package com.vibeplay.vibeplay

import android.content.Context
import android.util.Log
import com.vibeplay.vibeplay.audio.LoudnessAnalyzer
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

/**
 * Method channel handler for audio analysis operations
 * Supports:
 * - LUFS loudness analysis (ITU-R BS.1770-4)
 * - Silence/fade detection for smart crossfade
 * - BPM detection (future)
 */
class AudioAnalysisHandler(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "AudioAnalysisHandler"
    }

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private val loudnessAnalyzer = LoudnessAnalyzer(context)

    // Track ongoing analyses to prevent duplicates
    private val ongoingAnalyses = mutableSetOf<String>()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "analyzeLoudness" -> analyzeLoudness(call, result)
            "analyzeBatch" -> analyzeBatch(call, result)
            "getBpm" -> getBpm(call, result)
            "findSilenceStart" -> findSilenceStart(call, result)
            "cancelAnalysis" -> cancelAnalysis(call, result)
            else -> result.notImplemented()
        }
    }

    /**
     * Analyze loudness of a single file
     * Returns: { loudness: double (LUFS), peak: double (0-1), range: double (LU) }
     */
    private fun analyzeLoudness(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path == null) {
            result.error("INVALID_ARGS", "Missing 'path' argument", null)
            return
        }

        // Check if already analyzing
        if (ongoingAnalyses.contains(path)) {
            result.error("ALREADY_ANALYZING", "Analysis already in progress for this file", null)
            return
        }

        ongoingAnalyses.add(path)

        scope.launch {
            try {
                val analysisResult = loudnessAnalyzer.analyze(path)

                if (analysisResult != null) {
                    result.success(mapOf(
                        "loudness" to analysisResult.integratedLoudness,
                        "peak" to analysisResult.truePeak,
                        "range" to analysisResult.loudnessRange,
                        "shortTermMax" to analysisResult.shortTermMax,
                        "durationMs" to analysisResult.durationMs
                    ))
                } else {
                    result.error("ANALYSIS_FAILED", "Failed to analyze file", null)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error analyzing loudness: ${e.message}", e)
                result.error("ANALYSIS_ERROR", e.message, null)
            } finally {
                ongoingAnalyses.remove(path)
            }
        }
    }

    /**
     * Analyze loudness of multiple files in batch
     * Returns results as they complete via a callback mechanism
     */
    private fun analyzeBatch(call: MethodCall, result: MethodChannel.Result) {
        val paths = call.argument<List<String>>("paths")
        if (paths == null || paths.isEmpty()) {
            result.error("INVALID_ARGS", "Missing or empty 'paths' argument", null)
            return
        }

        scope.launch {
            val results = mutableMapOf<String, Map<String, Any?>>()
            var completed = 0
            val total = paths.size

            for (path in paths) {
                try {
                    val analysisResult = loudnessAnalyzer.analyze(path)

                    if (analysisResult != null) {
                        results[path] = mapOf(
                            "loudness" to analysisResult.integratedLoudness,
                            "peak" to analysisResult.truePeak,
                            "range" to analysisResult.loudnessRange,
                            "durationMs" to analysisResult.durationMs
                        )
                    } else {
                        results[path] = mapOf(
                            "error" to "Analysis failed"
                        )
                    }
                } catch (e: Exception) {
                    results[path] = mapOf(
                        "error" to e.message
                    )
                }

                completed++
                Log.d(TAG, "Batch progress: $completed/$total")
            }

            result.success(mapOf(
                "results" to results,
                "completed" to completed,
                "total" to total
            ))
        }
    }

    /**
     * Get BPM from audio file metadata or analysis
     * TODO: Implement proper BPM detection using beat tracking
     */
    private fun getBpm(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path == null) {
            result.error("INVALID_ARGS", "Missing 'path' argument", null)
            return
        }

        // For now, return null - BPM detection requires more complex analysis
        // Could be implemented using autocorrelation or onset detection
        result.success(null)
    }

    /**
     * Find where silence/fade begins at the end of a track
     * Useful for smart crossfade timing
     * Returns: millisecond position where silence/fade starts, or null if not found
     */
    private fun findSilenceStart(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        val thresholdDb = call.argument<Double>("thresholdDb") ?: -40.0
        val analyzeLastMs = call.argument<Int>("analyzeLastMs") ?: 15000

        if (path == null) {
            result.error("INVALID_ARGS", "Missing 'path' argument", null)
            return
        }

        scope.launch {
            try {
                val silenceStartMs = loudnessAnalyzer.findSilenceStart(
                    filePath = path,
                    thresholdDb = thresholdDb,
                    analyzeLastMs = analyzeLastMs
                )
                result.success(silenceStartMs)
            } catch (e: Exception) {
                Log.e(TAG, "Error finding silence start: ${e.message}", e)
                result.error("ANALYSIS_ERROR", e.message, null)
            }
        }
    }

    /**
     * Cancel any ongoing analysis for a file
     */
    private fun cancelAnalysis(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path != null) {
            ongoingAnalyses.remove(path)
        }
        result.success(true)
    }

    /**
     * Release resources
     */
    fun release() {
        scope.cancel()
        ongoingAnalyses.clear()
    }
}
