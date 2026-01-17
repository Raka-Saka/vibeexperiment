package com.vibeplay.vibeplay

import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.Virtualizer
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Handles equalizer functionality with multiple backends:
 * 1. DynamicsProcessing (Android 9+) - True 10-band hardware-accelerated EQ
 * 2. System Equalizer fallback - Uses device's native bands
 *
 * Plus hardware bass boost and virtualizer effects.
 */
class EqualizerHandler : MethodChannel.MethodCallHandler {
    companion object {
        private const val TAG = "EqualizerHandler"
        const val NUM_BANDS = 10
    }

    // Primary: DynamicsProcessing-based 10-band EQ (Android 9+)
    private var dynamicsEq: DynamicsProcessingEqualizer? = null

    // Fallback: System equalizer (limited bands)
    private var systemEqualizer: Equalizer? = null
    private var systemBandCount = 5

    // Hardware effects
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null

    private var audioSessionId: Int = 0
    private var isUsingDynamicsProcessing = false

    // Track band gains for consistency
    private val bandGains = FloatArray(NUM_BANDS) { 0f }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setAudioSessionId" -> {
                val sessionId = call.argument<Int>("sessionId") ?: 0
                val initResult = setAudioSessionId(sessionId)
                result.success(initResult)
            }
            "setEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                val success = setEnabled(enabled)
                result.success(success)
            }
            "setBandLevel" -> {
                val band = call.argument<Int>("band") ?: 0
                val level = call.argument<Int>("level") ?: 0
                val success = setBandLevel(band, level)
                result.success(success)
            }
            "setAllBands" -> {
                @Suppress("UNCHECKED_CAST")
                val levels = call.argument<List<Int>>("levels") ?: emptyList()
                val success = setAllBands(levels)
                result.success(success)
            }
            "setBassBoost" -> {
                val strength = call.argument<Int>("strength") ?: 0
                val success = setBassBoostStrength(strength.toShort())
                result.success(success)
            }
            "setVirtualizer" -> {
                val strength = call.argument<Int>("strength") ?: 0
                val success = setVirtualizerStrength(strength.toShort())
                result.success(success)
            }
            "getEqualizerProperties" -> {
                result.success(getEqualizerProperties())
            }
            "release" -> {
                release()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Initialize audio effects for the given session ID.
     * Returns a map with initialization status so Flutter knows what's available.
     */
    private fun setAudioSessionId(sessionId: Int): Map<String, Any> {
        if (sessionId == audioSessionId && (dynamicsEq != null || systemEqualizer != null)) {
            return mapOf(
                "success" to true,
                "alreadyInitialized" to true,
                "eqType" to if (isUsingDynamicsProcessing) "DynamicsProcessing" else "SystemEqualizer",
                "bandCount" to if (isUsingDynamicsProcessing) NUM_BANDS else systemBandCount
            )
        }

        release()
        audioSessionId = sessionId

        var eqInitialized = false
        var eqType = "None"
        var eqBandCount = 0
        var eqError: String? = null

        if (sessionId == 0) {
            Log.w(TAG, "Audio session ID is 0, effects may not work properly")
            return mapOf(
                "success" to false,
                "error" to "Invalid audio session ID (0)",
                "eqType" to "None",
                "bandCount" to 0
            )
        }

        // Try DynamicsProcessing first (Android 9+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                dynamicsEq = DynamicsProcessingEqualizer()
                if (dynamicsEq!!.initialize(sessionId)) {
                    isUsingDynamicsProcessing = true
                    eqInitialized = true
                    eqType = "DynamicsProcessing"
                    eqBandCount = NUM_BANDS
                    Log.d(TAG, "Using DynamicsProcessing for 10-band EQ")
                } else {
                    dynamicsEq = null
                    eqError = "DynamicsProcessing initialization returned false"
                }
            } catch (e: Exception) {
                Log.w(TAG, "DynamicsProcessing not available: ${e.message}")
                dynamicsEq = null
                eqError = "DynamicsProcessing exception: ${e.message}"
            }
        }

        // Fallback to system equalizer
        if (dynamicsEq == null) {
            try {
                systemEqualizer = Equalizer(0, sessionId).apply {
                    enabled = false
                }
                systemBandCount = systemEqualizer?.numberOfBands?.toInt() ?: 5
                isUsingDynamicsProcessing = false
                eqInitialized = true
                eqType = "SystemEqualizer"
                eqBandCount = systemBandCount
                eqError = null  // Clear any previous error since fallback succeeded
                Log.d(TAG, "Using system equalizer with $systemBandCount bands")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize system equalizer: ${e.message}")
                eqError = "System equalizer exception: ${e.message}"
            }
        }

        // Initialize bass boost
        var bassBoostInitialized = false
        try {
            bassBoost = BassBoost(0, sessionId).apply {
                enabled = false
            }
            bassBoostInitialized = true
            Log.d(TAG, "BassBoost initialized")
        } catch (e: Exception) {
            Log.w(TAG, "BassBoost not available: ${e.message}")
        }

        // Initialize virtualizer
        var virtualizerInitialized = false
        try {
            virtualizer = Virtualizer(0, sessionId).apply {
                enabled = false
            }
            virtualizerInitialized = true
            Log.d(TAG, "Virtualizer initialized")
        } catch (e: Exception) {
            Log.w(TAG, "Virtualizer not available: ${e.message}")
        }

        return mutableMapOf<String, Any>(
            "success" to eqInitialized,
            "eqType" to eqType,
            "bandCount" to eqBandCount,
            "isHardwareAccelerated" to (eqType == "DynamicsProcessing"),
            "bassBoostAvailable" to bassBoostInitialized,
            "virtualizerAvailable" to virtualizerInitialized
        ).apply {
            if (eqError != null && !eqInitialized) {
                put("error", eqError!!)
            }
            // Include fallback info if we fell back from DynamicsProcessing
            if (eqType == "SystemEqualizer" && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                put("fallbackReason", "DynamicsProcessing unavailable, using system equalizer")
            }
        }
    }

    private fun setEnabled(enabled: Boolean): Boolean {
        return try {
            if (isUsingDynamicsProcessing && dynamicsEq != null) {
                dynamicsEq?.isEnabled = enabled
            } else {
                systemEqualizer?.enabled = enabled
            }

            bassBoost?.enabled = enabled
            virtualizer?.enabled = enabled

            val eqType = if (isUsingDynamicsProcessing) "DynamicsProcessing 10-band" else "System ${systemBandCount}-band"
            Log.d(TAG, "EQ enabled: $enabled (using $eqType)")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set enabled: ${e.message}")
            false
        }
    }

    /**
     * Set band level
     * @param band Band index (0-9 for 10-band mode)
     * @param level Level in centibels (-1200 to +1200 = -12dB to +12dB)
     */
    private fun setBandLevel(band: Int, level: Int): Boolean {
        val gainDb = level / 100f
        bandGains[band.coerceIn(0, NUM_BANDS - 1)] = gainDb

        return try {
            if (isUsingDynamicsProcessing && dynamicsEq != null) {
                // DynamicsProcessing: Direct 10-band support
                dynamicsEq?.setBandGain(band, gainDb)
                Log.d(TAG, "DynamicsProcessing: Set band $band to ${gainDb}dB")
                true
            } else if (systemEqualizer != null) {
                // System EQ: Map 10 bands to available bands
                val mappedBand = mapToSystemBand(band)
                if (mappedBand >= 0 && mappedBand < systemBandCount) {
                    val millibels = (gainDb * 100).toInt().toShort()
                    val range = systemEqualizer!!.bandLevelRange
                    val clampedLevel = millibels.coerceIn(range[0], range[1])
                    systemEqualizer?.setBandLevel(mappedBand.toShort(), clampedLevel)
                    Log.d(TAG, "System EQ: Set band $mappedBand to $clampedLevel millibels")
                }
                true
            } else {
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set band level: ${e.message}")
            false
        }
    }

    /**
     * Map 10-band index to system equalizer bands
     */
    private fun mapToSystemBand(band10: Int): Int {
        if (systemBandCount >= 10) return band10
        if (systemBandCount == 5) {
            // Map 10 bands to 5 bands
            // 0,1 -> 0, 2,3 -> 1, 4,5 -> 2, 6,7 -> 3, 8,9 -> 4
            return band10 / 2
        }
        // General mapping
        return (band10 * systemBandCount) / NUM_BANDS
    }

    /**
     * Set all bands at once
     */
    private fun setAllBands(levels: List<Int>): Boolean {
        return try {
            for (i in levels.indices) {
                if (i < NUM_BANDS) {
                    setBandLevel(i, levels[i])
                }
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set all bands: ${e.message}")
            false
        }
    }

    private fun setBassBoostStrength(strength: Short): Boolean {
        val bb = bassBoost ?: return false
        return try {
            if (bb.strengthSupported) {
                val clampedStrength = strength.coerceIn(0, 1000)
                // Log warning if value was clamped (helps debug Flutter layer issues)
                if (clampedStrength != strength) {
                    Log.w(TAG, "Bass boost strength clamped: $strength -> $clampedStrength (valid range: 0-1000)")
                }
                bb.setStrength(clampedStrength)
                Log.d(TAG, "Set bass boost strength to $clampedStrength")
                true
            } else {
                Log.w(TAG, "Bass boost strength not supported on this device")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set bass boost: ${e.message}")
            false
        }
    }

    private fun setVirtualizerStrength(strength: Short): Boolean {
        val virt = virtualizer ?: return false
        return try {
            if (virt.strengthSupported) {
                val clampedStrength = strength.coerceIn(0, 1000)
                // Log warning if value was clamped (helps debug Flutter layer issues)
                if (clampedStrength != strength) {
                    Log.w(TAG, "Virtualizer strength clamped: $strength -> $clampedStrength (valid range: 0-1000)")
                }
                virt.setStrength(clampedStrength)
                Log.d(TAG, "Set virtualizer strength to $clampedStrength")
                true
            } else {
                Log.w(TAG, "Virtualizer strength not supported on this device")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set virtualizer: ${e.message}")
            false
        }
    }

    /**
     * Get equalizer properties
     */
    private fun getEqualizerProperties(): Map<String, Any> {
        return if (isUsingDynamicsProcessing && dynamicsEq != null) {
            dynamicsEq!!.getProperties()
        } else {
            // System equalizer properties
            val eq = systemEqualizer
            if (eq != null) {
                val frequencies = mutableListOf<Int>()
                val currentLevels = mutableListOf<Int>()

                for (i in 0 until systemBandCount) {
                    frequencies.add(eq.getCenterFreq(i.toShort()))
                    currentLevels.add(eq.getBandLevel(i.toShort()).toInt())
                }

                val range = eq.bandLevelRange
                mapOf(
                    "numberOfBands" to systemBandCount,
                    "frequencies" to frequencies,
                    "minLevel" to range[0].toInt(),
                    "maxLevel" to range[1].toInt(),
                    "currentLevels" to currentLevels,
                    "type" to "SystemEqualizer",
                    "isHardwareAccelerated" to false
                )
            } else {
                // Default/fallback properties
                mapOf(
                    "numberOfBands" to NUM_BANDS,
                    "frequencies" to listOf(32000, 64000, 125000, 250000, 500000, 1000000, 2000000, 4000000, 8000000, 16000000),
                    "minLevel" to -1200,
                    "maxLevel" to 1200,
                    "currentLevels" to bandGains.map { (it * 100).toInt() },
                    "type" to "Software",
                    "isHardwareAccelerated" to false
                )
            }
        }.toMutableMap().apply {
            put("bassBoostSupported", bassBoost?.strengthSupported ?: false)
            put("virtualizerSupported", virtualizer?.strengthSupported ?: false)
        }
    }

    fun release() {
        try {
            dynamicsEq?.release()
            dynamicsEq = null
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release DynamicsProcessing: ${e.message}")
        }

        try {
            systemEqualizer?.release()
            systemEqualizer = null
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release system equalizer: ${e.message}")
        }

        try {
            bassBoost?.release()
            bassBoost = null
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release bass boost: ${e.message}")
        }

        try {
            virtualizer?.release()
            virtualizer = null
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release virtualizer: ${e.message}")
        }

        audioSessionId = 0
        isUsingDynamicsProcessing = false
        bandGains.fill(0f)
        Log.d(TAG, "Audio effects released")
    }
}
