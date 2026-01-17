package com.vibeplay.vibeplay

import android.media.audiofx.PresetReverb
import android.media.audiofx.EnvironmentalReverb
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Handles Android system audio effects:
 * - Reverb (PresetReverb and EnvironmentalReverb)
 *
 * IMPORTANT: This uses Android's hardware audio effects API, which varies by device.
 *
 * REVERB IMPLEMENTATION NOTE:
 * There are TWO reverb systems in VibePlay:
 *
 * 1. AudioDSP.kt (PREFERRED) - Software Schroeder reverb integrated with VibeAudioEngine.
 *    - Consistent quality across all devices
 *    - Works with native PCM pipeline
 *    - Use setNativeReverbEnabled(), setNativeReverbMix(), setNativeReverbDecay()
 *
 * 2. This class (LEGACY/ALTERNATIVE) - Android PresetReverb/EnvironmentalReverb.
 *    - Quality varies by device hardware
 *    - Uses Android audio session effects
 *    - Useful for devices where software reverb is too CPU-intensive
 *
 * RECOMMENDATION: Use AudioDSP reverb (via VibeAudioEngine) for consistent results.
 * Only use this class if you need Android preset reverbs (Small Room, Hall, etc.)
 * that the user specifically requests, or on low-end devices.
 *
 * WARNING: Do NOT enable both reverb systems simultaneously - they will compound
 * and produce undesirable audio artifacts.
 */
class AudioEffectsHandler : MethodChannel.MethodCallHandler {
    companion object {
        private const val TAG = "AudioEffectsHandler"

        // Preset reverb types
        const val REVERB_NONE = -1
        const val REVERB_SMALL_ROOM = PresetReverb.PRESET_SMALLROOM
        const val REVERB_MEDIUM_ROOM = PresetReverb.PRESET_MEDIUMROOM
        const val REVERB_LARGE_ROOM = PresetReverb.PRESET_LARGEROOM
        const val REVERB_MEDIUM_HALL = PresetReverb.PRESET_MEDIUMHALL
        const val REVERB_LARGE_HALL = PresetReverb.PRESET_LARGEHALL
        const val REVERB_PLATE = PresetReverb.PRESET_PLATE
    }

    private var presetReverb: PresetReverb? = null
    private var environmentalReverb: EnvironmentalReverb? = null
    private var audioSessionId: Int = 0
    private var currentPreset: Int = REVERB_NONE
    private var reverbEnabled: Boolean = false

    // Custom reverb parameters (for environmental reverb)
    private var roomLevel: Int = -1000 // -9000 to 0 millibels
    private var reverbLevel: Int = -1000 // -9000 to 2000 millibels
    private var decayTime: Int = 1000 // 100 to 20000 ms
    private var reverbDelay: Int = 40 // 0 to 100 ms

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setAudioSessionId" -> {
                val sessionId = call.argument<Int>("sessionId") ?: 0
                setAudioSessionId(sessionId)
                result.success(true)
            }
            "setReverbEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                val success = setReverbEnabled(enabled)
                result.success(success)
            }
            "setReverbPreset" -> {
                val preset = call.argument<Int>("preset") ?: REVERB_NONE
                val success = setReverbPreset(preset)
                result.success(success)
            }
            "setCustomReverb" -> {
                val roomLvl = call.argument<Int>("roomLevel") ?: -1000
                val reverbLvl = call.argument<Int>("reverbLevel") ?: -1000
                val decay = call.argument<Int>("decayTime") ?: 1000
                val delay = call.argument<Int>("reverbDelay") ?: 40
                val success = setCustomReverb(roomLvl, reverbLvl, decay, delay)
                result.success(success)
            }
            "getReverbProperties" -> {
                result.success(getReverbProperties())
            }
            "release" -> {
                release()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun setAudioSessionId(sessionId: Int) {
        if (sessionId == audioSessionId && presetReverb != null) {
            return
        }

        release()
        audioSessionId = sessionId

        if (sessionId == 0) {
            Log.w(TAG, "Audio session ID is 0, reverb may not work properly")
            return
        }

        // Initialize preset reverb
        try {
            presetReverb = PresetReverb(0, sessionId).apply {
                enabled = false
            }
            Log.d(TAG, "PresetReverb initialized for session $sessionId")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize PresetReverb: ${e.message}")
        }

        // Initialize environmental reverb for custom settings
        try {
            environmentalReverb = EnvironmentalReverb(0, sessionId).apply {
                enabled = false
            }
            Log.d(TAG, "EnvironmentalReverb initialized for session $sessionId")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize EnvironmentalReverb: ${e.message}")
        }
    }

    private fun setReverbEnabled(enabled: Boolean): Boolean {
        reverbEnabled = enabled
        return try {
            if (currentPreset == REVERB_NONE) {
                // Using custom/environmental reverb
                environmentalReverb?.enabled = enabled
            } else {
                // Using preset reverb
                presetReverb?.enabled = enabled
            }
            Log.d(TAG, "Reverb enabled: $enabled")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set reverb enabled: ${e.message}")
            false
        }
    }

    private fun setReverbPreset(preset: Int): Boolean {
        currentPreset = preset
        return try {
            if (preset == REVERB_NONE) {
                presetReverb?.enabled = false
                Log.d(TAG, "Reverb disabled (NONE preset)")
            } else {
                val reverb = presetReverb
                if (reverb != null) {
                    reverb.preset = preset.toShort()
                    reverb.enabled = reverbEnabled
                    Log.d(TAG, "Set reverb preset to $preset")
                }
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set reverb preset: ${e.message}")
            false
        }
    }

    private fun setCustomReverb(roomLvl: Int, reverbLvl: Int, decay: Int, delay: Int): Boolean {
        roomLevel = roomLvl.coerceIn(-9000, 0)
        reverbLevel = reverbLvl.coerceIn(-9000, 2000)
        decayTime = decay.coerceIn(100, 20000)
        reverbDelay = delay.coerceIn(0, 100)

        // Switch to environmental reverb for custom settings
        currentPreset = REVERB_NONE
        presetReverb?.enabled = false

        return try {
            val envReverb = environmentalReverb
            if (envReverb != null) {
                envReverb.roomLevel = roomLevel.toShort()
                envReverb.reverbLevel = reverbLevel.toShort()
                envReverb.decayTime = decayTime
                envReverb.reverbDelay = reverbDelay
                envReverb.enabled = reverbEnabled
                Log.d(TAG, "Set custom reverb: room=$roomLevel, reverb=$reverbLevel, decay=$decayTime, delay=$reverbDelay")
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set custom reverb: ${e.message}")
            false
        }
    }

    private fun getReverbProperties(): Map<String, Any> {
        val presets = listOf(
            mapOf("id" to REVERB_NONE, "name" to "None"),
            mapOf("id" to REVERB_SMALL_ROOM, "name" to "Small Room"),
            mapOf("id" to REVERB_MEDIUM_ROOM, "name" to "Medium Room"),
            mapOf("id" to REVERB_LARGE_ROOM, "name" to "Large Room"),
            mapOf("id" to REVERB_MEDIUM_HALL, "name" to "Medium Hall"),
            mapOf("id" to REVERB_LARGE_HALL, "name" to "Large Hall"),
            mapOf("id" to REVERB_PLATE, "name" to "Plate")
        )

        return mapOf(
            "presetReverbAvailable" to (presetReverb != null),
            "environmentalReverbAvailable" to (environmentalReverb != null),
            "currentPreset" to currentPreset,
            "enabled" to reverbEnabled,
            "presets" to presets,
            "customSettings" to mapOf(
                "roomLevel" to roomLevel,
                "reverbLevel" to reverbLevel,
                "decayTime" to decayTime,
                "reverbDelay" to reverbDelay
            )
        )
    }

    fun release() {
        try {
            presetReverb?.release()
            presetReverb = null
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release PresetReverb: ${e.message}")
        }

        try {
            environmentalReverb?.release()
            environmentalReverb = null
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release EnvironmentalReverb: ${e.message}")
        }

        audioSessionId = 0
        currentPreset = REVERB_NONE
        reverbEnabled = false
        Log.d(TAG, "Audio effects released")
    }
}
