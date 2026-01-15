package com.vibeplay.vibeplay

import com.ryanheise.audioservice.AudioServiceActivity
import com.vibeplay.vibeplay.audio.VibeAudioHandler
import com.vibeplay.vibeplay.widget.WidgetHandler
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

class MainActivity : AudioServiceActivity() {
    private val VIDEO_CHANNEL = "com.vibeplay/video_generator"
    private val EQUALIZER_CHANNEL = "com.vibeplay/equalizer"
    private val LYRICS_CHANNEL = "com.vibeplay/lyrics"
    private val WIDGET_CHANNEL = "com.vibeplay/widget"
    private val AUDIO_EFFECTS_CHANNEL = "com.vibeplay/audio_effects"
    private val VISUALIZER_CHANNEL = "com.vibeplay/visualizer"
    private val VISUALIZER_EVENTS_CHANNEL = "com.vibeplay/visualizer_events"
    private val AUDIO_ANALYSIS_CHANNEL = "com.vibeplay/audio_analysis"

    // New VibeAudioEngine channels
    private val VIBE_AUDIO_CHANNEL = "com.vibeplay/vibe_audio"
    private val VIBE_AUDIO_EVENTS_CHANNEL = "com.vibeplay/vibe_audio_events"
    private val VIBE_AUDIO_PULSE_CHANNEL = "com.vibeplay/vibe_audio_pulse"

    private val scope = CoroutineScope(Dispatchers.Main + Job())
    private val equalizerHandler = EqualizerHandler()
    private val lyricsHandler = LyricsHandler()
    private val audioEffectsHandler = AudioEffectsHandler()
    private lateinit var visualizerHandler: VisualizerHandler
    private lateinit var widgetHandler: WidgetHandler
    private lateinit var vibeAudioHandler: VibeAudioHandler
    private lateinit var audioAnalysisHandler: AudioAnalysisHandler

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize handlers
        widgetHandler = WidgetHandler(this)
        visualizerHandler = VisualizerHandler(this)
        vibeAudioHandler = VibeAudioHandler(this)
        audioAnalysisHandler = AudioAnalysisHandler(this)

        // Audio analysis channel (LUFS loudness measurement)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_ANALYSIS_CHANNEL)
            .setMethodCallHandler(audioAnalysisHandler)

        // Equalizer channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EQUALIZER_CHANNEL)
            .setMethodCallHandler(equalizerHandler)

        // Lyrics channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LYRICS_CHANNEL)
            .setMethodCallHandler(lyricsHandler)

        // Widget channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler(widgetHandler)

        // Audio effects channel (reverb)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_EFFECTS_CHANNEL)
            .setMethodCallHandler(audioEffectsHandler)

        // Visualizer channels (legacy - will be replaced by VibeAudio)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VISUALIZER_CHANNEL)
            .setMethodCallHandler(visualizerHandler)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, VISUALIZER_EVENTS_CHANNEL)
            .setStreamHandler(visualizerHandler)

        // VibeAudioEngine channels - our custom audio engine
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VIBE_AUDIO_CHANNEL)
            .setMethodCallHandler(vibeAudioHandler)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, VIBE_AUDIO_EVENTS_CHANNEL)
            .setStreamHandler(vibeAudioHandler)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, VIBE_AUDIO_PULSE_CHANNEL)
            .setStreamHandler(vibeAudioHandler.createPulseStreamHandler())

        // Video generator channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VIDEO_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "generateVideo" -> {
                    val audioPath = call.argument<String>("audioPath")
                    val outputPath = call.argument<String>("outputPath")
                    val title = call.argument<String>("title") ?: "Untitled"
                    val artist = call.argument<String>("artist") ?: "Unknown"

                    if (audioPath == null || outputPath == null) {
                        result.error("INVALID_ARGS", "Missing audioPath or outputPath", null)
                        return@setMethodCallHandler
                    }

                    scope.launch {
                        try {
                            val generator = VideoGenerator(this@MainActivity)
                            val success = withContext(Dispatchers.IO) {
                                generator.generateWaveformVideo(
                                    audioPath,
                                    outputPath,
                                    title,
                                    artist
                                ) { progress ->
                                    // Could send progress updates via event channel
                                }
                            }
                            result.success(success)
                        } catch (e: Exception) {
                            result.error("VIDEO_ERROR", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
        equalizerHandler.release()
        audioEffectsHandler.release()
        visualizerHandler.release()
        vibeAudioHandler.release()
        audioAnalysisHandler.release()
    }
}
