package com.vibeplay.vibeplay.audio

import kotlin.math.*

/**
 * SonicPitchShifter - Pitch shifting for VibeAudioEngine
 *
 * Based on the Sonic algorithm (WSOLA - Waveform Similarity Overlap-Add).
 * This allows changing pitch without affecting tempo.
 *
 * Key features:
 * - Independent pitch control (semitones)
 * - High-quality time-domain processing
 * - Low latency suitable for real-time playback
 */
class SonicPitchShifter {

    companion object {
        private const val TAG = "SonicPitchShifter"
        private const val SONIC_MIN_PITCH = 0.5f
        private const val SONIC_MAX_PITCH = 2.0f
    }

    // Configuration
    private var sampleRate = 44100
    private var numChannels = 2
    private var enabled = false
    private var pitch = 1.0f  // 1.0 = normal, 2.0 = octave up, 0.5 = octave down

    // Sonic processor instance
    private var sonic: Sonic? = null

    // Output buffer
    private var outputBuffer = ShortArray(8192)
    private var outputBufferSize = 0

    /**
     * Configure the pitch shifter with audio parameters
     */
    fun configure(sampleRate: Int, numChannels: Int) {
        this.sampleRate = sampleRate
        this.numChannels = numChannels

        // Create new Sonic instance
        sonic = Sonic(sampleRate, numChannels).apply {
            setPitch(pitch)
            setSpeed(1.0f)  // Keep speed at 1.0 (we only want pitch change)
            setRate(1.0f)
            setVolume(1.0f)
        }
    }

    /**
     * Set pitch multiplier.
     * 1.0 = normal pitch
     * 2.0 = one octave higher
     * 0.5 = one octave lower
     */
    fun setPitch(pitchMultiplier: Float) {
        pitch = pitchMultiplier.coerceIn(SONIC_MIN_PITCH, SONIC_MAX_PITCH)
        sonic?.setPitch(pitch)
    }

    /**
     * Set pitch in semitones.
     * 0 = normal, +12 = octave up, -12 = octave down
     */
    fun setPitchSemitones(semitones: Float) {
        // Convert semitones to pitch multiplier: pitch = 2^(semitones/12)
        val multiplier = 2f.pow(semitones / 12f)
        setPitch(multiplier)
    }

    fun getPitch(): Float = pitch

    fun getPitchSemitones(): Float {
        // Convert pitch multiplier to semitones: semitones = 12 * log2(pitch)
        return (12f * ln(pitch) / ln(2f))
    }

    fun setEnabled(enabled: Boolean) {
        this.enabled = enabled
    }

    fun isEnabled(): Boolean = enabled

    /**
     * Process audio samples through pitch shifter.
     *
     * IMPORTANT: This may return a different number of samples than input!
     * - pitch > 1.0: fewer output samples
     * - pitch < 1.0: more output samples
     *
     * @param samples Input samples (interleaved stereo)
     * @return Processed samples (may be different length)
     */
    fun process(samples: ShortArray): ShortArray {
        if (!enabled || pitch == 1.0f) {
            return samples
        }

        val sonicInstance = sonic ?: return samples

        // Write input samples to Sonic
        sonicInstance.writeSamplesToStream(samples, samples.size / numChannels)

        // Read output samples
        val availableSamples = sonicInstance.samplesAvailable()
        if (availableSamples <= 0) {
            return ShortArray(0)
        }

        // Ensure output buffer is large enough
        val requiredSize = availableSamples * numChannels
        if (outputBuffer.size < requiredSize) {
            outputBuffer = ShortArray(requiredSize * 2)
        }

        // Read processed samples
        val readSamples = sonicInstance.readSamplesFromStream(outputBuffer, availableSamples)

        // Return exactly what was read
        return if (readSamples > 0) {
            outputBuffer.copyOf(readSamples * numChannels)
        } else {
            ShortArray(0)
        }
    }

    /**
     * Flush any remaining samples in the buffer.
     * Call this at end of stream.
     */
    fun flush(): ShortArray {
        val sonicInstance = sonic ?: return ShortArray(0)

        sonicInstance.flushStream()

        val availableSamples = sonicInstance.samplesAvailable()
        if (availableSamples <= 0) {
            return ShortArray(0)
        }

        val requiredSize = availableSamples * numChannels
        if (outputBuffer.size < requiredSize) {
            outputBuffer = ShortArray(requiredSize)
        }

        val readSamples = sonicInstance.readSamplesFromStream(outputBuffer, availableSamples)
        return if (readSamples > 0) {
            outputBuffer.copyOf(readSamples * numChannels)
        } else {
            ShortArray(0)
        }
    }

    /**
     * Reset the pitch shifter state.
     * Call this when seeking or changing tracks.
     */
    fun reset() {
        sonic = Sonic(sampleRate, numChannels).apply {
            setPitch(pitch)
            setSpeed(1.0f)
            setRate(1.0f)
            setVolume(1.0f)
        }
    }
}

/**
 * Sonic - Time-domain pitch/tempo modification algorithm.
 *
 * This is a Kotlin implementation of the Sonic algorithm, originally developed
 * by Bill Cox and used in Android Text-to-Speech and many other applications.
 *
 * The algorithm uses WSOLA (Waveform Similarity Overlap-Add) for high-quality
 * pitch shifting without the artifacts of simple resampling.
 */
class Sonic(
    private val sampleRate: Int,
    private val numChannels: Int
) {
    companion object {
        private const val SONIC_MIN_PITCH = 0.25f
        private const val SONIC_MAX_PITCH = 4.0f
        private const val SONIC_AMDF_FREQ = 4000
    }

    // Parameters
    private var speed = 1.0f
    private var pitch = 1.0f
    private var rate = 1.0f
    private var volume = 1.0f

    // Buffers
    private var inputBuffer: ShortArray
    private var outputBuffer: ShortArray
    private var pitchBuffer: ShortArray
    private var downSampleBuffer: ShortArray

    // State
    private var numInputSamples = 0
    private var numOutputSamples = 0
    private var numPitchSamples = 0
    private var minPeriod: Int
    private var maxPeriod: Int
    private var maxRequired: Int
    private var remainingInputToCopy = 0
    private var prevPeriod = 0
    private var prevMinDiff = 0
    private var newRatePosition = 0
    private var oldRatePosition = 0

    init {
        minPeriod = sampleRate / SONIC_AMDF_FREQ
        maxPeriod = sampleRate / 65
        maxRequired = 2 * maxPeriod

        val bufferSize = maxRequired * numChannels
        inputBuffer = ShortArray(bufferSize)
        outputBuffer = ShortArray(bufferSize)
        pitchBuffer = ShortArray(bufferSize)
        downSampleBuffer = ShortArray(maxRequired)
    }

    fun setPitch(pitch: Float) {
        this.pitch = pitch.coerceIn(SONIC_MIN_PITCH, SONIC_MAX_PITCH)
    }

    fun setSpeed(speed: Float) {
        this.speed = speed.coerceIn(0.1f, 10.0f)
    }

    fun setRate(rate: Float) {
        this.rate = rate.coerceIn(0.1f, 10.0f)
        oldRatePosition = 0
        newRatePosition = 0
    }

    fun setVolume(volume: Float) {
        this.volume = volume.coerceIn(0.0f, 2.0f)
    }

    fun samplesAvailable(): Int = numOutputSamples

    /**
     * Write samples to the stream for processing
     */
    fun writeSamplesToStream(samples: ShortArray, numSamples: Int) {
        enlargeInputBufferIfNeeded(numInputSamples + numSamples)

        // Copy to input buffer
        System.arraycopy(
            samples, 0,
            inputBuffer, numInputSamples * numChannels,
            numSamples * numChannels
        )
        numInputSamples += numSamples

        processStreamInput()
    }

    /**
     * Read processed samples from the stream
     */
    fun readSamplesFromStream(samples: ShortArray, maxSamples: Int): Int {
        val numSamples = minOf(maxSamples, numOutputSamples)

        if (numSamples <= 0) return 0

        System.arraycopy(
            outputBuffer, 0,
            samples, 0,
            numSamples * numChannels
        )

        // Remove read samples from buffer
        numOutputSamples -= numSamples
        if (numOutputSamples > 0) {
            System.arraycopy(
                outputBuffer, numSamples * numChannels,
                outputBuffer, 0,
                numOutputSamples * numChannels
            )
        }

        return numSamples
    }

    /**
     * Flush remaining samples
     */
    fun flushStream() {
        val remainingSamples = numInputSamples
        val expectedOutput = (remainingSamples / (speed * pitch)).toInt() + numPitchSamples
        enlargeOutputBufferIfNeeded(numOutputSamples + expectedOutput)

        // Process any remaining input
        if (numInputSamples > 0) {
            // Add silence to ensure all samples are processed
            val silenceSize = maxRequired
            enlargeInputBufferIfNeeded(numInputSamples + silenceSize)
            for (i in 0 until silenceSize * numChannels) {
                inputBuffer[numInputSamples * numChannels + i] = 0
            }
            numInputSamples += silenceSize
            processStreamInput()
        }

        // Move pitch buffer to output
        if (numPitchSamples > 0) {
            enlargeOutputBufferIfNeeded(numOutputSamples + numPitchSamples)
            System.arraycopy(
                pitchBuffer, 0,
                outputBuffer, numOutputSamples * numChannels,
                numPitchSamples * numChannels
            )
            numOutputSamples += numPitchSamples
            numPitchSamples = 0
        }
    }

    private fun processStreamInput() {
        val effectivePitch = pitch * rate
        val effectiveSpeed = speed / effectivePitch

        if (effectiveSpeed > 1.0001f) {
            changeSpeed(effectiveSpeed)
        } else if (effectiveSpeed < 0.9999f) {
            changeSpeed(effectiveSpeed)
        } else {
            copyToOutput(numInputSamples)
            numInputSamples = 0
        }

        if (effectivePitch != 1.0f) {
            adjustPitch()
        }
    }

    private fun changeSpeed(speedFactor: Float) {
        if (numInputSamples < maxRequired) return

        var position = 0

        while (numInputSamples - position >= maxRequired) {
            val period = findPitchPeriod(position)

            if (speedFactor > 1.0f) {
                // Speed up - skip samples
                position += (period * speedFactor).toInt()
            } else {
                // Slow down - overlap-add
                val newSamples = (period / speedFactor).toInt() - period
                enlargeOutputBufferIfNeeded(numOutputSamples + period + newSamples)
                overlapAdd(period, position, newSamples)
                position += period
            }
        }

        // Remove processed samples from input buffer
        if (position > 0) {
            numInputSamples -= position
            if (numInputSamples > 0) {
                System.arraycopy(
                    inputBuffer, position * numChannels,
                    inputBuffer, 0,
                    numInputSamples * numChannels
                )
            }
        }
    }

    private fun adjustPitch() {
        val effectivePitch = pitch * rate

        if (numOutputSamples == 0) return

        // Move output to pitch buffer for resampling
        enlargePitchBufferIfNeeded(numPitchSamples + numOutputSamples)
        System.arraycopy(
            outputBuffer, 0,
            pitchBuffer, numPitchSamples * numChannels,
            numOutputSamples * numChannels
        )
        numPitchSamples += numOutputSamples
        numOutputSamples = 0

        // Resample to change pitch
        while (numPitchSamples > 0) {
            val period = (sampleRate / 65).coerceAtLeast(1)
            val newSamples = (period / effectivePitch).toInt()

            if (numPitchSamples < period) break

            enlargeOutputBufferIfNeeded(numOutputSamples + newSamples)

            // Linear interpolation resampling
            for (i in 0 until newSamples) {
                val srcPos = (i * effectivePitch).toInt()
                val frac = (i * effectivePitch) - srcPos

                if (srcPos + 1 < numPitchSamples) {
                    for (ch in 0 until numChannels) {
                        val idx = srcPos * numChannels + ch
                        val s1 = pitchBuffer[idx].toFloat()
                        val s2 = pitchBuffer[idx + numChannels].toFloat()
                        val interpolated = s1 + (s2 - s1) * frac
                        outputBuffer[(numOutputSamples + i) * numChannels + ch] =
                            interpolated.toInt().coerceIn(-32768, 32767).toShort()
                    }
                }
            }

            numOutputSamples += newSamples
            numPitchSamples -= period

            if (numPitchSamples > 0) {
                System.arraycopy(
                    pitchBuffer, period * numChannels,
                    pitchBuffer, 0,
                    numPitchSamples * numChannels
                )
            }
        }
    }

    private fun copyToOutput(numSamples: Int) {
        enlargeOutputBufferIfNeeded(numOutputSamples + numSamples)
        System.arraycopy(
            inputBuffer, 0,
            outputBuffer, numOutputSamples * numChannels,
            numSamples * numChannels
        )
        numOutputSamples += numSamples
    }

    private fun findPitchPeriod(position: Int): Int {
        // Simplified pitch period detection using downsampling
        val skip = sampleRate / SONIC_AMDF_FREQ

        // Downsample to mono for pitch detection
        for (i in 0 until maxPeriod / skip) {
            var sum = 0
            val idx = (position + i * skip) * numChannels
            if (idx < inputBuffer.size) {
                for (ch in 0 until numChannels) {
                    sum += inputBuffer[idx + ch]
                }
                downSampleBuffer[i] = (sum / numChannels).toShort()
            }
        }

        // Find pitch period using AMDF
        var bestPeriod = minPeriod
        var minDiff = Int.MAX_VALUE

        for (period in minPeriod / skip until maxPeriod / skip) {
            var diff = 0
            for (i in 0 until period) {
                val idx1 = i
                val idx2 = i + period
                if (idx2 < downSampleBuffer.size) {
                    diff += abs(downSampleBuffer[idx1] - downSampleBuffer[idx2])
                }
            }

            if (diff < minDiff) {
                minDiff = diff
                bestPeriod = period * skip
            }
        }

        return bestPeriod.coerceIn(minPeriod, maxPeriod)
    }

    private fun overlapAdd(period: Int, position: Int, newSamples: Int) {
        // Copy original samples
        System.arraycopy(
            inputBuffer, position * numChannels,
            outputBuffer, numOutputSamples * numChannels,
            period * numChannels
        )
        numOutputSamples += period

        // Generate additional samples by overlap-add
        for (i in 0 until newSamples) {
            val ratio = (i + 1).toFloat() / (newSamples + 1)
            for (ch in 0 until numChannels) {
                val idx1 = (position + i) * numChannels + ch
                val idx2 = (position + period + i) * numChannels + ch

                if (idx1 < inputBuffer.size && idx2 < inputBuffer.size) {
                    val sample = (inputBuffer[idx1] * (1 - ratio) +
                                 inputBuffer[idx2] * ratio).toInt()
                    outputBuffer[(numOutputSamples + i) * numChannels + ch] =
                        sample.coerceIn(-32768, 32767).toShort()
                }
            }
        }
        numOutputSamples += newSamples
    }

    private fun enlargeInputBufferIfNeeded(newSize: Int) {
        val requiredSize = newSize * numChannels
        if (inputBuffer.size < requiredSize) {
            val newBuffer = ShortArray(requiredSize * 2)
            System.arraycopy(inputBuffer, 0, newBuffer, 0, numInputSamples * numChannels)
            inputBuffer = newBuffer
        }
    }

    private fun enlargeOutputBufferIfNeeded(newSize: Int) {
        val requiredSize = newSize * numChannels
        if (outputBuffer.size < requiredSize) {
            val newBuffer = ShortArray(requiredSize * 2)
            System.arraycopy(outputBuffer, 0, newBuffer, 0, numOutputSamples * numChannels)
            outputBuffer = newBuffer
        }
    }

    private fun enlargePitchBufferIfNeeded(newSize: Int) {
        val requiredSize = newSize * numChannels
        if (pitchBuffer.size < requiredSize) {
            val newBuffer = ShortArray(requiredSize * 2)
            System.arraycopy(pitchBuffer, 0, newBuffer, 0, numPitchSamples * numChannels)
            pitchBuffer = newBuffer
        }
    }
}
