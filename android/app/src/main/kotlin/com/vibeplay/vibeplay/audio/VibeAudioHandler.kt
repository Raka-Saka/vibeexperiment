package com.vibeplay.vibeplay.audio

import android.content.Context
import android.net.Uri
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * VibeAudioHandler - Flutter interface for VibeAudioEngine.
 *
 * Handles method channel calls from Flutter and sends events back.
 */
class VibeAudioHandler(private val context: Context) :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    companion object {
        private const val TAG = "VibeAudioHandler"
    }

    private val engine = VibeAudioEngine(context)
    private var eventSink: EventChannel.EventSink? = null

    // Pulse event channel (separate for high-frequency updates)
    private var pulseStreamHandler: PulseStreamHandler? = null

    init {
        // Set up engine callbacks
        engine.onStateChanged = { state ->
            sendEvent("stateChanged", mapOf("state" to state.name))
        }

        engine.onPositionChanged = { position ->
            sendEvent("positionChanged", mapOf("position" to position))
        }

        engine.onDurationChanged = { duration ->
            sendEvent("durationChanged", mapOf("duration" to duration))
        }

        engine.onCompletion = {
            sendEvent("completed", null)
        }

        engine.onError = { error ->
            sendEvent("error", mapOf("message" to error))
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "prepare" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_ARG", "Path is required", null)
                        return
                    }
                    val success = engine.prepare(path)
                    result.success(mapOf(
                        "success" to success,
                        "duration" to engine.getDuration(),
                        "audioSessionId" to engine.getAudioSessionId()
                    ))
                }

                "play" -> {
                    engine.play()
                    result.success(true)
                }

                "pause" -> {
                    engine.pause()
                    result.success(true)
                }

                "resume" -> {
                    engine.resume()
                    result.success(true)
                }

                "stop" -> {
                    engine.stop()
                    result.success(true)
                }

                "seekTo" -> {
                    val position = call.argument<Number>("position")?.toLong() ?: 0
                    engine.seekTo(position)
                    result.success(true)
                }

                "getPosition" -> {
                    result.success(engine.getPosition())
                }

                "getDuration" -> {
                    result.success(engine.getDuration())
                }

                "isPlaying" -> {
                    result.success(engine.isPlaying())
                }

                "getAudioSessionId" -> {
                    result.success(engine.getAudioSessionId())
                }

                "release" -> {
                    engine.release()
                    result.success(true)
                }

                "getDeviceCapabilities" -> {
                    result.success(getDeviceCapabilities())
                }

                // Gapless playback methods
                "setGaplessEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    engine.setGaplessEnabled(enabled)
                    result.success(true)
                }

                "prepareNextTrack" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_ARG", "Path is required", null)
                        return
                    }
                    val success = engine.prepareNextTrack(path)
                    result.success(success)
                }

                "isNextTrackReady" -> {
                    result.success(engine.isNextTrackReady())
                }

                "transitionToNextTrack" -> {
                    val success = engine.transitionToNextTrack()
                    result.success(mapOf(
                        "success" to success,
                        "duration" to engine.getDuration(),
                        "audioSessionId" to engine.getAudioSessionId()
                    ))
                }

                "clearNextTrack" -> {
                    engine.clearNextTrack()
                    result.success(true)
                }

                // Playback controls
                "setSpeed" -> {
                    val speed = call.argument<Double>("speed")?.toFloat() ?: 1.0f
                    engine.setSpeed(speed)
                    result.success(true)
                }

                "getSpeed" -> {
                    result.success(engine.getSpeed().toDouble())
                }

                "setVolume" -> {
                    val volume = call.argument<Double>("volume")?.toFloat() ?: 1.0f
                    engine.setVolume(volume)
                    result.success(true)
                }

                "getVolume" -> {
                    result.success(engine.getVolume().toDouble())
                }

                // Crossfade
                "setCrossfadeEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    engine.setCrossfadeEnabled(enabled)
                    result.success(true)
                }

                "isCrossfadeEnabled" -> {
                    result.success(engine.isCrossfadeEnabled())
                }

                "setCrossfadeDuration" -> {
                    val durationMs = call.argument<Int>("durationMs") ?: 3000
                    engine.setCrossfadeDuration(durationMs)
                    result.success(true)
                }

                "getCrossfadeDuration" -> {
                    result.success(engine.getCrossfadeDuration())
                }

                "startCrossfade" -> {
                    val success = engine.startCrossfade()
                    result.success(success)
                }

                // Native DSP methods
                "setDSPEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    engine.setDSPEnabled(enabled)
                    result.success(true)
                }

                "isDSPEnabled" -> {
                    result.success(engine.isDSPEnabled())
                }

                "setNativeEQEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    engine.setNativeEQEnabled(enabled)
                    result.success(true)
                }

                "isNativeEQEnabled" -> {
                    result.success(engine.isNativeEQEnabled())
                }

                "setNativeEQBandGain" -> {
                    val band = call.argument<Int>("band") ?: 0
                    val gain = call.argument<Double>("gain")?.toFloat() ?: 0f
                    engine.setNativeEQBandGain(band, gain)
                    result.success(true)
                }

                "getNativeEQBandGain" -> {
                    val band = call.argument<Int>("band") ?: 0
                    result.success(engine.getNativeEQBandGain(band).toDouble())
                }

                "getNativeEQBandFrequency" -> {
                    val band = call.argument<Int>("band") ?: 0
                    result.success(engine.getNativeEQBandFrequency(band).toDouble())
                }

                "getNativeEQBandCount" -> {
                    result.success(engine.getNativeEQBandCount())
                }

                "setNativeReverbEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    engine.setNativeReverbEnabled(enabled)
                    result.success(true)
                }

                "isNativeReverbEnabled" -> {
                    result.success(engine.isNativeReverbEnabled())
                }

                "setNativeReverbMix" -> {
                    val mix = call.argument<Double>("mix")?.toFloat() ?: 0.3f
                    engine.setNativeReverbMix(mix)
                    result.success(true)
                }

                "getNativeReverbMix" -> {
                    result.success(engine.getNativeReverbMix().toDouble())
                }

                "setNativeReverbDecay" -> {
                    val decay = call.argument<Double>("decay")?.toFloat() ?: 0.5f
                    engine.setNativeReverbDecay(decay)
                    result.success(true)
                }

                "getNativeReverbDecay" -> {
                    result.success(engine.getNativeReverbDecay().toDouble())
                }

                "resetDSP" -> {
                    engine.resetDSP()
                    result.success(true)
                }

                // Pitch shifting methods
                "setPitch" -> {
                    val semitones = call.argument<Double>("semitones")?.toFloat() ?: 0f
                    engine.setPitch(semitones)
                    result.success(true)
                }

                "getPitch" -> {
                    result.success(engine.getPitch().toDouble())
                }

                "isPitchEnabled" -> {
                    result.success(engine.isPitchEnabled())
                }

                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in ${call.method}: ${e.message}", e)
            result.error("ERROR", e.message, null)
        }
    }

    // EventChannel.StreamHandler for state events
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        engine.setEventSink(events)
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        engine.setEventSink(null)
    }

    /**
     * Create a stream handler for pulse events
     */
    fun createPulseStreamHandler(): EventChannel.StreamHandler {
        if (pulseStreamHandler == null) {
            pulseStreamHandler = PulseStreamHandler(engine)
        }
        return pulseStreamHandler!!
    }

    private fun sendEvent(type: String, data: Map<String, Any>?) {
        eventSink?.success(mapOf(
            "type" to type,
            "data" to (data ?: emptyMap<String, Any>())
        ))
    }

    /**
     * Get device audio capabilities for quality optimization
     */
    private fun getDeviceCapabilities(): Map<String, Any> {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager

        // Get native sample rate
        val nativeSampleRate = audioManager.getProperty(android.media.AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE)?.toIntOrNull() ?: 44100

        // Get native buffer size
        val nativeBufferSize = audioManager.getProperty(android.media.AudioManager.PROPERTY_OUTPUT_FRAMES_PER_BUFFER)?.toIntOrNull() ?: 256

        // Check for low-latency support
        val hasLowLatency = context.packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_AUDIO_LOW_LATENCY)

        // Check for pro audio support (Android 6.0+)
        val hasProAudio = context.packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_AUDIO_PRO)

        // Supported formats
        val supportedFormats = mutableListOf("mp3", "aac", "flac", "wav", "ogg")

        return mapOf(
            "nativeSampleRate" to nativeSampleRate,
            "nativeBufferSize" to nativeBufferSize,
            "hasLowLatency" to hasLowLatency,
            "hasProAudio" to hasProAudio,
            "supportedFormats" to supportedFormats,
            "androidApiLevel" to android.os.Build.VERSION.SDK_INT,
            "deviceModel" to android.os.Build.MODEL,
            "manufacturer" to android.os.Build.MANUFACTURER
        )
    }

    fun release() {
        engine.release()
        eventSink = null
        pulseStreamHandler = null
    }

    /**
     * Inner class for pulse event streaming
     */
    private class PulseStreamHandler(private val engine: VibeAudioEngine) : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            engine.setPulseEventSink(events)
        }

        override fun onCancel(arguments: Any?) {
            engine.setPulseEventSink(null)
        }
    }
}
