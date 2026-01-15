package com.vibeplay.vibeplay.audio

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.EventChannel
import kotlin.math.*

/**
 * AudioPulse - Real-time audio analysis engine for visualization.
 *
 * Performs FFT analysis, frequency band extraction, beat detection,
 * and energy tracking on raw PCM audio data.
 *
 * This is the "pulse" that makes visualizations come alive.
 */
class AudioPulse {

    companion object {
        private const val TAG = "AudioPulse"

        // FFT Configuration
        private const val FFT_SIZE = 2048  // Higher = better frequency resolution
        private const val SPECTRUM_BANDS = 32  // For detailed spectrum display

        // Frequency band boundaries (Hz) - musical ranges
        private const val SUB_BASS_MIN = 20
        private const val SUB_BASS_MAX = 60      // Sub-bass: rumble, feel
        private const val BASS_MAX = 250         // Bass: kick drums, bass guitar
        private const val LOW_MID_MAX = 500      // Low-mid: warmth
        private const val MID_MAX = 2000         // Mid: vocals, instruments
        private const val HIGH_MID_MAX = 4000    // High-mid: presence
        private const val TREBLE_MAX = 6000      // Treble: clarity, detail
        // Brilliance: 6000-20000 Hz - air, sparkle

        // Beat detection
        private const val BEAT_SENSITIVITY = 1.3f   // Slightly more sensitive
        private const val BEAT_COOLDOWN_MS = 80L    // Faster beat detection
        private const val ENERGY_HISTORY_SIZE = 30  // Shorter history for faster response

        // Update throttling
        private const val MIN_UPDATE_INTERVAL_MS = 16L  // ~60fps max
    }

    // Configuration
    private var sampleRate = 44100
    private var channelCount = 2

    // Sample buffer (circular)
    private val sampleBuffer = FloatArray(FFT_SIZE)
    private var sampleIndex = 0
    private var samplesCollected = 0

    // FFT arrays
    private val fftReal = FloatArray(FFT_SIZE)
    private val fftImag = FloatArray(FFT_SIZE)
    private val magnitudes = FloatArray(FFT_SIZE / 2)
    private val prevMagnitudes = FloatArray(FFT_SIZE / 2)

    // Hamming window (pre-computed for performance)
    private val hammingWindow = FloatArray(FFT_SIZE) { i ->
        0.54f - 0.46f * cos(2.0 * PI * i / (FFT_SIZE - 1)).toFloat()
    }

    // Frequency bands (0.0 - 1.0, smoothed)
    private var subBass = 0f
    private var bass = 0f
    private var lowMid = 0f
    private var mid = 0f
    private var highMid = 0f
    private var treble = 0f
    private var brilliance = 0f

    // Combined bands for simple use
    private var bassTotal = 0f      // subBass + bass
    private var midTotal = 0f       // lowMid + mid + highMid
    private var trebleTotal = 0f    // treble + brilliance

    // Temporal analysis
    private var energy = 0f
    private var peak = 0f
    private val energyHistory = FloatArray(ENERGY_HISTORY_SIZE)
    private var energyHistoryIndex = 0

    // Beat detection - use separate bass history for proper comparison
    private var beat = 0f
    private var onBeat = false
    private var lastBeatTime = 0L
    private val beatTimes = mutableListOf<Long>()
    private var bpm = 0f
    private val bassHistory = FloatArray(ENERGY_HISTORY_SIZE)
    private var bassHistoryIndex = 0

    // Spectral analysis
    private var flux = 0f
    private var centroid = 0f  // Spectral centroid (brightness)
    private val spectrum = FloatArray(SPECTRUM_BANDS)

    // Waveform for display
    private val waveform = FloatArray(128)
    private var waveformIndex = 0

    // Smoothing factors (higher = more responsive)
    // Keep these HIGH - let Flutter do final visual smoothing
    // We want raw peaks to come through for sync
    private val smoothFast = 0.85f   // Nearly raw for beat detection
    private val smoothMed = 0.7f     // Responsive for general
    private val smoothSlow = 0.5f    // Some smoothing for slow elements

    // Flutter communication
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var lastUpdateTime = 0L

    /**
     * Configure with audio parameters
     */
    fun configure(sampleRate: Int, channelCount: Int) {
        this.sampleRate = sampleRate
        this.channelCount = channelCount
        Log.d(TAG, "Configured: ${sampleRate}Hz, ${channelCount}ch")
        reset()
    }

    /**
     * Reset all state
     */
    fun reset() {
        sampleIndex = 0
        samplesCollected = 0
        subBass = 0f; bass = 0f; lowMid = 0f; mid = 0f
        highMid = 0f; treble = 0f; brilliance = 0f
        energy = 0f; peak = 0f; beat = 0f; flux = 0f
        bpm = 0f; onBeat = false
        energyHistoryIndex = 0
        bassHistoryIndex = 0
        bassHistory.fill(0f)
        energyHistory.fill(0f)
        beatTimes.clear()
    }

    /**
     * Process incoming PCM samples (16-bit signed)
     */
    fun processSamples(samples: ShortArray) {
        // Convert to mono float and store
        var i = 0
        while (i < samples.size) {
            var sample = 0f

            // Average channels to mono
            for (ch in 0 until channelCount) {
                if (i + ch < samples.size) {
                    sample += samples[i + ch] / 32768f
                }
            }
            sample /= channelCount

            // Store in circular buffer
            sampleBuffer[sampleIndex] = sample
            sampleIndex = (sampleIndex + 1) % FFT_SIZE
            samplesCollected++

            // Store in waveform buffer (downsampled)
            if (samplesCollected % 16 == 0) {
                waveform[waveformIndex] = sample
                waveformIndex = (waveformIndex + 1) % waveform.size
            }

            i += channelCount
        }

        // Perform analysis when we have enough samples
        if (samplesCollected >= FFT_SIZE / 4) {
            val now = System.currentTimeMillis()
            if (now - lastUpdateTime >= MIN_UPDATE_INTERVAL_MS) {
                lastUpdateTime = now
                performAnalysis()
            }
        }
    }

    /**
     * Get current pulse data as a map for Flutter
     */
    fun getPulseData(): Map<String, Any> {
        return mapOf(
            // 7-band frequency analysis
            "subBass" to subBass,
            "bass" to bass,
            "lowMid" to lowMid,
            "mid" to mid,
            "highMid" to highMid,
            "treble" to treble,
            "brilliance" to brilliance,

            // Simplified 3-band (for easy use)
            "bassTotal" to bassTotal,
            "midTotal" to midTotal,
            "trebleTotal" to trebleTotal,

            // Energy and dynamics
            "energy" to energy,
            "peak" to peak,

            // Beat detection
            "beat" to beat,
            "onBeat" to onBeat,
            "bpm" to bpm,

            // Spectral
            "flux" to flux,
            "centroid" to centroid,

            // Detailed data
            "spectrum" to spectrum.toList(),
            "waveform" to waveform.toList(),

            // Timestamp
            "timestamp" to System.currentTimeMillis()
        )
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    //region Analysis

    private fun performAnalysis() {
        // Copy samples to FFT buffer with windowing
        for (i in 0 until FFT_SIZE) {
            val srcIndex = (sampleIndex + i) % FFT_SIZE
            fftReal[i] = sampleBuffer[srcIndex] * hammingWindow[i]
            fftImag[i] = 0f
        }

        // Perform FFT
        fft(fftReal, fftImag, FFT_SIZE)

        // Calculate magnitudes (convert to dB scale for better visualization)
        var maxMag = 0f
        for (i in 0 until FFT_SIZE / 2) {
            val re = fftReal[i]
            val im = fftImag[i]
            val mag = sqrt(re * re + im * im)
            magnitudes[i] = mag
            maxMag = max(maxMag, mag)
        }

        // Normalize
        if (maxMag > 0.001f) {
            for (i in magnitudes.indices) {
                magnitudes[i] = (magnitudes[i] / maxMag).coerceIn(0f, 1f)
            }
        }

        // Extract frequency bands
        extractFrequencyBands()

        // Calculate energy
        calculateEnergy()

        // Detect beats
        detectBeat()

        // Calculate spectral flux
        calculateFlux()

        // Calculate spectral centroid (brightness)
        calculateCentroid()

        // Build 32-band spectrum
        buildSpectrum()

        // Store magnitudes for next flux calculation
        System.arraycopy(magnitudes, 0, prevMagnitudes, 0, magnitudes.size)

        samplesCollected = 0
    }

    private fun extractFrequencyBands() {
        val binWidth = sampleRate.toFloat() / FFT_SIZE

        var subBassSum = 0f; var subBassCount = 0
        var bassSum = 0f; var bassCount = 0
        var lowMidSum = 0f; var lowMidCount = 0
        var midSum = 0f; var midCount = 0
        var highMidSum = 0f; var highMidCount = 0
        var trebleSum = 0f; var trebleCount = 0
        var brillianceSum = 0f; var brillianceCount = 0

        for (i in 1 until FFT_SIZE / 2) {
            val freq = i * binWidth
            val mag = magnitudes[i]

            when {
                freq < SUB_BASS_MAX -> { subBassSum += mag; subBassCount++ }
                freq < BASS_MAX -> { bassSum += mag; bassCount++ }
                freq < LOW_MID_MAX -> { lowMidSum += mag; lowMidCount++ }
                freq < MID_MAX -> { midSum += mag; midCount++ }
                freq < HIGH_MID_MAX -> { highMidSum += mag; highMidCount++ }
                freq < TREBLE_MAX -> { trebleSum += mag; trebleCount++ }
                else -> { brillianceSum += mag; brillianceCount++ }
            }
        }

        // Calculate averages and apply smoothing
        val newSubBass = if (subBassCount > 0) subBassSum / subBassCount else 0f
        val newBass = if (bassCount > 0) bassSum / bassCount else 0f
        val newLowMid = if (lowMidCount > 0) lowMidSum / lowMidCount else 0f
        val newMid = if (midCount > 0) midSum / midCount else 0f
        val newHighMid = if (highMidCount > 0) highMidSum / highMidCount else 0f
        val newTreble = if (trebleCount > 0) trebleSum / trebleCount else 0f
        val newBrilliance = if (brillianceCount > 0) brillianceSum / brillianceCount else 0f

        // Apply different smoothing - bass is more responsive
        subBass = lerp(subBass, newSubBass, smoothFast)
        bass = lerp(bass, newBass, smoothFast)
        lowMid = lerp(lowMid, newLowMid, smoothMed)
        mid = lerp(mid, newMid, smoothMed)
        highMid = lerp(highMid, newHighMid, smoothMed)
        treble = lerp(treble, newTreble, smoothMed)
        brilliance = lerp(brilliance, newBrilliance, smoothSlow)

        // Calculate totals
        bassTotal = (subBass + bass) / 2f
        midTotal = (lowMid + mid + highMid) / 3f
        trebleTotal = (treble + brilliance) / 2f
    }

    private fun calculateEnergy() {
        // RMS energy
        var sum = 0f
        for (i in 0 until FFT_SIZE) {
            val idx = (sampleIndex + i) % FFT_SIZE
            sum += sampleBuffer[idx] * sampleBuffer[idx]
        }
        val rms = sqrt(sum / FFT_SIZE)

        // Smooth energy
        val newEnergy = (rms * 3f).coerceIn(0f, 1f)  // Scale up for visibility
        energy = lerp(energy, newEnergy, smoothMed)

        // Track peak with decay
        if (newEnergy > peak) {
            peak = newEnergy
        } else {
            peak = lerp(peak, newEnergy, 0.05f)  // Slow decay
        }

        // Store in history for beat detection
        energyHistory[energyHistoryIndex] = energy
        energyHistoryIndex = (energyHistoryIndex + 1) % energyHistory.size
    }

    private fun detectBeat() {
        val now = System.currentTimeMillis()
        val timeSinceLastBeat = now - lastBeatTime

        // Beat detection: bass energy spike above BASS average (not overall energy)
        // Use bass because it's most rhythmically relevant
        val beatEnergy = (subBass * 0.6f + bass * 0.4f)

        // Store bass energy in history
        bassHistory[bassHistoryIndex] = beatEnergy
        bassHistoryIndex = (bassHistoryIndex + 1) % bassHistory.size

        // Calculate average BASS energy over history
        var avgBassEnergy = 0f
        for (e in bassHistory) avgBassEnergy += e
        avgBassEnergy /= bassHistory.size

        // Also calculate variance to detect transients better
        var variance = 0f
        for (e in bassHistory) {
            val diff = e - avgBassEnergy
            variance += diff * diff
        }
        variance = sqrt(variance / bassHistory.size)

        // Dynamic threshold: average + variance multiplier
        // This makes beat detection adapt to the music's dynamics
        val threshold = avgBassEnergy + variance * BEAT_SENSITIVITY

        if (beatEnergy > threshold &&
            timeSinceLastBeat > BEAT_COOLDOWN_MS &&
            beatEnergy > 0.08f) {  // Lower minimum threshold

            beat = 1f
            onBeat = true
            lastBeatTime = now

            // Record for BPM calculation
            beatTimes.add(now)
            while (beatTimes.size > 16) {
                beatTimes.removeAt(0)
            }

            // Calculate BPM from beat intervals
            if (beatTimes.size >= 4) {
                val intervals = mutableListOf<Long>()
                for (i in 1 until beatTimes.size) {
                    val interval = beatTimes[i] - beatTimes[i - 1]
                    if (interval in 250..2000) {  // Valid beat interval range
                        intervals.add(interval)
                    }
                }
                if (intervals.isNotEmpty()) {
                    val avgInterval = intervals.average()
                    val newBpm = (60000.0 / avgInterval).toFloat()
                    if (newBpm in 60f..200f) {
                        bpm = lerp(bpm, newBpm, 0.2f)
                    }
                }
            }
        } else {
            beat = lerp(beat, 0f, 0.4f)  // Decay for visual pulse effect
            onBeat = false
        }
    }

    private fun calculateFlux() {
        // Spectral flux = sum of positive differences
        var fluxSum = 0f
        for (i in magnitudes.indices) {
            val diff = magnitudes[i] - prevMagnitudes[i]
            if (diff > 0) {
                fluxSum += diff * diff  // Square for emphasis
            }
        }
        val newFlux = sqrt(fluxSum / magnitudes.size)
        flux = lerp(flux, newFlux.coerceIn(0f, 1f), smoothMed)
    }

    private fun calculateCentroid() {
        // Spectral centroid = weighted average of frequencies
        var weightedSum = 0f
        var magSum = 0f
        val binWidth = sampleRate.toFloat() / FFT_SIZE

        for (i in 1 until FFT_SIZE / 2) {
            val freq = i * binWidth
            val mag = magnitudes[i]
            weightedSum += freq * mag
            magSum += mag
        }

        val newCentroid = if (magSum > 0.001f) {
            // Normalize to 0-1 range (assuming max relevant freq is 10kHz)
            (weightedSum / magSum / 10000f).coerceIn(0f, 1f)
        } else 0f

        centroid = lerp(centroid, newCentroid, smoothSlow)
    }

    private fun buildSpectrum() {
        // Map FFT bins to spectrum bands (logarithmic distribution)
        val maxBin = FFT_SIZE / 2

        for (band in 0 until SPECTRUM_BANDS) {
            // Logarithmic frequency distribution
            val lowFreq = 20f * floatPow(2f, band.toFloat() * 10f / SPECTRUM_BANDS)
            val highFreq = 20f * floatPow(2f, (band + 1).toFloat() * 10f / SPECTRUM_BANDS)

            val binWidth = sampleRate.toFloat() / FFT_SIZE
            val lowBin = (lowFreq / binWidth).toInt().coerceIn(1, maxBin - 1)
            val highBin = (highFreq / binWidth).toInt().coerceIn(lowBin + 1, maxBin)

            var sum = 0f
            var count = 0
            for (i in lowBin until highBin) {
                sum += magnitudes[i]
                count++
            }

            val newValue = if (count > 0) sum / count else 0f
            spectrum[band] = lerp(spectrum[band], newValue, smoothMed)
        }
    }

    //endregion

    //region FFT Implementation (Cooley-Tukey)

    private fun fft(real: FloatArray, imag: FloatArray, n: Int) {
        // Bit reversal permutation
        var j = 0
        for (i in 0 until n - 1) {
            if (i < j) {
                var temp = real[i]; real[i] = real[j]; real[j] = temp
                temp = imag[i]; imag[i] = imag[j]; imag[j] = temp
            }
            var k = n / 2
            while (k <= j) {
                j -= k
                k /= 2
            }
            j += k
        }

        // Cooley-Tukey decimation-in-time
        var len = 2
        while (len <= n) {
            val halfLen = len / 2
            val angle = -2.0 * PI / len

            var i = 0
            while (i < n) {
                var wReal = 1.0
                var wImag = 0.0
                val wRotReal = cos(angle)
                val wRotImag = sin(angle)

                for (k in 0 until halfLen) {
                    val evenIdx = i + k
                    val oddIdx = i + k + halfLen

                    val tReal = (wReal * real[oddIdx] - wImag * imag[oddIdx]).toFloat()
                    val tImag = (wReal * imag[oddIdx] + wImag * real[oddIdx]).toFloat()

                    real[oddIdx] = real[evenIdx] - tReal
                    imag[oddIdx] = imag[evenIdx] - tImag
                    real[evenIdx] = real[evenIdx] + tReal
                    imag[evenIdx] = imag[evenIdx] + tImag

                    val newWReal = wReal * wRotReal - wImag * wRotImag
                    wImag = wReal * wRotImag + wImag * wRotReal
                    wReal = newWReal
                }
                i += len
            }
            len *= 2
        }
    }

    //endregion

    //region Utilities

    private fun lerp(a: Float, b: Float, t: Float): Float = a + (b - a) * t

    private fun floatPow(base: Float, exp: Float): Float = Math.pow(base.toDouble(), exp.toDouble()).toFloat()

    //endregion
}
