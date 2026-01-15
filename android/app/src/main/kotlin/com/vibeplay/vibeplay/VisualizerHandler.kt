package com.vibeplay.vibeplay

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.media.audiofx.Visualizer
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Handles audio visualization by capturing FFT and waveform data
 * from the audio output using Android's Visualizer class.
 */
class VisualizerHandler(private val activity: Activity) :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    companion object {
        private const val TAG = "VisualizerHandler"
        private const val CAPTURE_SIZE = 256 // Must be power of 2, between 128-1024
    }

    private var visualizer: Visualizer? = null
    private var audioSessionId: Int = 0
    private var isCapturing = false

    // Event channel for streaming data to Flutter
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // Capture rate control
    private var captureRate = 60 // fps
    private var lastCaptureTime = 0L

    // Cached data arrays
    private var fftData: ByteArray? = null
    private var waveformData: ByteArray? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setAudioSessionId" -> {
                val sessionId = call.argument<Int>("sessionId") ?: 0
                setAudioSessionId(sessionId)
                result.success(true)
            }
            "startCapture" -> {
                val rate = call.argument<Int>("captureRate") ?: 60
                val success = startCapture(rate)
                result.success(success)
            }
            "stopCapture" -> {
                stopCapture()
                result.success(true)
            }
            "getFftData" -> {
                result.success(getFftData())
            }
            "getWaveformData" -> {
                result.success(getWaveformData())
            }
            "isAvailable" -> {
                result.success(isVisualizerAvailable())
            }
            "release" -> {
                release()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    // EventChannel.StreamHandler implementation
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        Log.d(TAG, "Event channel listener attached")
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        Log.d(TAG, "Event channel listener detached")
    }

    private fun isVisualizerAvailable(): Boolean {
        // Check for RECORD_AUDIO permission (required for Visualizer)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.RECORD_AUDIO
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun setAudioSessionId(sessionId: Int) {
        if (sessionId == audioSessionId && visualizer != null) {
            return
        }

        // Remember if we were capturing before reinitializing
        val wasCapturing = isCapturing

        release()
        audioSessionId = sessionId

        if (sessionId == 0) {
            Log.w(TAG, "Audio session ID is 0, using global output")
        } else {
            Log.d(TAG, "Setting audio session ID to $sessionId")
        }

        initializeVisualizer()

        // Restart capture if we were capturing before
        if (wasCapturing && visualizer != null) {
            Log.d(TAG, "Restarting capture after session ID change")
            startCapture(captureRate)
        }
    }

    private fun initializeVisualizer() {
        if (!isVisualizerAvailable()) {
            Log.w(TAG, "Visualizer not available - missing RECORD_AUDIO permission")
            return
        }

        try {
            // Use 0 for global audio output, or specific session ID
            visualizer = Visualizer(audioSessionId).apply {
                // Set capture size (affects frequency resolution)
                captureSize = CAPTURE_SIZE

                // Initialize data arrays
                fftData = ByteArray(captureSize)
                waveformData = ByteArray(captureSize)

                // Set up data capture listener
                setDataCaptureListener(
                    object : Visualizer.OnDataCaptureListener {
                        override fun onWaveFormDataCapture(
                            visualizer: Visualizer?,
                            waveform: ByteArray?,
                            samplingRate: Int
                        ) {
                            if (waveform != null && isCapturing) {
                                waveformData = waveform.clone()
                                sendDataToFlutter()
                            }
                        }

                        override fun onFftDataCapture(
                            visualizer: Visualizer?,
                            fft: ByteArray?,
                            samplingRate: Int
                        ) {
                            if (fft != null && isCapturing) {
                                fftData = fft.clone()
                            }
                        }
                    },
                    Visualizer.getMaxCaptureRate() / 2, // Capture rate in millihertz
                    true,  // Enable waveform capture
                    true   // Enable FFT capture
                )

                enabled = false // Start disabled
            }

            Log.d(TAG, "Visualizer initialized for session $audioSessionId, capture size: $CAPTURE_SIZE")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Visualizer: ${e.message}")
            visualizer = null
        }
    }

    private fun startCapture(rate: Int): Boolean {
        captureRate = rate.coerceIn(1, 120)

        val vis = visualizer
        if (vis == null) {
            // Initialize visualizer - use 0 for global audio output if no session ID set
            initializeVisualizer()
            if (visualizer == null) {
                Log.e(TAG, "Cannot start capture - visualizer not initialized")
                return false
            }
        }

        return try {
            visualizer?.enabled = true
            isCapturing = true
            Log.d(TAG, "Visualizer capture started at $captureRate fps")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start capture: ${e.message}")
            false
        }
    }

    private fun stopCapture() {
        isCapturing = false
        try {
            visualizer?.enabled = false
            Log.d(TAG, "Visualizer capture stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop capture: ${e.message}")
        }
    }

    private fun getFftData(): List<Int>? {
        val fft = fftData ?: return null

        // Convert FFT data to magnitudes
        // FFT data format: [DC, bin1_real, bin1_imag, bin2_real, bin2_imag, ...]
        val magnitudes = mutableListOf<Int>()

        // Skip DC component (index 0)
        for (i in 2 until fft.size step 2) {
            val real = fft[i].toInt()
            val imag = fft[i + 1].toInt()
            // Calculate magnitude: sqrt(real^2 + imag^2)
            val magnitude = kotlin.math.sqrt((real * real + imag * imag).toDouble()).toInt()
            magnitudes.add(magnitude.coerceIn(0, 255))
        }

        return magnitudes
    }

    private fun getWaveformData(): List<Int>? {
        val waveform = waveformData ?: return null
        return waveform.map { (it.toInt() and 0xFF) }
    }

    private var debugCounter = 0

    private fun sendDataToFlutter() {
        val currentTime = System.currentTimeMillis()
        val minInterval = 1000 / captureRate

        if (currentTime - lastCaptureTime < minInterval) {
            return
        }
        lastCaptureTime = currentTime

        val sink = eventSink ?: return

        val fftResult = getFftData()
        val waveformResult = getWaveformData()

        // Debug: log raw data every 2 seconds
        debugCounter++
        if (debugCounter % 120 == 0) {
            val fftSum = fftResult?.sum() ?: 0
            val waveSum = waveformResult?.sum() ?: 0
            val fftMax = fftResult?.maxOrNull() ?: 0
            Log.d(TAG, "RAW DATA - FFT sum=$fftSum max=$fftMax, Waveform sum=$waveSum, session=$audioSessionId")
        }

        mainHandler.post {
            try {
                val data = mapOf(
                    "fft" to fftResult,
                    "waveform" to waveformResult,
                    "timestamp" to currentTime
                )
                sink.success(data)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send data to Flutter: ${e.message}")
            }
        }
    }

    fun release() {
        stopCapture()
        try {
            visualizer?.release()
            visualizer = null
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release visualizer: ${e.message}")
        }
        fftData = null
        waveformData = null
        audioSessionId = 0
        Log.d(TAG, "Visualizer released")
    }
}
