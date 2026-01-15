package com.vibeplay.vibeplay.audio

import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.ln
import kotlin.math.pow
import kotlin.math.sqrt

/**
 * LUFS (Loudness Units Full Scale) Analyzer
 *
 * Implements ITU-R BS.1770-4 loudness measurement algorithm:
 * 1. K-weighting pre-filter (accounts for human hearing sensitivity)
 * 2. Mean square calculation per 400ms blocks with 75% overlap
 * 3. Absolute gating at -70 LUFS
 * 4. Relative gating at -10 dB below ungated loudness
 * 5. Final integrated loudness calculation
 */
class LoudnessAnalyzer(private val context: Context) {

    companion object {
        private const val TAG = "LoudnessAnalyzer"

        // ITU-R BS.1770-4 constants
        private const val BLOCK_SIZE_MS = 400       // 400ms blocks
        private const val BLOCK_OVERLAP = 0.75      // 75% overlap
        private const val ABSOLUTE_GATE_LUFS = -70.0
        private const val RELATIVE_GATE_DB = -10.0

        // Channel weights for surround (we only use stereo)
        private const val FRONT_WEIGHT = 1.0
        private const val SURROUND_WEIGHT = 1.41    // +1.5 dB for surround
    }

    data class LoudnessResult(
        val integratedLoudness: Double,  // LUFS
        val truePeak: Double,            // 0.0 to 1.0+ (can exceed 1.0 for inter-sample peaks)
        val loudnessRange: Double,       // LU (dynamic range)
        val shortTermMax: Double,        // Maximum short-term loudness (3s window)
        val sampleCount: Long,
        val durationMs: Long
    )

    /**
     * Analyze a file and return LUFS loudness and peak values
     */
    suspend fun analyze(filePath: String): LoudnessResult? = withContext(Dispatchers.IO) {
        val file = File(filePath)
        if (!file.exists()) {
            Log.e(TAG, "File not found: $filePath")
            return@withContext null
        }

        var extractor: MediaExtractor? = null
        var codec: MediaCodec? = null

        try {
            extractor = MediaExtractor()
            extractor.setDataSource(filePath)

            // Find audio track
            var audioTrackIndex = -1
            var format: MediaFormat? = null

            for (i in 0 until extractor.trackCount) {
                val trackFormat = extractor.getTrackFormat(i)
                val mime = trackFormat.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    format = trackFormat
                    break
                }
            }

            if (audioTrackIndex < 0 || format == null) {
                Log.e(TAG, "No audio track found in: $filePath")
                return@withContext null
            }

            extractor.selectTrack(audioTrackIndex)

            val sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            val channelCount = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: return@withContext null
            val duration = if (format.containsKey(MediaFormat.KEY_DURATION)) {
                format.getLong(MediaFormat.KEY_DURATION) / 1000 // Convert to ms
            } else 0L

            Log.d(TAG, "Analyzing: $filePath (${sampleRate}Hz, ${channelCount}ch, ${duration}ms)")

            // Create decoder
            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(format, null, null, 0)
            codec.start()

            // Analysis state
            val blockSizeSamples = (sampleRate * BLOCK_SIZE_MS / 1000.0).toInt()
            val hopSizeSamples = (blockSizeSamples * (1.0 - BLOCK_OVERLAP)).toInt()

            // K-weighting filter state (per channel)
            val kWeightFilters = Array(channelCount) { KWeightingFilter(sampleRate.toDouble()) }

            // Accumulate filtered samples for block processing
            val blockBuffer = mutableListOf<DoubleArray>()  // List of per-channel sample arrays
            val blockLoudnesses = mutableListOf<Double>()   // Loudness of each 400ms block

            var truePeak = 0.0
            var totalSamples = 0L
            var samplesInCurrentBlock = 0
            val currentBlockSamples = Array(channelCount) { DoubleArray(blockSizeSamples) }

            // Decode loop
            val bufferInfo = MediaCodec.BufferInfo()
            var inputDone = false
            var outputDone = false
            val timeoutUs = 10000L

            while (!outputDone) {
                // Feed input
                if (!inputDone) {
                    val inputIndex = codec.dequeueInputBuffer(timeoutUs)
                    if (inputIndex >= 0) {
                        val inputBuffer = codec.getInputBuffer(inputIndex) ?: continue
                        val sampleSize = extractor.readSampleData(inputBuffer, 0)

                        if (sampleSize < 0) {
                            codec.queueInputBuffer(inputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            codec.queueInputBuffer(inputIndex, 0, sampleSize, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }

                // Get output
                val outputIndex = codec.dequeueOutputBuffer(bufferInfo, timeoutUs)
                if (outputIndex >= 0) {
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        outputDone = true
                    }

                    val outputBuffer = codec.getOutputBuffer(outputIndex) ?: continue
                    outputBuffer.position(bufferInfo.offset)
                    outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                    outputBuffer.order(ByteOrder.LITTLE_ENDIAN)

                    // Process PCM samples (assuming 16-bit signed)
                    val sampleCount = bufferInfo.size / 2 / channelCount

                    for (i in 0 until sampleCount) {
                        for (ch in 0 until channelCount) {
                            // Read 16-bit sample and normalize to -1.0 to 1.0
                            val sample = outputBuffer.short.toDouble() / 32768.0

                            // Track true peak (simple - could use oversampling for inter-sample peaks)
                            if (abs(sample) > truePeak) {
                                truePeak = abs(sample)
                            }

                            // Apply K-weighting filter
                            val filtered = kWeightFilters[ch].process(sample)

                            // Add to current block
                            if (samplesInCurrentBlock < blockSizeSamples) {
                                currentBlockSamples[ch][samplesInCurrentBlock] = filtered
                            }
                        }

                        samplesInCurrentBlock++
                        totalSamples++

                        // When block is full, calculate loudness and slide
                        if (samplesInCurrentBlock >= blockSizeSamples) {
                            val blockLoudness = calculateBlockLoudness(currentBlockSamples, channelCount)
                            blockLoudnesses.add(blockLoudness)

                            // Slide by hop size (keep 75% of samples)
                            for (ch in 0 until channelCount) {
                                System.arraycopy(
                                    currentBlockSamples[ch], hopSizeSamples,
                                    currentBlockSamples[ch], 0,
                                    blockSizeSamples - hopSizeSamples
                                )
                            }
                            samplesInCurrentBlock = blockSizeSamples - hopSizeSamples
                        }
                    }

                    codec.releaseOutputBuffer(outputIndex, false)
                }
            }

            // Process any remaining samples in final block (if enough)
            if (samplesInCurrentBlock > blockSizeSamples / 4) {
                // Pad with zeros
                for (ch in 0 until channelCount) {
                    for (i in samplesInCurrentBlock until blockSizeSamples) {
                        currentBlockSamples[ch][i] = 0.0
                    }
                }
                val blockLoudness = calculateBlockLoudness(currentBlockSamples, channelCount)
                blockLoudnesses.add(blockLoudness)
            }

            // Calculate integrated loudness with gating
            val integratedLoudness = calculateIntegratedLoudness(blockLoudnesses)

            // Calculate loudness range (LRA) - simplified
            val loudnessRange = calculateLoudnessRange(blockLoudnesses)

            // Find maximum short-term loudness (would need 3s window - simplified here)
            val shortTermMax = blockLoudnesses.maxOrNull() ?: integratedLoudness

            Log.d(TAG, "Analysis complete: ${String.format("%.1f", integratedLoudness)} LUFS, peak: ${String.format("%.3f", truePeak)}")

            return@withContext LoudnessResult(
                integratedLoudness = integratedLoudness,
                truePeak = truePeak,
                loudnessRange = loudnessRange,
                shortTermMax = shortTermMax,
                sampleCount = totalSamples,
                durationMs = duration
            )

        } catch (e: Exception) {
            Log.e(TAG, "Error analyzing file: ${e.message}", e)
            return@withContext null
        } finally {
            try {
                codec?.stop()
                codec?.release()
            } catch (e: Exception) { /* ignore */ }
            try {
                extractor?.release()
            } catch (e: Exception) { /* ignore */ }
        }
    }

    /**
     * Calculate loudness of a single 400ms block
     * Returns loudness in LUFS
     */
    private fun calculateBlockLoudness(samples: Array<DoubleArray>, channelCount: Int): Double {
        var sumSquares = 0.0
        val sampleCount = samples[0].size

        for (ch in 0 until channelCount) {
            var channelSum = 0.0
            for (i in 0 until sampleCount) {
                channelSum += samples[ch][i] * samples[ch][i]
            }
            val meanSquare = channelSum / sampleCount

            // Apply channel weight (front channels = 1.0, surround = 1.41)
            // For stereo, both channels are front
            sumSquares += meanSquare * FRONT_WEIGHT
        }

        // Convert to LUFS: -0.691 + 10 * log10(sum)
        return if (sumSquares > 0) {
            -0.691 + 10.0 * log10(sumSquares)
        } else {
            -100.0  // Silence
        }
    }

    /**
     * Calculate integrated loudness with ITU-R BS.1770-4 gating
     */
    private fun calculateIntegratedLoudness(blockLoudnesses: List<Double>): Double {
        if (blockLoudnesses.isEmpty()) return -70.0

        // Step 1: Absolute gating at -70 LUFS
        val afterAbsoluteGate = blockLoudnesses.filter { it > ABSOLUTE_GATE_LUFS }
        if (afterAbsoluteGate.isEmpty()) return -70.0

        // Step 2: Calculate ungated loudness (for relative gate)
        val ungatedLoudness = powerAverage(afterAbsoluteGate)

        // Step 3: Relative gating at ungated - 10 dB
        val relativeGateThreshold = ungatedLoudness + RELATIVE_GATE_DB
        val afterRelativeGate = afterAbsoluteGate.filter { it > relativeGateThreshold }
        if (afterRelativeGate.isEmpty()) return ungatedLoudness

        // Step 4: Calculate final integrated loudness
        return powerAverage(afterRelativeGate)
    }

    /**
     * Power-average a list of loudness values (in LUFS)
     */
    private fun powerAverage(values: List<Double>): Double {
        if (values.isEmpty()) return -70.0

        var sumPower = 0.0
        for (lufs in values) {
            // Convert LUFS to power: 10^((L + 0.691) / 10)
            sumPower += 10.0.pow((lufs + 0.691) / 10.0)
        }

        val avgPower = sumPower / values.size
        return -0.691 + 10.0 * log10(avgPower)
    }

    /**
     * Calculate loudness range (LRA) - simplified version
     * Full LRA uses gating and percentiles
     */
    private fun calculateLoudnessRange(blockLoudnesses: List<Double>): Double {
        if (blockLoudnesses.size < 2) return 0.0

        // Filter out silence
        val filtered = blockLoudnesses.filter { it > -70.0 }.sorted()
        if (filtered.size < 2) return 0.0

        // Use 10th and 95th percentile (simplified)
        val lowIndex = (filtered.size * 0.10).toInt()
        val highIndex = (filtered.size * 0.95).toInt().coerceAtMost(filtered.size - 1)

        return filtered[highIndex] - filtered[lowIndex]
    }

    private fun log10(x: Double): Double {
        return if (x > 0) ln(x) / ln(10.0) else -100.0
    }

    /**
     * Find where silence/fade begins at the end of a track
     *
     * @param filePath Path to audio file
     * @param thresholdDb Silence threshold in dB (e.g., -40.0)
     * @param analyzeLastMs How many milliseconds from the end to analyze
     * @return Milliseconds from start where silence begins, or null if no silence found
     */
    suspend fun findSilenceStart(
        filePath: String,
        thresholdDb: Double = -40.0,
        analyzeLastMs: Int = 15000
    ): Long? = withContext(Dispatchers.IO) {
        val file = File(filePath)
        if (!file.exists()) {
            Log.e(TAG, "File not found: $filePath")
            return@withContext null
        }

        var extractor: MediaExtractor? = null
        var codec: MediaCodec? = null

        try {
            extractor = MediaExtractor()
            extractor.setDataSource(filePath)

            // Find audio track
            var audioTrackIndex = -1
            var format: MediaFormat? = null

            for (i in 0 until extractor.trackCount) {
                val trackFormat = extractor.getTrackFormat(i)
                val mime = trackFormat.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    format = trackFormat
                    break
                }
            }

            if (audioTrackIndex < 0 || format == null) {
                return@withContext null
            }

            extractor.selectTrack(audioTrackIndex)

            val sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            val channelCount = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: return@withContext null
            val durationUs = if (format.containsKey(MediaFormat.KEY_DURATION)) {
                format.getLong(MediaFormat.KEY_DURATION)
            } else return@withContext null

            val durationMs = durationUs / 1000

            // Don't analyze very short tracks
            if (durationMs < analyzeLastMs * 2) {
                return@withContext null
            }

            // Seek to the analysis start point
            val analysisStartMs = durationMs - analyzeLastMs
            val analysisStartUs = analysisStartMs * 1000
            extractor.seekTo(analysisStartUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)

            // Create decoder
            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(format, null, null, 0)
            codec.start()

            // Convert threshold from dB to linear amplitude
            val thresholdLinear = 10.0.pow(thresholdDb / 20.0)

            // Store RMS values for analysis windows (100ms windows)
            val windowSizeMs = 100
            val windowSizeSamples = (sampleRate * windowSizeMs / 1000)
            val rmsValues = mutableListOf<Pair<Long, Double>>() // (timestamp_ms, rms)

            var currentWindowSamples = 0
            var currentWindowSumSquares = 0.0
            var currentPositionMs = analysisStartMs

            // Decode and analyze
            val bufferInfo = MediaCodec.BufferInfo()
            var inputDone = false
            var outputDone = false
            val timeoutUs = 10000L

            while (!outputDone) {
                // Feed input
                if (!inputDone) {
                    val inputIndex = codec.dequeueInputBuffer(timeoutUs)
                    if (inputIndex >= 0) {
                        val inputBuffer = codec.getInputBuffer(inputIndex) ?: continue
                        val sampleSize = extractor.readSampleData(inputBuffer, 0)

                        if (sampleSize < 0) {
                            codec.queueInputBuffer(inputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            codec.queueInputBuffer(inputIndex, 0, sampleSize, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }

                // Get output
                val outputIndex = codec.dequeueOutputBuffer(bufferInfo, timeoutUs)
                if (outputIndex >= 0) {
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        outputDone = true
                    }

                    val outputBuffer = codec.getOutputBuffer(outputIndex) ?: continue
                    outputBuffer.position(bufferInfo.offset)
                    outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                    outputBuffer.order(ByteOrder.LITTLE_ENDIAN)

                    val sampleCount = bufferInfo.size / 2 / channelCount

                    for (i in 0 until sampleCount) {
                        var sampleSum = 0.0
                        for (ch in 0 until channelCount) {
                            val sample = outputBuffer.short.toDouble() / 32768.0
                            sampleSum += sample * sample
                        }
                        currentWindowSumSquares += sampleSum / channelCount
                        currentWindowSamples++

                        // When window is full, calculate RMS
                        if (currentWindowSamples >= windowSizeSamples) {
                            val rms = sqrt(currentWindowSumSquares / currentWindowSamples)
                            rmsValues.add(Pair(currentPositionMs, rms))

                            currentPositionMs += windowSizeMs
                            currentWindowSamples = 0
                            currentWindowSumSquares = 0.0
                        }
                    }

                    codec.releaseOutputBuffer(outputIndex, false)
                }
            }

            // Find where continuous silence begins (from the end backwards)
            if (rmsValues.isEmpty()) {
                return@withContext null
            }

            // Look for the point where audio drops below threshold and stays there
            var silenceStartMs: Long? = null
            var consecutiveSilentWindows = 0
            val minSilentWindows = 3 // Require at least 300ms of consecutive silence

            // Scan from end to beginning
            for (i in rmsValues.indices.reversed()) {
                val (timestamp, rms) = rmsValues[i]

                if (rms < thresholdLinear) {
                    consecutiveSilentWindows++
                    if (consecutiveSilentWindows >= minSilentWindows) {
                        silenceStartMs = timestamp
                    }
                } else {
                    // Found audio above threshold, stop
                    if (silenceStartMs != null) {
                        break
                    }
                    consecutiveSilentWindows = 0
                }
            }

            // Also detect fade-outs: look for continuous decrease in RMS
            if (silenceStartMs == null && rmsValues.size > 10) {
                // Check if the last portion shows a consistent fade
                val lastQuarter = rmsValues.takeLast(rmsValues.size / 4)
                if (lastQuarter.size > 3) {
                    var fadeDetected = true
                    var peakRms = 0.0

                    for (i in 0 until lastQuarter.size - 1) {
                        if (lastQuarter[i].second > peakRms) {
                            peakRms = lastQuarter[i].second
                        }
                        // If RMS increases significantly, it's not a fade
                        if (lastQuarter[i + 1].second > lastQuarter[i].second * 1.5) {
                            fadeDetected = false
                            break
                        }
                    }

                    // If we detected a fade and final RMS is much lower than peak
                    if (fadeDetected && lastQuarter.last().second < peakRms * 0.3) {
                        silenceStartMs = lastQuarter.first().first
                    }
                }
            }

            Log.d(TAG, "Silence detection: ${if (silenceStartMs != null) "silence at ${silenceStartMs}ms" else "no silence found"}")
            return@withContext silenceStartMs

        } catch (e: Exception) {
            Log.e(TAG, "Error detecting silence: ${e.message}", e)
            return@withContext null
        } finally {
            try {
                codec?.stop()
                codec?.release()
            } catch (e: Exception) { /* ignore */ }
            try {
                extractor?.release()
            } catch (e: Exception) { /* ignore */ }
        }
    }

    /**
     * K-weighting pre-filter as specified in ITU-R BS.1770
     * Consists of:
     * 1. High-shelf boost (accounts for head acoustic effects)
     * 2. High-pass filter (removes DC and very low frequencies)
     */
    private class KWeightingFilter(sampleRate: Double) {
        // Pre-computed coefficients for common sample rates
        // These are biquad filter coefficients

        // High-shelf filter (stage 1)
        private val shelfB0: Double
        private val shelfB1: Double
        private val shelfB2: Double
        private val shelfA1: Double
        private val shelfA2: Double

        // High-pass filter (stage 2)
        private val hpB0: Double
        private val hpB1: Double
        private val hpB2: Double
        private val hpA1: Double
        private val hpA2: Double

        // Filter state
        private var shelfX1 = 0.0
        private var shelfX2 = 0.0
        private var shelfY1 = 0.0
        private var shelfY2 = 0.0

        private var hpX1 = 0.0
        private var hpX2 = 0.0
        private var hpY1 = 0.0
        private var hpY2 = 0.0

        init {
            // Pre-filter coefficients from ITU-R BS.1770-4
            // These are optimized for 48kHz but work reasonably at other rates

            // High shelf: +4dB at high frequencies
            // Fc = 1500 Hz, gain = +4 dB
            val fc1 = 1681.97 // Pre-filter frequency
            val Q1 = 0.7071
            val gain1 = 3.999  // dB
            val K1 = Math.tan(Math.PI * fc1 / sampleRate)
            val V1 = 10.0.pow(gain1 / 20.0)

            val norm1 = 1.0 / (1.0 + K1 / Q1 + K1 * K1)
            shelfB0 = (V1 + sqrt(2.0 * V1) * K1 + K1 * K1) * norm1
            shelfB1 = 2.0 * (K1 * K1 - V1) * norm1
            shelfB2 = (V1 - sqrt(2.0 * V1) * K1 + K1 * K1) * norm1
            shelfA1 = 2.0 * (K1 * K1 - 1.0) * norm1
            shelfA2 = (1.0 - K1 / Q1 + K1 * K1) * norm1

            // High-pass filter: -3dB at ~38 Hz
            val fc2 = 38.13547 // High-pass frequency
            val Q2 = 0.5003
            val K2 = Math.tan(Math.PI * fc2 / sampleRate)

            val norm2 = 1.0 / (1.0 + K2 / Q2 + K2 * K2)
            hpB0 = norm2
            hpB1 = -2.0 * norm2
            hpB2 = norm2
            hpA1 = 2.0 * (K2 * K2 - 1.0) * norm2
            hpA2 = (1.0 - K2 / Q2 + K2 * K2) * norm2
        }

        fun process(input: Double): Double {
            // Stage 1: High shelf
            val shelfOut = shelfB0 * input + shelfB1 * shelfX1 + shelfB2 * shelfX2 -
                          shelfA1 * shelfY1 - shelfA2 * shelfY2
            shelfX2 = shelfX1
            shelfX1 = input
            shelfY2 = shelfY1
            shelfY1 = shelfOut

            // Stage 2: High pass
            val hpOut = hpB0 * shelfOut + hpB1 * hpX1 + hpB2 * hpX2 -
                       hpA1 * hpY1 - hpA2 * hpY2
            hpX2 = hpX1
            hpX1 = shelfOut
            hpY2 = hpY1
            hpY1 = hpOut

            return hpOut
        }

        fun reset() {
            shelfX1 = 0.0; shelfX2 = 0.0
            shelfY1 = 0.0; shelfY2 = 0.0
            hpX1 = 0.0; hpX2 = 0.0
            hpY1 = 0.0; hpY2 = 0.0
        }
    }
}
