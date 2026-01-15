package com.vibeplay.vibeplay.audio

import kotlin.math.*

/**
 * AudioDSP - Native PCM audio processing for VibeAudioEngine.
 *
 * Provides real-time DSP effects directly on PCM samples:
 * - 5-band parametric EQ using biquad filters
 * - Simple stereo reverb using comb + allpass filters
 *
 * All processing is done in-place on 16-bit PCM samples.
 */
class AudioDSP {

    companion object {
        private const val TAG = "AudioDSP"

        // EQ bands (Hz)
        private val EQ_FREQUENCIES = floatArrayOf(60f, 230f, 910f, 3600f, 14000f)
        private const val EQ_BAND_COUNT = 5

        // Reverb parameters
        private const val REVERB_COMB_COUNT = 4
        private const val REVERB_ALLPASS_COUNT = 2
    }

    // Processing state
    private var sampleRate = 44100
    private var channelCount = 2
    private var enabled = false

    // EQ state
    private var eqEnabled = false
    private val eqGains = FloatArray(EQ_BAND_COUNT) { 0f }  // -12 to +12 dB
    private val eqFilters = Array(EQ_BAND_COUNT) { Array(2) { BiquadFilter() } }  // Per channel

    // Reverb state
    private var reverbEnabled = false
    private var reverbMix = 0.3f  // 0-1 wet/dry mix
    private var reverbDecay = 0.5f  // 0-1 decay factor
    private val combFiltersL = Array(REVERB_COMB_COUNT) { CombFilter() }
    private val combFiltersR = Array(REVERB_COMB_COUNT) { CombFilter() }
    private val allpassFiltersL = Array(REVERB_ALLPASS_COUNT) { AllpassFilter() }
    private val allpassFiltersR = Array(REVERB_ALLPASS_COUNT) { AllpassFilter() }

    /**
     * Configure DSP with audio parameters
     */
    fun configure(sampleRate: Int, channelCount: Int) {
        this.sampleRate = sampleRate
        this.channelCount = channelCount

        // Reconfigure EQ filters for new sample rate
        for (band in 0 until EQ_BAND_COUNT) {
            for (ch in 0 until minOf(channelCount, 2)) {
                eqFilters[band][ch].configurePeaking(
                    EQ_FREQUENCIES[band],
                    sampleRate.toFloat(),
                    1.0f,  // Q factor
                    eqGains[band]
                )
            }
        }

        // Configure reverb delay lines
        // Comb filter delays (in samples) - prime numbers for better diffusion
        val combDelays = intArrayOf(
            (0.0297f * sampleRate).toInt(),
            (0.0371f * sampleRate).toInt(),
            (0.0411f * sampleRate).toInt(),
            (0.0437f * sampleRate).toInt()
        )

        // Allpass filter delays
        val allpassDelays = intArrayOf(
            (0.005f * sampleRate).toInt(),
            (0.0017f * sampleRate).toInt()
        )

        for (i in 0 until REVERB_COMB_COUNT) {
            combFiltersL[i].configure(combDelays[i], reverbDecay)
            combFiltersR[i].configure(combDelays[i], reverbDecay)
        }

        for (i in 0 until REVERB_ALLPASS_COUNT) {
            allpassFiltersL[i].configure(allpassDelays[i], 0.5f)
            allpassFiltersR[i].configure(allpassDelays[i], 0.5f)
        }
    }

    /**
     * Process PCM samples in-place.
     * Input: interleaved 16-bit PCM (L, R, L, R, ...)
     */
    fun process(samples: ShortArray) {
        if (!enabled || (!eqEnabled && !reverbEnabled)) return

        // Convert to float for processing
        val floatSamples = FloatArray(samples.size)
        for (i in samples.indices) {
            floatSamples[i] = samples[i] / 32768f
        }

        // Apply EQ
        if (eqEnabled) {
            processEQ(floatSamples)
        }

        // Apply reverb
        if (reverbEnabled) {
            processReverb(floatSamples)
        }

        // Convert back to 16-bit with soft clipping
        for (i in samples.indices) {
            val clipped = softClip(floatSamples[i])
            samples[i] = (clipped * 32767f).toInt().coerceIn(-32768, 32767).toShort()
        }
    }

    /**
     * Process EQ on float samples
     */
    private fun processEQ(samples: FloatArray) {
        if (channelCount == 2) {
            // Stereo processing
            var i = 0
            while (i < samples.size - 1) {
                var left = samples[i]
                var right = samples[i + 1]

                // Apply each EQ band
                for (band in 0 until EQ_BAND_COUNT) {
                    if (eqGains[band] != 0f) {
                        left = eqFilters[band][0].process(left)
                        right = eqFilters[band][1].process(right)
                    }
                }

                samples[i] = left
                samples[i + 1] = right
                i += 2
            }
        } else {
            // Mono processing
            for (i in samples.indices) {
                var sample = samples[i]
                for (band in 0 until EQ_BAND_COUNT) {
                    if (eqGains[band] != 0f) {
                        sample = eqFilters[band][0].process(sample)
                    }
                }
                samples[i] = sample
            }
        }
    }

    /**
     * Process reverb on float samples (Schroeder reverb algorithm)
     */
    private fun processReverb(samples: FloatArray) {
        if (channelCount != 2) return  // Reverb only for stereo

        var i = 0
        while (i < samples.size - 1) {
            val dryL = samples[i]
            val dryR = samples[i + 1]

            // Mix input to mono for reverb input
            val monoIn = (dryL + dryR) * 0.5f

            // Parallel comb filters
            var wetL = 0f
            var wetR = 0f
            for (j in 0 until REVERB_COMB_COUNT) {
                wetL += combFiltersL[j].process(monoIn)
                wetR += combFiltersR[j].process(monoIn)
            }
            wetL /= REVERB_COMB_COUNT
            wetR /= REVERB_COMB_COUNT

            // Series allpass filters for diffusion
            for (j in 0 until REVERB_ALLPASS_COUNT) {
                wetL = allpassFiltersL[j].process(wetL)
                wetR = allpassFiltersR[j].process(wetR)
            }

            // Mix wet/dry
            samples[i] = dryL * (1f - reverbMix) + wetL * reverbMix
            samples[i + 1] = dryR * (1f - reverbMix) + wetR * reverbMix
            i += 2
        }
    }

    /**
     * Soft clipping to prevent harsh digital distortion
     */
    private fun softClip(x: Float): Float {
        return when {
            x > 1f -> 1f - exp(-x + 1f) * 0.36788f
            x < -1f -> -1f + exp(x + 1f) * 0.36788f
            else -> x
        }
    }

    // ============ Public API ============

    fun setEnabled(enabled: Boolean) {
        this.enabled = enabled
    }

    fun isEnabled(): Boolean = enabled

    fun setEQEnabled(enabled: Boolean) {
        this.eqEnabled = enabled
    }

    fun isEQEnabled(): Boolean = eqEnabled

    /**
     * Set EQ band gain in dB (-12 to +12)
     */
    fun setEQBandGain(band: Int, gainDb: Float) {
        if (band < 0 || band >= EQ_BAND_COUNT) return

        val clampedGain = gainDb.coerceIn(-12f, 12f)
        eqGains[band] = clampedGain

        // Update filter coefficients
        for (ch in 0 until minOf(channelCount, 2)) {
            eqFilters[band][ch].configurePeaking(
                EQ_FREQUENCIES[band],
                sampleRate.toFloat(),
                1.0f,
                clampedGain
            )
        }
    }

    fun getEQBandGain(band: Int): Float {
        return if (band in 0 until EQ_BAND_COUNT) eqGains[band] else 0f
    }

    fun getEQBandFrequency(band: Int): Float {
        return if (band in 0 until EQ_BAND_COUNT) EQ_FREQUENCIES[band] else 0f
    }

    fun getEQBandCount(): Int = EQ_BAND_COUNT

    fun setReverbEnabled(enabled: Boolean) {
        this.reverbEnabled = enabled
    }

    fun isReverbEnabled(): Boolean = reverbEnabled

    /**
     * Set reverb wet/dry mix (0-1)
     */
    fun setReverbMix(mix: Float) {
        reverbMix = mix.coerceIn(0f, 1f)
    }

    fun getReverbMix(): Float = reverbMix

    /**
     * Set reverb decay (0-1, affects room size)
     */
    fun setReverbDecay(decay: Float) {
        reverbDecay = decay.coerceIn(0f, 0.99f)

        // Update comb filters
        for (i in 0 until REVERB_COMB_COUNT) {
            combFiltersL[i].setFeedback(reverbDecay)
            combFiltersR[i].setFeedback(reverbDecay)
        }
    }

    fun getReverbDecay(): Float = reverbDecay

    /**
     * Reset all DSP state (call on track change)
     */
    fun reset() {
        for (band in 0 until EQ_BAND_COUNT) {
            for (ch in 0 until 2) {
                eqFilters[band][ch].reset()
            }
        }
        for (i in 0 until REVERB_COMB_COUNT) {
            combFiltersL[i].reset()
            combFiltersR[i].reset()
        }
        for (i in 0 until REVERB_ALLPASS_COUNT) {
            allpassFiltersL[i].reset()
            allpassFiltersR[i].reset()
        }
    }

    // ============ Biquad Filter ============

    /**
     * Second-order IIR filter (biquad) for EQ
     */
    private class BiquadFilter {
        // Coefficients
        private var b0 = 1f
        private var b1 = 0f
        private var b2 = 0f
        private var a1 = 0f
        private var a2 = 0f

        // State
        private var x1 = 0f
        private var x2 = 0f
        private var y1 = 0f
        private var y2 = 0f

        /**
         * Configure as peaking EQ filter
         */
        fun configurePeaking(freq: Float, sampleRate: Float, q: Float, gainDb: Float) {
            val A = 10f.pow(gainDb / 40f)
            val w0 = 2f * PI.toFloat() * freq / sampleRate
            val cosW0 = cos(w0)
            val sinW0 = sin(w0)
            val alpha = sinW0 / (2f * q)

            val a0 = 1f + alpha / A
            b0 = (1f + alpha * A) / a0
            b1 = (-2f * cosW0) / a0
            b2 = (1f - alpha * A) / a0
            a1 = (-2f * cosW0) / a0
            a2 = (1f - alpha / A) / a0
        }

        fun process(input: Float): Float {
            val output = b0 * input + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2

            x2 = x1
            x1 = input
            y2 = y1
            y1 = output

            return output
        }

        fun reset() {
            x1 = 0f; x2 = 0f; y1 = 0f; y2 = 0f
        }
    }

    // ============ Comb Filter ============

    /**
     * Feedback comb filter for reverb
     */
    private class CombFilter {
        private var buffer = FloatArray(0)
        private var bufferIndex = 0
        private var feedback = 0.5f

        fun configure(delaySamples: Int, feedback: Float) {
            buffer = FloatArray(maxOf(1, delaySamples))
            bufferIndex = 0
            this.feedback = feedback
        }

        fun setFeedback(fb: Float) {
            feedback = fb
        }

        fun process(input: Float): Float {
            val delayed = buffer[bufferIndex]
            val output = input + delayed * feedback
            buffer[bufferIndex] = output
            bufferIndex = (bufferIndex + 1) % buffer.size
            return delayed
        }

        fun reset() {
            buffer.fill(0f)
            bufferIndex = 0
        }
    }

    // ============ Allpass Filter ============

    /**
     * Allpass filter for reverb diffusion
     */
    private class AllpassFilter {
        private var buffer = FloatArray(0)
        private var bufferIndex = 0
        private var coefficient = 0.5f

        fun configure(delaySamples: Int, coefficient: Float) {
            buffer = FloatArray(maxOf(1, delaySamples))
            bufferIndex = 0
            this.coefficient = coefficient
        }

        fun process(input: Float): Float {
            val delayed = buffer[bufferIndex]
            val output = -coefficient * input + delayed
            buffer[bufferIndex] = input + coefficient * delayed
            bufferIndex = (bufferIndex + 1) % buffer.size
            return output
        }

        fun reset() {
            buffer.fill(0f)
            bufferIndex = 0
        }
    }
}
