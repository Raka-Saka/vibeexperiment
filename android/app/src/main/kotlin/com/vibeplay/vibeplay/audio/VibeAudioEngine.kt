package com.vibeplay.vibeplay.audio

import android.content.Context
import android.media.*
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.PowerManager
import android.util.Log
import io.flutter.plugin.common.EventChannel
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.*

/**
 * VibeAudioEngine - The heart of VibePlay's audio system.
 *
 * A custom audio engine built from the ground up with visualization as a
 * first-class citizen. This gives us direct access to PCM data for
 * real-time FFT analysis and beat detection.
 *
 * Architecture:
 * Audio File → MediaExtractor → MediaCodec → PCM Buffer → AudioTrack
 *                                                ↓
 *                                          AudioPulse (FFT)
 *                                                ↓
 *                                          Flutter Shader
 */
class VibeAudioEngine(private val context: Context) {

    companion object {
        private const val TAG = "VibeAudioEngine"
        private const val BUFFER_SIZE_FACTOR = 2
        private const val SAMPLE_RATE = 44100
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_OUT_STEREO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT

        // Hi-res audio constants
        private const val HI_RES_SAMPLE_RATE = 96000
        private const val HI_RES_AUDIO_FORMAT = AudioFormat.ENCODING_PCM_FLOAT
    }

    // Device capabilities
    private var lowLatencySupported = false
    private var proAudioSupported = false
    private var hiResAudioSupported = false
    private var nativeSampleRate = SAMPLE_RATE
    private var nativeBufferSize = 256

    // Audio focus handling
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var audioFocusRequest: AudioFocusRequest? = null
    private var hasAudioFocus = false
    private var shouldResumeOnFocusGain = false
    private var previousVolume: Float = 1.0f

    // WakeLock to prevent CPU sleep during background playback
    private val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
    private var wakeLock: PowerManager.WakeLock? = null

    private val audioFocusChangeListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            AudioManager.AUDIOFOCUS_GAIN -> {
                Log.d(TAG, "Audio focus GAINED")
                hasAudioFocus = true
                // Restore volume if we ducked
                audioTrack?.setVolume(previousVolume)
                // Resume if we were playing before focus loss
                if (shouldResumeOnFocusGain && isPrepared.get()) {
                    shouldResumeOnFocusGain = false
                    mainHandler.post { resume() }
                }
            }
            AudioManager.AUDIOFOCUS_LOSS -> {
                // Permanent loss - another app took focus
                Log.d(TAG, "Audio focus LOST (permanent)")
                hasAudioFocus = false
                shouldResumeOnFocusGain = false
                if (isPlaying.get()) {
                    mainHandler.post { pause() }
                }
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                // Temporary loss - e.g., phone call
                Log.d(TAG, "Audio focus LOST (transient)")
                hasAudioFocus = false
                if (isPlaying.get()) {
                    shouldResumeOnFocusGain = true
                    mainHandler.post { pause() }
                }
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                // Brief interruption - e.g., navigation voice
                Log.d(TAG, "Audio focus LOST (can duck)")
                // Duck the volume instead of pausing
                previousVolume = 1.0f
                audioTrack?.setVolume(0.2f)
            }
        }
    }

    // State
    enum class State { IDLE, PREPARING, READY, PLAYING, PAUSED, STOPPED, ERROR }

    private var state = State.IDLE
    private val isPlaying = AtomicBoolean(false)
    private val isPrepared = AtomicBoolean(false)

    // Audio components
    private var mediaExtractor: MediaExtractor? = null
    private var mediaCodec: MediaCodec? = null
    private var audioTrack: AudioTrack? = null

    // Threading
    private var decodeThread: HandlerThread? = null
    private var decodeHandler: Handler? = null
    private var playbackThread: Thread? = null

    // Audio info
    private var sampleRate = SAMPLE_RATE
    private var channelCount = 2
    private var durationMs: Long = 0
    private val positionUs = AtomicLong(0)

    // Gapless playback - pre-loaded next track
    private var nextTrackPath: String? = null
    private var nextMediaExtractor: MediaExtractor? = null
    private var nextMediaCodec: MediaCodec? = null
    private var nextPrepared = AtomicBoolean(false)
    private var nextDurationMs: Long = 0
    private var nextSampleRate = SAMPLE_RATE
    private var nextChannelCount = 2
    private var gaplessEnabled = true

    // Playback controls
    private var playbackSpeed: Float = 1.0f
    private var volume: Float = 1.0f

    // Crossfade support
    private var crossfadeEnabled = false
    private var crossfadeDurationMs: Int = 3000
    private var isCrossfading = AtomicBoolean(false)
    private var crossfadeVolume: Float = 1.0f  // Current track volume during crossfade
    private var nextTrackVolume: Float = 0.0f  // Next track volume during crossfade
    private var nextAudioTrack: AudioTrack? = null  // Second AudioTrack for crossfade
    private var crossfadePlaybackThread: Thread? = null  // Thread for next track playback during crossfade

    // PCM buffer for visualization - this is the key!
    private val pcmBuffer = ShortArray(4096)  // Circular buffer
    private var pcmBufferIndex = 0
    private val pcmLock = Object()

    // Audio Pulse - our visualization engine
    private val audioPulse = AudioPulse()

    // Audio DSP - native effects processing
    private val audioDSP = AudioDSP()

    // Pitch shifter - independent pitch control without tempo change
    private val pitchShifter = SonicPitchShifter()

    // Event sink for Flutter
    private var eventSink: EventChannel.EventSink? = null
    private var pulseEventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(android.os.Looper.getMainLooper())

    // Callbacks
    var onStateChanged: ((State) -> Unit)? = null
    var onPositionChanged: ((Long) -> Unit)? = null
    var onDurationChanged: ((Long) -> Unit)? = null
    var onError: ((String) -> Unit)? = null
    var onCompletion: (() -> Unit)? = null

    init {
        detectDeviceCapabilities()
    }

    /**
     * Detect device audio capabilities for optimized playback
     */
    private fun detectDeviceCapabilities() {
        // Check for low-latency audio support (API 21+)
        lowLatencySupported = context.packageManager.hasSystemFeature(
            android.content.pm.PackageManager.FEATURE_AUDIO_LOW_LATENCY
        )

        // Check for pro audio support (API 23+)
        proAudioSupported = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            context.packageManager.hasSystemFeature(
                android.content.pm.PackageManager.FEATURE_AUDIO_PRO
            )
        } else {
            false
        }

        // Get native sample rate and buffer size
        val sampleRateStr = audioManager.getProperty(AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE)
        val bufferSizeStr = audioManager.getProperty(AudioManager.PROPERTY_OUTPUT_FRAMES_PER_BUFFER)

        nativeSampleRate = sampleRateStr?.toIntOrNull() ?: SAMPLE_RATE
        nativeBufferSize = bufferSizeStr?.toIntOrNull() ?: 256

        // Check for hi-res audio support (24-bit/96kHz)
        hiResAudioSupported = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            // Check if device supports float audio format (higher precision)
            try {
                val testFormat = AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                    .setSampleRate(HI_RES_SAMPLE_RATE)
                    .setChannelMask(CHANNEL_CONFIG)
                    .build()
                val minBuffer = AudioTrack.getMinBufferSize(
                    HI_RES_SAMPLE_RATE,
                    CHANNEL_CONFIG,
                    AudioFormat.ENCODING_PCM_FLOAT
                )
                minBuffer > 0
            } catch (e: Exception) {
                false
            }
        } else {
            false
        }

        Log.d(TAG, "Device capabilities: lowLatency=$lowLatencySupported, proAudio=$proAudioSupported, " +
                "hiRes=$hiResAudioSupported, nativeRate=$nativeSampleRate, nativeBuffer=$nativeBufferSize")
    }

    /**
     * Get device audio capabilities for Flutter
     */
    fun getDeviceCapabilities(): Map<String, Any> {
        return mapOf(
            "lowLatencySupported" to lowLatencySupported,
            "proAudioSupported" to proAudioSupported,
            "hiResAudioSupported" to hiResAudioSupported,
            "nativeSampleRate" to nativeSampleRate,
            "nativeBufferSize" to nativeBufferSize,
            "apiLevel" to Build.VERSION.SDK_INT,
            "deviceModel" to Build.MODEL,
            "manufacturer" to Build.MANUFACTURER
        )
    }

    //region Public API

    /**
     * Prepare an audio file for playback
     */
    fun prepare(uri: Uri): Boolean {
        return prepare(uri.toString())
    }

    fun prepare(path: String): Boolean {
        Log.d(TAG, "Preparing: $path")

        try {
            release()
            setState(State.PREPARING)

            // Create and configure MediaExtractor
            mediaExtractor = MediaExtractor().apply {
                if (path.startsWith("content://") || path.startsWith("file://")) {
                    setDataSource(context, Uri.parse(path), null)
                } else {
                    setDataSource(path)
                }
            }

            // Find audio track
            val audioTrackIndex = findAudioTrack()
            if (audioTrackIndex < 0) {
                Log.e(TAG, "No audio track found")
                setState(State.ERROR)
                return false
            }

            mediaExtractor?.selectTrack(audioTrackIndex)
            val format = mediaExtractor?.getTrackFormat(audioTrackIndex)

            // Get audio properties
            sampleRate = format?.getInteger(MediaFormat.KEY_SAMPLE_RATE) ?: SAMPLE_RATE
            channelCount = format?.getInteger(MediaFormat.KEY_CHANNEL_COUNT) ?: 2
            durationMs = (format?.getLong(MediaFormat.KEY_DURATION) ?: 0) / 1000

            Log.d(TAG, "Audio: ${sampleRate}Hz, ${channelCount}ch, ${durationMs}ms")
            onDurationChanged?.invoke(durationMs)

            // Create MediaCodec decoder
            val mime = format?.getString(MediaFormat.KEY_MIME) ?: "audio/mpeg"
            mediaCodec = MediaCodec.createDecoderByType(mime).apply {
                configure(format, null, null, 0)
            }

            // Create AudioTrack
            val minBufferSize = AudioTrack.getMinBufferSize(
                sampleRate,
                if (channelCount == 1) AudioFormat.CHANNEL_OUT_MONO else CHANNEL_CONFIG,
                AUDIO_FORMAT
            )

            audioTrack = buildOptimizedAudioTrack(sampleRate, channelCount, minBufferSize)

            // Initialize AudioPulse with correct sample rate
            audioPulse.configure(sampleRate, channelCount)

            // Initialize AudioDSP for effects processing
            audioDSP.configure(sampleRate, channelCount)

            // Initialize pitch shifter
            pitchShifter.configure(sampleRate, channelCount)

            isPrepared.set(true)
            setState(State.READY)
            Log.d(TAG, "Prepared successfully")
            return true

        } catch (e: Exception) {
            Log.e(TAG, "Prepare failed: ${e.message}", e)
            onError?.invoke(e.message ?: "Unknown error")
            setState(State.ERROR)
            return false
        }
    }

    /**
     * Start playback
     */
    fun play() {
        if (!isPrepared.get()) {
            Log.w(TAG, "Cannot play - not prepared")
            return
        }

        if (isPlaying.get()) {
            Log.d(TAG, "Already playing")
            return
        }

        // Request audio focus before starting
        if (!requestAudioFocus()) {
            Log.w(TAG, "Could not obtain audio focus")
            // Still allow playback, but it may be interrupted
        }

        // Acquire WakeLock to prevent CPU sleep during background playback
        acquireWakeLock()

        Log.d(TAG, "Starting playback")
        isPlaying.set(true)

        mediaCodec?.start()
        audioTrack?.play()

        // Start decode/playback thread
        playbackThread = Thread { playbackLoop() }.apply {
            name = "VibeAudio-Playback"
            start()
        }

        setState(State.PLAYING)
    }

    /**
     * Pause playback
     */
    fun pause() {
        if (!isPlaying.get()) return

        Log.d(TAG, "Pausing")
        isPlaying.set(false)
        audioTrack?.pause()

        // Release WakeLock when paused (user explicitly paused)
        releaseWakeLock()

        setState(State.PAUSED)
    }

    /**
     * Resume playback
     */
    fun resume() {
        if (isPlaying.get()) return
        if (!isPrepared.get()) return

        // Request audio focus before resuming
        if (!requestAudioFocus()) {
            Log.w(TAG, "Could not obtain audio focus for resume")
        }

        // Re-acquire WakeLock for background playback
        acquireWakeLock()

        Log.d(TAG, "Resuming")
        isPlaying.set(true)
        audioTrack?.play()

        // Restart playback thread if needed
        if (playbackThread?.isAlive != true) {
            playbackThread = Thread { playbackLoop() }.apply {
                name = "VibeAudio-Playback"
                start()
            }
        }

        setState(State.PLAYING)
    }

    /**
     * Stop playback
     */
    fun stop() {
        Log.d(TAG, "Stopping")
        isPlaying.set(false)

        playbackThread?.join(1000)
        playbackThread = null

        audioTrack?.stop()
        mediaCodec?.stop()

        // Abandon audio focus when stopping
        abandonAudioFocus()

        // Release WakeLock when stopped
        releaseWakeLock()

        positionUs.set(0)
        setState(State.STOPPED)
    }

    /**
     * Seek to position in milliseconds
     */
    fun seekTo(positionMs: Long) {
        Log.d(TAG, "Seeking to ${positionMs}ms")

        val wasPlaying = isPlaying.get()
        if (wasPlaying) {
            isPlaying.set(false)
            playbackThread?.join(500)
        }

        mediaExtractor?.seekTo(positionMs * 1000, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
        mediaCodec?.flush()
        pitchShifter.reset()  // Reset pitch shifter state on seek
        positionUs.set(positionMs * 1000)

        if (wasPlaying) {
            isPlaying.set(true)
            playbackThread = Thread { playbackLoop() }.apply {
                name = "VibeAudio-Playback"
                start()
            }
        }

        onPositionChanged?.invoke(positionMs)
    }

    /**
     * Get current position in milliseconds
     */
    fun getPosition(): Long = positionUs.get() / 1000

    /**
     * Get duration in milliseconds
     */
    fun getDuration(): Long = durationMs

    /**
     * Check if currently playing
     */
    fun isPlaying(): Boolean = isPlaying.get()

    /**
     * Get the audio session ID for effects
     */
    fun getAudioSessionId(): Int = audioTrack?.audioSessionId ?: 0

    //region Playback Controls

    /**
     * Set playback speed (0.5 to 2.0)
     * Note: Speed change requires AudioTrack recreation on older APIs
     */
    fun setSpeed(speed: Float) {
        playbackSpeed = speed.coerceIn(0.5f, 2.0f)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            audioTrack?.playbackParams = audioTrack?.playbackParams?.setSpeed(playbackSpeed) ?: return
        }
    }

    fun getSpeed(): Float = playbackSpeed

    /**
     * Set volume (0.0 to 1.0)
     */
    fun setVolume(vol: Float) {
        volume = vol.coerceIn(0.0f, 1.0f)
        if (!isCrossfading.get()) {
            audioTrack?.setVolume(volume)
        }
    }

    fun getVolume(): Float = volume

    /**
     * Set pitch in semitones (-12 to +12).
     * 0 = normal pitch
     * +12 = one octave higher
     * -12 = one octave lower
     *
     * Unlike speed, pitch does NOT affect playback tempo.
     */
    fun setPitch(semitones: Float) {
        val clampedSemitones = semitones.coerceIn(-12f, 12f)
        pitchShifter.setPitchSemitones(clampedSemitones)
        pitchShifter.setEnabled(clampedSemitones != 0f)
        Log.d(TAG, "Pitch set to $clampedSemitones semitones")
    }

    fun getPitch(): Float = pitchShifter.getPitchSemitones()

    fun isPitchEnabled(): Boolean = pitchShifter.isEnabled()

    //endregion

    //region Native DSP Effects

    /**
     * Enable or disable native DSP processing (EQ + Reverb)
     */
    fun setDSPEnabled(enabled: Boolean) {
        audioDSP.setEnabled(enabled)
    }

    fun isDSPEnabled(): Boolean = audioDSP.isEnabled()

    //endregion

    //region AudioPulse (FFT Analysis) Control

    /**
     * Enable or disable AudioPulse FFT analysis.
     * Disabling saves significant battery when visualizer is not visible.
     */
    fun setAudioPulseEnabled(enabled: Boolean) {
        audioPulse.setEnabled(enabled)
        Log.d(TAG, "AudioPulse ${if (enabled) "enabled" else "disabled"}")
    }

    fun isAudioPulseEnabled(): Boolean = audioPulse.isEnabled()

//endregion

    //region Native EQ
    /**
     * Enable or disable native EQ
     */
    fun setNativeEQEnabled(enabled: Boolean) {
        audioDSP.setEQEnabled(enabled)
        if (enabled) audioDSP.setEnabled(true)
    }

    fun isNativeEQEnabled(): Boolean = audioDSP.isEQEnabled()

    /**
     * Set EQ band gain (-12 to +12 dB)
     * Bands: 0=60Hz, 1=230Hz, 2=910Hz, 3=3.6kHz, 4=14kHz
     */
    fun setNativeEQBandGain(band: Int, gainDb: Float) {
        audioDSP.setEQBandGain(band, gainDb)
    }

    fun getNativeEQBandGain(band: Int): Float = audioDSP.getEQBandGain(band)

    fun getNativeEQBandFrequency(band: Int): Float = audioDSP.getEQBandFrequency(band)

    fun getNativeEQBandCount(): Int = audioDSP.getEQBandCount()

    /**
     * Enable or disable native reverb
     */
    fun setNativeReverbEnabled(enabled: Boolean) {
        audioDSP.setReverbEnabled(enabled)
        if (enabled) audioDSP.setEnabled(true)
    }

    fun isNativeReverbEnabled(): Boolean = audioDSP.isReverbEnabled()

    /**
     * Set reverb wet/dry mix (0-1)
     */
    fun setNativeReverbMix(mix: Float) {
        audioDSP.setReverbMix(mix)
    }

    fun getNativeReverbMix(): Float = audioDSP.getReverbMix()

    /**
     * Set reverb decay/room size (0-1)
     */
    fun setNativeReverbDecay(decay: Float) {
        audioDSP.setReverbDecay(decay)
    }

    fun getNativeReverbDecay(): Float = audioDSP.getReverbDecay()

    /**
     * Reset DSP state (call on track change)
     */
    fun resetDSP() {
        audioDSP.reset()
        pitchShifter.reset()
    }

    //endregion

    //region Crossfade

    /**
     * Enable or disable crossfade
     */
    fun setCrossfadeEnabled(enabled: Boolean) {
        crossfadeEnabled = enabled
    }

    fun isCrossfadeEnabled(): Boolean = crossfadeEnabled

    /**
     * Set crossfade duration in milliseconds
     */
    fun setCrossfadeDuration(durationMs: Int) {
        crossfadeDurationMs = durationMs.coerceIn(1000, 12000)
    }

    fun getCrossfadeDuration(): Int = crossfadeDurationMs

    /**
     * Start crossfade to the next prepared track.
     * Call this when approaching the end of current track.
     * Returns true if crossfade started successfully.
     */
    fun startCrossfade(): Boolean {
        if (!crossfadeEnabled || !nextPrepared.get() || isCrossfading.get()) {
            Log.d(TAG, "Cannot start crossfade: enabled=$crossfadeEnabled, nextPrepared=${nextPrepared.get()}, isCrossfading=${isCrossfading.get()}")
            return false
        }

        Log.d(TAG, "Starting crossfade to next track")
        isCrossfading.set(true)
        crossfadeVolume = volume
        nextTrackVolume = 0.0f

        // Create AudioTrack for next track if needed
        if (nextAudioTrack == null) {
            nextAudioTrack = createAudioTrackForCrossfade()
        }
        nextAudioTrack?.setVolume(0.0f)  // Start silent

        // Start the next track's decoder and audio
        nextMediaCodec?.start()
        nextAudioTrack?.play()

        // Start playback thread for next track (decodes and plays audio)
        crossfadePlaybackThread = Thread {
            crossfadePlaybackLoop()
        }.apply {
            name = "VibeAudio-CrossfadePlayback"
            start()
        }

        // Start volume fade thread
        Thread {
            performCrossfade()
        }.apply {
            name = "VibeAudio-CrossfadeFade"
            start()
        }

        return true
    }

    /**
     * Playback loop for the next track during crossfade
     */
    private fun crossfadePlaybackLoop() {
        Log.d(TAG, "Crossfade playback loop started")

        val codec = nextMediaCodec ?: return
        val extractor = nextMediaExtractor ?: return
        val track = nextAudioTrack ?: return

        val bufferInfo = MediaCodec.BufferInfo()
        var inputDone = false

        while (isCrossfading.get()) {
            // Feed input to decoder
            if (!inputDone) {
                val inputIndex = codec.dequeueInputBuffer(10000)
                if (inputIndex >= 0) {
                    val inputBuffer = codec.getInputBuffer(inputIndex)
                    if (inputBuffer != null) {
                        val sampleSize = extractor.readSampleData(inputBuffer, 0)
                        if (sampleSize < 0) {
                            codec.queueInputBuffer(inputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            val presentationTimeUs = extractor.sampleTime
                            codec.queueInputBuffer(inputIndex, 0, sampleSize, presentationTimeUs, 0)
                            extractor.advance()
                        }
                    }
                }
            }

            // Get decoded output and write to AudioTrack
            val outputIndex = codec.dequeueOutputBuffer(bufferInfo, 10000)
            if (outputIndex >= 0) {
                val outputBuffer = codec.getOutputBuffer(outputIndex)
                if (outputBuffer != null && bufferInfo.size > 0) {
                    val audioData = ByteArray(bufferInfo.size)
                    outputBuffer.get(audioData)
                    outputBuffer.rewind()
                    track.write(audioData, 0, audioData.size)
                }
                codec.releaseOutputBuffer(outputIndex, false)
            }
        }

        Log.d(TAG, "Crossfade playback loop ended")
    }

    private fun createAudioTrackForCrossfade(): AudioTrack {
        val minBufferSize = AudioTrack.getMinBufferSize(
            nextSampleRate,
            if (nextChannelCount == 1) AudioFormat.CHANNEL_OUT_MONO else CHANNEL_CONFIG,
            AUDIO_FORMAT
        )
        return buildOptimizedAudioTrack(nextSampleRate, nextChannelCount, minBufferSize)
    }

    private fun performCrossfade() {
        val steps = 50
        val stepDurationMs = crossfadeDurationMs / steps
        val volumeStep = volume / steps

        for (i in 0 until steps) {
            if (!isCrossfading.get()) break

            crossfadeVolume = (volume - (volumeStep * i)).coerceIn(0.0f, 1.0f)
            nextTrackVolume = (volumeStep * i).coerceIn(0.0f, 1.0f)

            audioTrack?.setVolume(crossfadeVolume)
            nextAudioTrack?.setVolume(nextTrackVolume)

            Thread.sleep(stepDurationMs.toLong())
        }

        // Crossfade complete - transition to next track
        if (isCrossfading.get()) {
            mainHandler.post {
                completeCrossfadeTransition()
            }
        }
    }

    private fun completeCrossfadeTransition() {
        Log.d(TAG, "Completing crossfade transition")

        // Stop current track
        isPlaying.set(false)
        playbackThread?.join(500)

        // Release current resources
        audioTrack?.stop()
        audioTrack?.release()
        mediaCodec?.stop()
        mediaCodec?.release()
        mediaExtractor?.release()

        // Swap next to current
        audioTrack = nextAudioTrack
        mediaCodec = nextMediaCodec
        mediaExtractor = nextMediaExtractor
        sampleRate = nextSampleRate
        channelCount = nextChannelCount
        durationMs = nextDurationMs

        // Clear next references
        nextAudioTrack = null
        nextMediaCodec = null
        nextMediaExtractor = null
        nextPrepared.set(false)
        nextTrackPath = null

        // Reset state
        isCrossfading.set(false)
        audioTrack?.setVolume(volume)
        isPrepared.set(true)
        isPlaying.set(true)
        positionUs.set(0)

        // Update AudioPulse
        audioPulse.configure(sampleRate, channelCount)

        // Continue playback loop with new track
        playbackThread = Thread { playbackLoop() }.apply {
            name = "VibeAudio-Playback"
            start()
        }

        setState(State.PLAYING)
        onDurationChanged?.invoke(durationMs)

        Log.d(TAG, "Crossfade transition complete")
    }

    //endregion

    //region Gapless Playback

    /**
     * Enable or disable gapless playback
     */
    fun setGaplessEnabled(enabled: Boolean) {
        gaplessEnabled = enabled
        if (!enabled) {
            clearNextTrack()
        }
    }

    /**
     * Prepare the next track for gapless playback.
     * Call this while the current track is playing.
     */
    fun prepareNextTrack(path: String): Boolean {
        if (!gaplessEnabled) return false

        Log.d(TAG, "Preparing next track for gapless: $path")

        try {
            // Clear any existing next track
            clearNextTrack()

            nextTrackPath = path

            // Create MediaExtractor for next track
            nextMediaExtractor = MediaExtractor().apply {
                if (path.startsWith("content://") || path.startsWith("file://")) {
                    setDataSource(context, Uri.parse(path), null)
                } else {
                    setDataSource(path)
                }
            }

            // Find audio track
            val audioTrackIndex = findAudioTrackIn(nextMediaExtractor!!)
            if (audioTrackIndex < 0) {
                Log.e(TAG, "No audio track found in next track")
                clearNextTrack()
                return false
            }

            nextMediaExtractor?.selectTrack(audioTrackIndex)
            val format = nextMediaExtractor?.getTrackFormat(audioTrackIndex)

            // Get audio properties
            nextSampleRate = format?.getInteger(MediaFormat.KEY_SAMPLE_RATE) ?: SAMPLE_RATE
            nextChannelCount = format?.getInteger(MediaFormat.KEY_CHANNEL_COUNT) ?: 2
            nextDurationMs = (format?.getLong(MediaFormat.KEY_DURATION) ?: 0) / 1000

            // Create MediaCodec for next track
            val mime = format?.getString(MediaFormat.KEY_MIME) ?: "audio/mpeg"
            nextMediaCodec = MediaCodec.createDecoderByType(mime).apply {
                configure(format, null, null, 0)
            }

            nextPrepared.set(true)
            Log.d(TAG, "Next track prepared: ${nextDurationMs}ms, ${nextSampleRate}Hz")
            return true

        } catch (e: Exception) {
            Log.e(TAG, "Failed to prepare next track: ${e.message}", e)
            clearNextTrack()
            return false
        }
    }

    /**
     * Check if next track is ready for gapless transition
     */
    fun isNextTrackReady(): Boolean = nextPrepared.get()

    /**
     * Get the path of the prepared next track
     */
    fun getNextTrackPath(): String? = nextTrackPath

    /**
     * Clear the prepared next track
     */
    fun clearNextTrack() {
        Log.d(TAG, "Clearing next track")
        nextPrepared.set(false)
        nextTrackPath = null

        try {
            nextMediaCodec?.release()
            nextMediaCodec = null
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing next MediaCodec: ${e.message}")
        }

        try {
            nextMediaExtractor?.release()
            nextMediaExtractor = null
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing next MediaExtractor: ${e.message}")
        }
    }

    /**
     * Transition to the next track (for gapless playback).
     * Returns true if transition succeeded.
     */
    fun transitionToNextTrack(): Boolean {
        if (!nextPrepared.get()) {
            Log.d(TAG, "No next track prepared for transition")
            return false
        }

        Log.d(TAG, "Transitioning to next track (gapless)")

        try {
            // Stop current playback thread but keep playing state
            val wasPlaying = isPlaying.get()
            isPlaying.set(false)
            playbackThread?.join(500)

            // Release current track resources
            mediaCodec?.stop()
            mediaCodec?.release()
            mediaExtractor?.release()

            // Move next track to current
            mediaExtractor = nextMediaExtractor
            mediaCodec = nextMediaCodec
            sampleRate = nextSampleRate
            channelCount = nextChannelCount
            durationMs = nextDurationMs

            // Clear next references (now current)
            nextMediaExtractor = null
            nextMediaCodec = null
            nextPrepared.set(false)
            nextTrackPath = null

            // Reconfigure AudioTrack if sample rate/channels changed
            val currentSampleRate = audioTrack?.sampleRate ?: 0
            if (sampleRate != currentSampleRate ||
                (channelCount == 1 && audioTrack?.channelCount != 1) ||
                (channelCount == 2 && audioTrack?.channelCount != 2)) {
                Log.d(TAG, "Recreating AudioTrack for new format")
                audioTrack?.stop()
                audioTrack?.release()
                audioTrack = createAudioTrack()
            }

            // Update AudioPulse
            audioPulse.configure(sampleRate, channelCount)

            // Mark as prepared (important for resume to work)
            isPrepared.set(true)

            positionUs.set(0)
            onDurationChanged?.invoke(durationMs)

            // Start playing the new track
            if (wasPlaying) {
                mediaCodec?.start()
                audioTrack?.play()
                isPlaying.set(true)
                playbackThread = Thread { playbackLoop() }.apply {
                    name = "VibeAudio-Playback"
                    start()
                }
                setState(State.PLAYING)
            } else {
                setState(State.READY)
            }

            Log.d(TAG, "Gapless transition complete")
            return true

        } catch (e: Exception) {
            Log.e(TAG, "Gapless transition failed: ${e.message}", e)
            return false
        }
    }

    private fun createAudioTrack(): AudioTrack {
        val minBufferSize = AudioTrack.getMinBufferSize(
            sampleRate,
            if (channelCount == 1) AudioFormat.CHANNEL_OUT_MONO else CHANNEL_CONFIG,
            AUDIO_FORMAT
        )
        return buildOptimizedAudioTrack(sampleRate, channelCount, minBufferSize)
    }

    /**
     * Build an optimized AudioTrack with device-specific settings.
     * Uses low-latency mode on supported devices (API 26+).
     */
    private fun buildOptimizedAudioTrack(rate: Int, channels: Int, minBufferSize: Int): AudioTrack {
        val channelMask = if (channels == 1) AudioFormat.CHANNEL_OUT_MONO else CHANNEL_CONFIG

        // Calculate optimal buffer size
        // For low-latency: use native buffer size aligned to device capabilities
        // For normal: use larger buffer for stability
        val bufferSize = if (lowLatencySupported && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Use native buffer frames * bytes per frame * some multiplier
            // bytes per frame = channels * 2 (16-bit = 2 bytes)
            val bytesPerFrame = channels * 2
            val optimalBufferSize = nativeBufferSize * bytesPerFrame * 4 // 4x native buffer
            maxOf(minBufferSize, optimalBufferSize)
        } else {
            minBufferSize * BUFFER_SIZE_FACTOR
        }

        val builder = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AUDIO_FORMAT)
                    .setSampleRate(rate)
                    .setChannelMask(channelMask)
                    .build()
            )
            .setBufferSizeInBytes(bufferSize)
            .setTransferMode(AudioTrack.MODE_STREAM)

        // Enable low-latency performance mode on API 26+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && lowLatencySupported) {
            builder.setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
            Log.d(TAG, "AudioTrack created with LOW_LATENCY mode, buffer=$bufferSize bytes")
        } else {
            Log.d(TAG, "AudioTrack created with standard mode, buffer=$bufferSize bytes")
        }

        return builder.build()
    }

    private fun findAudioTrackIn(extractor: MediaExtractor): Int {
        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME)
            if (mime?.startsWith("audio/") == true) {
                return i
            }
        }
        return -1
    }

    /**
     * Release all resources
     */
    fun release() {
        Log.d(TAG, "Releasing")

        isPlaying.set(false)
        isPrepared.set(false)

        // Abandon audio focus when releasing
        abandonAudioFocus()

        // Release WakeLock when releasing
        releaseWakeLock()

        // Clear any prepared next track
        clearNextTrack()

        playbackThread?.join(1000)
        playbackThread = null

        try {
            audioTrack?.stop()
            audioTrack?.release()
            audioTrack = null
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing AudioTrack: ${e.message}")
        }

        try {
            mediaCodec?.stop()
            mediaCodec?.release()
            mediaCodec = null
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing MediaCodec: ${e.message}")
        }

        try {
            mediaExtractor?.release()
            mediaExtractor = null
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing MediaExtractor: ${e.message}")
        }

        setState(State.IDLE)
    }

    //endregion

    //region Playback Loop

    private fun playbackLoop() {

        val codec = mediaCodec ?: run {
            Log.e(TAG, "Playback loop: MediaCodec is null!")
            return
        }
        val extractor = mediaExtractor ?: run {
            Log.e(TAG, "Playback loop: MediaExtractor is null!")
            return
        }
        val track = audioTrack ?: run {
            Log.e(TAG, "Playback loop: AudioTrack is null!")
            return
        }

        val bufferInfo = MediaCodec.BufferInfo()
        var inputDone = false
        var outputDone = false

        while (isPlaying.get() && !outputDone) {
            // Feed input to decoder
            if (!inputDone) {
                val inputIndex = codec.dequeueInputBuffer(10000)
                if (inputIndex >= 0) {
                    val inputBuffer = codec.getInputBuffer(inputIndex)
                    if (inputBuffer != null) {
                        val sampleSize = extractor.readSampleData(inputBuffer, 0)
                        if (sampleSize < 0) {
                            codec.queueInputBuffer(inputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                            Log.d(TAG, "Input EOS")
                        } else {
                            val presentationTimeUs = extractor.sampleTime
                            codec.queueInputBuffer(inputIndex, 0, sampleSize, presentationTimeUs, 0)
                            extractor.advance()
                        }
                    }
                }
            }

            // Get decoded output
            val outputIndex = codec.dequeueOutputBuffer(bufferInfo, 10000)
            when {
                outputIndex >= 0 -> {
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        outputDone = true
                    }

                    val outputBuffer = codec.getOutputBuffer(outputIndex)
                    if (outputBuffer != null && bufferInfo.size > 0) {
                        // THIS IS WHERE THE MAGIC HAPPENS!
                        // We have direct access to PCM data
                        processPcmData(outputBuffer, bufferInfo.size)

                        // Write to AudioTrack for playback
                        val audioData = ByteArray(bufferInfo.size)
                        outputBuffer.get(audioData)
                        outputBuffer.rewind()

                        // Apply DSP effects (EQ, reverb) if enabled
                        val processedData = applyDSP(audioData)

                        // Apply pitch shifting if enabled
                        val finalData = applyPitchShift(processedData)

                        if (finalData.isNotEmpty()) {
                            track.write(finalData, 0, finalData.size)
                        }

                        // Update position
                        positionUs.set(bufferInfo.presentationTimeUs)
                    }

                    codec.releaseOutputBuffer(outputIndex, false)

                    // Send position update (throttled)
                    if (System.currentTimeMillis() % 250 < 20) {
                        mainHandler.post {
                            onPositionChanged?.invoke(positionUs.get() / 1000)
                        }
                    }
                }
                outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    // Format changed, no action needed
                }
            }
        }

        if (outputDone && isPlaying.get()) {
            mainHandler.post {
                isPlaying.set(false)
                setState(State.STOPPED)
                onCompletion?.invoke()
            }
        }
    }

    /**
     * Apply DSP effects to audio data.
     * Converts byte array to shorts, processes, converts back.
     */
    private fun applyDSP(audioData: ByteArray): ByteArray {
        if (!audioDSP.isEnabled()) return audioData

        // Convert bytes to shorts (little-endian 16-bit PCM)
        val samples = ShortArray(audioData.size / 2)
        for (i in samples.indices) {
            val lo = audioData[i * 2].toInt() and 0xFF
            val hi = audioData[i * 2 + 1].toInt()
            samples[i] = ((hi shl 8) or lo).toShort()
        }

        // Process through DSP
        audioDSP.process(samples)

        // Convert back to bytes
        val result = ByteArray(audioData.size)
        for (i in samples.indices) {
            val s = samples[i].toInt()
            result[i * 2] = (s and 0xFF).toByte()
            result[i * 2 + 1] = ((s shr 8) and 0xFF).toByte()
        }

        return result
    }

    /**
     * Apply pitch shifting to audio data.
     * NOTE: This may return a different number of samples than input!
     * - pitch > 1.0: fewer output samples
     * - pitch < 1.0: more output samples
     */
    private fun applyPitchShift(audioData: ByteArray): ByteArray {
        if (!pitchShifter.isEnabled()) return audioData

        // Convert bytes to shorts (little-endian 16-bit PCM)
        val samples = ShortArray(audioData.size / 2)
        for (i in samples.indices) {
            val lo = audioData[i * 2].toInt() and 0xFF
            val hi = audioData[i * 2 + 1].toInt()
            samples[i] = ((hi shl 8) or lo).toShort()
        }

        // Process through pitch shifter (may return different size!)
        val processedSamples = pitchShifter.process(samples)

        if (processedSamples.isEmpty()) {
            return ByteArray(0)
        }

        // Convert back to bytes
        val result = ByteArray(processedSamples.size * 2)
        for (i in processedSamples.indices) {
            val s = processedSamples[i].toInt()
            result[i * 2] = (s and 0xFF).toByte()
            result[i * 2 + 1] = ((s shr 8) and 0xFF).toByte()
        }

        return result
    }

    /**
     * Process PCM data for visualization - THE KEY FUNCTION!
     * This is where we feed audio data to AudioPulse
     */
    private fun processPcmData(buffer: ByteBuffer, size: Int) {
        buffer.order(ByteOrder.LITTLE_ENDIAN)

        // Convert to shorts and feed to AudioPulse
        val samples = ShortArray(size / 2)
        buffer.asShortBuffer().get(samples)
        buffer.rewind()

        // Feed to AudioPulse for FFT analysis
        audioPulse.processSamples(samples)

        // Store in our PCM buffer for any other use
        synchronized(pcmLock) {
            for (sample in samples) {
                pcmBuffer[pcmBufferIndex] = sample
                pcmBufferIndex = (pcmBufferIndex + 1) % pcmBuffer.size
            }
        }

        // Send pulse data to Flutter
        sendPulseData()
    }

    //endregion

    //region Flutter Integration

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun setPulseEventSink(sink: EventChannel.EventSink?) {
        pulseEventSink = sink
        audioPulse.setEventSink(sink)
    }

    private fun sendPulseData() {
        val sink = pulseEventSink ?: return

        val data = audioPulse.getPulseData()
        mainHandler.post {
            try {
                sink.success(data)
            } catch (e: Exception) {
                Log.e(TAG, "Error sending pulse data: ${e.message}")
            }
        }
    }

    private fun setState(newState: State) {
        if (state != newState) {
            state = newState
            Log.d(TAG, "State: $newState")
            mainHandler.post {
                onStateChanged?.invoke(newState)
                sendStateToFlutter()
            }
        }
    }

    private fun sendStateToFlutter() {
        eventSink?.success(mapOf(
            "state" to state.name,
            "position" to getPosition(),
            "duration" to durationMs,
            "isPlaying" to isPlaying.get()
        ))
    }

    //endregion

    //region Helper Functions

    private fun findAudioTrack(): Int {
        val extractor = mediaExtractor ?: return -1
        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME)
            if (mime?.startsWith("audio/") == true) {
                return i
            }
        }
        return -1
    }

    //endregion

    //region Audio Focus Management

    /**
     * Request audio focus before starting playback
     */
    private fun requestAudioFocus(): Boolean {
        if (hasAudioFocus) return true

        Log.d(TAG, "Requesting audio focus")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                .setAcceptsDelayedFocusGain(true)
                .setOnAudioFocusChangeListener(audioFocusChangeListener, mainHandler)
                .build()

            audioFocusRequest = focusRequest
            val result = audioManager.requestAudioFocus(focusRequest)
            hasAudioFocus = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } else {
            @Suppress("DEPRECATION")
            val result = audioManager.requestAudioFocus(
                audioFocusChangeListener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN
            )
            hasAudioFocus = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }

        Log.d(TAG, "Audio focus request result: $hasAudioFocus")
        return hasAudioFocus
    }

    /**
     * Abandon audio focus when stopping or releasing
     */
    private fun abandonAudioFocus() {
        if (!hasAudioFocus && audioFocusRequest == null) return

        Log.d(TAG, "Abandoning audio focus")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
            audioFocusRequest = null
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(audioFocusChangeListener)
        }

        hasAudioFocus = false
        shouldResumeOnFocusGain = false
    }

    //endregion

    //region WakeLock Management

    /**
     * Acquire WakeLock to prevent CPU sleep during background playback.
     * This ensures track completion events are delivered and next track starts.
     */
    private fun acquireWakeLock() {
        if (wakeLock == null) {
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "VibePlay::AudioPlayback"
            )
        }

        if (wakeLock?.isHeld != true) {
            // Acquire with timeout of 2 hours max to prevent battery drain
            // if something goes wrong
            wakeLock?.acquire(2 * 60 * 60 * 1000L)
            Log.d(TAG, "WakeLock acquired for background playback")
        }
    }

    /**
     * Release WakeLock when playback stops or pauses
     */
    private fun releaseWakeLock() {
        if (wakeLock?.isHeld == true) {
            wakeLock?.release()
            Log.d(TAG, "WakeLock released")
        }
    }

    //endregion
}
