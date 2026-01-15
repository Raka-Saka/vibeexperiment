package com.vibeplay.vibeplay

import android.media.audiofx.DynamicsProcessing
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi

/**
 * 10-band equalizer using Android's DynamicsProcessing API (Android 9+).
 * This provides real-time audio processing with hardware acceleration.
 *
 * DynamicsProcessing offers:
 * - Pre-EQ with up to 32 bands
 * - Multi-band compressor
 * - Post-EQ
 * - Limiter
 *
 * We use the Pre-EQ stage for our 10-band parametric equalizer.
 */
@RequiresApi(Build.VERSION_CODES.P)
class DynamicsProcessingEqualizer {

    companion object {
        private const val TAG = "DynamicsProcessingEQ"
        const val NUM_BANDS = 10

        // Standard 10-band center frequencies in Hz
        val FREQUENCIES = floatArrayOf(32f, 64f, 125f, 250f, 500f, 1000f, 2000f, 4000f, 8000f, 16000f)

        // Check if DynamicsProcessing is available
        fun isAvailable(): Boolean {
            return Build.VERSION.SDK_INT >= Build.VERSION_CODES.P
        }
    }

    private var dynamicsProcessing: DynamicsProcessing? = null
    private var audioSessionId: Int = 0

    // Current gains in dB for each band (-12 to +12)
    private val bandGains = FloatArray(NUM_BANDS) { 0f }

    // Whether EQ is enabled
    var isEnabled: Boolean = false
        set(value) {
            field = value
            dynamicsProcessing?.enabled = value
        }

    /**
     * Initialize DynamicsProcessing for the given audio session
     */
    fun initialize(sessionId: Int): Boolean {
        if (sessionId == audioSessionId && dynamicsProcessing != null) {
            return true
        }

        release()
        audioSessionId = sessionId

        return try {
            // Create DynamicsProcessing configuration
            val config = createConfig()

            // Create DynamicsProcessing instance
            dynamicsProcessing = DynamicsProcessing(0, sessionId, config).apply {
                enabled = false
            }

            // Configure each EQ band after creation
            for (i in 0 until NUM_BANDS) {
                configureBand(i, FREQUENCIES[i], 0f)
            }

            Log.d(TAG, "DynamicsProcessing initialized with $NUM_BANDS EQ bands")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize DynamicsProcessing: ${e.message}")
            dynamicsProcessing = null
            false
        }
    }

    /**
     * Create DynamicsProcessing.Config for 10-band EQ
     */
    private fun createConfig(): DynamicsProcessing.Config {
        // We want:
        // - Pre-EQ enabled with 10 bands
        // - MBC (multi-band compressor) disabled
        // - Post-EQ disabled
        // - Limiter enabled (to prevent clipping)

        val builder = DynamicsProcessing.Config.Builder(
            DynamicsProcessing.VARIANT_FAVOR_FREQUENCY_RESOLUTION, // Better for EQ
            1, // 1 channel stage (will be applied to all channels)
            true, // Pre-EQ enabled
            NUM_BANDS, // 10 Pre-EQ bands
            false, // MBC disabled
            0, // No MBC bands
            false, // Post-EQ disabled
            0, // No Post-EQ bands
            true // Limiter enabled
        )

        // Configure Pre-EQ stage
        val preEq = DynamicsProcessing.Eq(
            true, // inUse
            true, // enabled
            NUM_BANDS // number of bands
        )
        builder.setPreEqAllChannelsTo(preEq)

        // Configure limiter to prevent clipping
        // Limiter(inUse, enabled, linkGroup, attackTime, releaseTime, ratio, threshold, postGain)
        val limiter = DynamicsProcessing.Limiter(
            true, // inUse
            true, // enabled
            0, // linkGroup (0 = linked)
            1f, // attack time (ms) - fast attack to catch peaks
            50f, // release time (ms)
            10f, // ratio (10:1 limiting above threshold)
            -0.5f, // threshold (dB) - just below 0 to catch peaks
            0f // post gain (dB)
        )
        builder.setLimiterAllChannelsTo(limiter)

        return builder.build()
    }

    /**
     * Configure a single EQ band
     */
    private fun configureBand(bandIndex: Int, frequency: Float, gainDb: Float) {
        val dp = dynamicsProcessing ?: return

        try {
            val eqBand = DynamicsProcessing.EqBand(
                true, // enabled
                frequency,
                gainDb.coerceIn(-12f, 12f)
            )

            // Set for all channels (stereo)
            dp.setPreEqBandAllChannelsTo(bandIndex, eqBand)

        } catch (e: Exception) {
            Log.e(TAG, "Failed to configure band $bandIndex: ${e.message}")
        }
    }

    /**
     * Set gain for a specific band
     * @param band Band index (0-9)
     * @param gainDb Gain in dB (-12 to +12)
     */
    fun setBandGain(band: Int, gainDb: Float) {
        if (band < 0 || band >= NUM_BANDS) return

        val clampedGain = gainDb.coerceIn(-12f, 12f)
        bandGains[band] = clampedGain

        if (dynamicsProcessing != null) {
            configureBand(band, FREQUENCIES[band], clampedGain)
        }
    }

    /**
     * Get current gain for a band
     */
    fun getBandGain(band: Int): Float {
        return if (band in 0 until NUM_BANDS) bandGains[band] else 0f
    }

    /**
     * Set all band gains at once
     */
    fun setAllBands(gains: FloatArray) {
        for (i in 0 until minOf(gains.size, NUM_BANDS)) {
            setBandGain(i, gains[i])
        }
    }

    /**
     * Reset all bands to 0 dB
     */
    fun reset() {
        for (i in 0 until NUM_BANDS) {
            setBandGain(i, 0f)
        }
    }

    /**
     * Get equalizer properties for Flutter
     */
    fun getProperties(): Map<String, Any> {
        return mapOf(
            "numberOfBands" to NUM_BANDS,
            "frequencies" to FREQUENCIES.map { (it * 1000).toInt() }, // In milliHz
            "minLevel" to -1200, // -12 dB in centibels
            "maxLevel" to 1200,  // +12 dB in centibels
            "currentLevels" to bandGains.map { (it * 100).toInt() },
            "type" to "DynamicsProcessing",
            "isHardwareAccelerated" to true
        )
    }

    /**
     * Release resources
     */
    fun release() {
        try {
            dynamicsProcessing?.enabled = false
            dynamicsProcessing?.release()
            dynamicsProcessing = null
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release DynamicsProcessing: ${e.message}")
        }

        audioSessionId = 0
        bandGains.fill(0f)
        Log.d(TAG, "DynamicsProcessing released")
    }
}
