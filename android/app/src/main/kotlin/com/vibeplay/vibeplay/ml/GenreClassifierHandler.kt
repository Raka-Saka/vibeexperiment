package com.vibeplay.vibeplay.ml

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

/**
 * GenreClassifierHandler - Platform channel handler for genre classification
 *
 * Provides Flutter interface to GenreClassifier for on-device ML genre detection.
 */
class GenreClassifierHandler(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "GenreClassifierHandler"
    }

    private val classifier = GenreClassifier(context)
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var isInitialized = false

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                scope.launch {
                    try {
                        val success = classifier.init()
                        isInitialized = true
                        withContext(Dispatchers.Main) {
                            result.success(mapOf(
                                "success" to success,
                                "hasModel" to success,
                                "genres" to GenreClassifier.GENRES
                            ))
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Initialize failed: ${e.message}")
                        withContext(Dispatchers.Main) {
                            result.error("INIT_ERROR", e.message, null)
                        }
                    }
                }
            }

            "classifyFile" -> {
                val filePath = call.argument<String>("path")
                if (filePath == null) {
                    result.error("INVALID_ARG", "File path is required", null)
                    return
                }

                scope.launch {
                    try {
                        Log.d(TAG, "Classifying: $filePath")
                        val classResult = classifier.classify(filePath)

                        withContext(Dispatchers.Main) {
                            if (classResult != null) {
                                result.success(mapOf(
                                    "genre" to classResult.genre,
                                    "confidence" to classResult.confidence,
                                    "probabilities" to classResult.probabilities,
                                    "isHeuristic" to classResult.isHeuristic
                                ))
                            } else {
                                result.success(null)
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Classification failed: ${e.message}")
                        withContext(Dispatchers.Main) {
                            result.error("CLASSIFY_ERROR", e.message, null)
                        }
                    }
                }
            }

            "classifyBatch" -> {
                val filePaths = call.argument<List<String>>("paths")
                if (filePaths == null || filePaths.isEmpty()) {
                    result.error("INVALID_ARG", "File paths list is required", null)
                    return
                }

                scope.launch {
                    try {
                        val results = mutableListOf<Map<String, Any?>>()

                        for ((index, path) in filePaths.withIndex()) {
                            Log.d(TAG, "Classifying batch ${index + 1}/${filePaths.size}: $path")
                            val classResult = classifier.classify(path)

                            results.add(if (classResult != null) {
                                mapOf(
                                    "path" to path,
                                    "genre" to classResult.genre,
                                    "confidence" to classResult.confidence,
                                    "probabilities" to classResult.probabilities,
                                    "isHeuristic" to classResult.isHeuristic
                                )
                            } else {
                                mapOf(
                                    "path" to path,
                                    "genre" to null,
                                    "error" to "Classification failed"
                                )
                            })
                        }

                        withContext(Dispatchers.Main) {
                            result.success(results)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Batch classification failed: ${e.message}")
                        withContext(Dispatchers.Main) {
                            result.error("BATCH_ERROR", e.message, null)
                        }
                    }
                }
            }

            "getGenres" -> {
                result.success(GenreClassifier.GENRES)
            }

            "isInitialized" -> {
                result.success(isInitialized)
            }

            else -> result.notImplemented()
        }
    }

    fun release() {
        scope.cancel()
        classifier.close()
        isInitialized = false
    }
}
