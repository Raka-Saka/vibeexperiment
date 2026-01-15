package com.vibeplay.vibeplay

import kotlin.math.*

/**
 * Software-based 10-band parametric equalizer using biquad filters.
 * Implements peaking EQ filters based on the Audio EQ Cookbook.
 *
 * Standard 10-band frequencies: 32, 64, 125, 250, 500, 1k, 2k, 4k, 8k, 16k Hz
 */
class SoftwareEqualizer(private val sampleRate: Int = 44100) {

    companion object {
        const val NUM_BANDS = 10

        // Standard 10-band center frequencies in Hz
        val FREQUENCIES = intArrayOf(32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000)

        // Bandwidth in octaves (Q factor related)
        const val BANDWIDTH = 1.0
    }

    // Biquad filter coefficients for each band
    private val filters = Array(NUM_BANDS) { BiquadFilter() }

    // Current gain for each band in dB (-12 to +12)
    private val gains = DoubleArray(NUM_BANDS) { 0.0 }

    // Whether the equalizer is enabled
    var isEnabled: Boolean = false

    init {
        // Initialize all filters with 0 dB gain
        for (i in 0 until NUM_BANDS) {
            updateFilter(i, 0.0)
        }
    }

    /**
     * Set the gain for a specific band
     * @param band Band index (0-9)
     * @param gainDb Gain in decibels (-12 to +12)
     */
    fun setBandGain(band: Int, gainDb: Double) {
        if (band < 0 || band >= NUM_BANDS) return

        val clampedGain = gainDb.coerceIn(-12.0, 12.0)
        gains[band] = clampedGain
        updateFilter(band, clampedGain)
    }

    /**
     * Get the current gain for a band
     */
    fun getBandGain(band: Int): Double {
        return if (band in 0 until NUM_BANDS) gains[band] else 0.0
    }

    /**
     * Set all band gains at once
     */
    fun setAllBands(bandGains: DoubleArray) {
        for (i in 0 until minOf(bandGains.size, NUM_BANDS)) {
            setBandGain(i, bandGains[i])
        }
    }

    /**
     * Reset all bands to 0 dB
     */
    fun reset() {
        for (i in 0 until NUM_BANDS) {
            setBandGain(i, 0.0)
        }
        // Reset filter states
        filters.forEach { it.reset() }
    }

    /**
     * Process a single audio sample through all EQ bands
     * @param sample Input sample (-1.0 to 1.0)
     * @return Processed sample
     */
    fun processSample(sample: Double): Double {
        if (!isEnabled) return sample

        var output = sample
        for (filter in filters) {
            output = filter.process(output)
        }

        // Soft clip to prevent distortion
        return softClip(output)
    }

    /**
     * Process a buffer of audio samples (mono)
     */
    fun processBuffer(buffer: FloatArray) {
        if (!isEnabled) return

        for (i in buffer.indices) {
            buffer[i] = processSample(buffer[i].toDouble()).toFloat()
        }
    }

    /**
     * Process a buffer of audio samples (stereo interleaved)
     */
    fun processStereoBuffer(buffer: FloatArray) {
        if (!isEnabled) return

        // For stereo, we process each channel the same way
        // A more advanced implementation would have separate filter states per channel
        for (i in buffer.indices) {
            buffer[i] = processSample(buffer[i].toDouble()).toFloat()
        }
    }

    /**
     * Process 16-bit PCM samples
     */
    fun processShortBuffer(buffer: ShortArray) {
        if (!isEnabled) return

        for (i in buffer.indices) {
            val sample = buffer[i] / 32768.0
            val processed = processSample(sample)
            buffer[i] = (processed * 32767.0).toInt().coerceIn(-32768, 32767).toShort()
        }
    }

    /**
     * Update biquad filter coefficients for a band
     * Uses peaking EQ filter design from Audio EQ Cookbook
     */
    private fun updateFilter(band: Int, gainDb: Double) {
        val frequency = FREQUENCIES[band].toDouble()
        val gain = 10.0.pow(gainDb / 20.0) // Convert dB to linear

        // Calculate filter coefficients
        val omega = 2.0 * PI * frequency / sampleRate
        val sinOmega = sin(omega)
        val cosOmega = cos(omega)

        // Q factor from bandwidth
        val alpha = sinOmega * sinh(ln(2.0) / 2.0 * BANDWIDTH * omega / sinOmega)

        val a = gain.pow(0.5) // For peaking filter

        // Peaking EQ coefficients
        val b0: Double
        val b1: Double
        val b2: Double
        val a0: Double
        val a1: Double
        val a2: Double

        if (abs(gainDb) < 0.001) {
            // Unity gain - passthrough
            b0 = 1.0
            b1 = 0.0
            b2 = 0.0
            a0 = 1.0
            a1 = 0.0
            a2 = 0.0
        } else if (gainDb > 0) {
            // Boost
            b0 = 1.0 + alpha * a
            b1 = -2.0 * cosOmega
            b2 = 1.0 - alpha * a
            a0 = 1.0 + alpha / a
            a1 = -2.0 * cosOmega
            a2 = 1.0 - alpha / a
        } else {
            // Cut
            b0 = 1.0 + alpha / a
            b1 = -2.0 * cosOmega
            b2 = 1.0 - alpha / a
            a0 = 1.0 + alpha * a
            a1 = -2.0 * cosOmega
            a2 = 1.0 - alpha * a
        }

        // Normalize and set coefficients
        filters[band].setCoefficients(
            b0 / a0,
            b1 / a0,
            b2 / a0,
            a1 / a0,
            a2 / a0
        )
    }

    /**
     * Soft clipping to prevent harsh digital distortion
     */
    private fun softClip(sample: Double): Double {
        return when {
            sample > 1.0 -> 1.0 - exp(-sample + 1.0)
            sample < -1.0 -> -1.0 + exp(sample + 1.0)
            else -> sample
        }
    }

    /**
     * Get equalizer info for Flutter
     */
    fun getProperties(): Map<String, Any> {
        return mapOf(
            "numberOfBands" to NUM_BANDS,
            "frequencies" to FREQUENCIES.map { it * 1000 }, // In milliHz for consistency
            "minLevel" to -1200, // -12 dB in millibels
            "maxLevel" to 1200,  // +12 dB in millibels
            "currentLevels" to gains.map { (it * 100).toInt() },
            "isSoftware" to true
        )
    }
}

/**
 * Biquad filter implementation (Direct Form II Transposed)
 */
class BiquadFilter {
    // Coefficients
    private var b0 = 1.0
    private var b1 = 0.0
    private var b2 = 0.0
    private var a1 = 0.0
    private var a2 = 0.0

    // State variables (for Direct Form II Transposed)
    private var z1 = 0.0
    private var z2 = 0.0

    fun setCoefficients(b0: Double, b1: Double, b2: Double, a1: Double, a2: Double) {
        this.b0 = b0
        this.b1 = b1
        this.b2 = b2
        this.a1 = a1
        this.a2 = a2
    }

    fun reset() {
        z1 = 0.0
        z2 = 0.0
    }

    /**
     * Process a single sample through the filter
     * Using Direct Form II Transposed for better numerical stability
     */
    fun process(input: Double): Double {
        val output = b0 * input + z1
        z1 = b1 * input - a1 * output + z2
        z2 = b2 * input - a2 * output
        return output
    }
}
