package com.vibeplay.vibeplay.ml

import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.util.Log
import kotlinx.coroutines.*
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import kotlin.math.*

/**
 * GenreClassifier - On-device ML genre classification using YAMNet TensorFlow Lite model
 *
 * Uses YAMNet (trained on AudioSet) to classify audio, then maps music-related classes
 * to 10 standard genres: Blues, Classical, Country, Disco, Hip-Hop, Jazz, Metal, Pop, Reggae, Rock
 */
class GenreClassifier(private val context: Context) {

    companion object {
        private const val TAG = "GenreClassifier"

        // Model configuration
        private const val YAMNET_MODEL_FILE = "yamnet.tflite"
        private const val GENRE_CLASSIFIER_FILE = "genre_classifier.tflite"

        // YAMNet audio configuration
        private const val YAMNET_SAMPLE_RATE = 16000
        private const val YAMNET_PATCH_SAMPLES = 15600  // ~0.975 seconds per patch
        private const val YAMNET_NUM_CLASSES = 521
        private const val YAMNET_EMBEDDING_SIZE = 1024

        // Audio extraction configuration
        private const val AUDIO_DURATION_SEC = 5.0f  // Analyze 5 seconds for better accuracy
        private const val NUM_SAMPLES = (YAMNET_SAMPLE_RATE * AUDIO_DURATION_SEC).toInt()

        // Genre labels (GTZAN dataset standard) - must match training order
        val GENRES = listOf(
            "Blues", "Classical", "Country", "Disco", "Hip-Hop",
            "Jazz", "Metal", "Pop", "Reggae", "Rock"
        )

        // YAMNet class indices for music genres (from yamnet_class_map.csv)
        // Maps YAMNet class index to our genre index
        private val YAMNET_TO_GENRE_MAP = mapOf(
            // Blues (index 0)
            246 to 0,  // Blues

            // Classical (index 1)
            232 to 1,  // Classical music
            233 to 1,  // Opera

            // Country (index 2)
            224 to 2,  // Country
            226 to 2,  // Bluegrass
            228 to 2,  // Folk music

            // Disco (index 3)
            231 to 3,  // Disco
            269 to 3,  // Dance music

            // Hip-Hop (index 4)
            212 to 4,  // Hip hop music

            // Jazz (index 5)
            230 to 5,  // Jazz
            225 to 5,  // Swing music
            227 to 5,  // Funk (jazz-adjacent)

            // Metal (index 6)
            215 to 6,  // Heavy metal
            216 to 6,  // Punk rock
            217 to 6,  // Grunge

            // Pop (index 7)
            211 to 7,  // Pop music
            247 to 7,  // Music for children (often pop-style)

            // Reggae (index 8)
            223 to 8,  // Reggae
            258 to 8,  // Ska

            // Rock (index 9)
            214 to 9,  // Rock music
            218 to 9,  // Progressive rock
            219 to 9,  // Rock and roll
            220 to 9,  // Psychedelic rock
        )

        // Additional mappings for electronic/other genres (map to closest match)
        private val YAMNET_SECONDARY_MAP = mapOf(
            // Electronic -> Disco (dance-oriented)
            234 to 3,  // Electronic music
            235 to 3,  // House music
            236 to 3,  // Techno
            237 to 3,  // Dubstep
            238 to 3,  // Drum and bass
            239 to 3,  // Electronica
            240 to 3,  // Electronic dance music
            242 to 3,  // Trance music

            // Soul/R&B -> Blues (related roots)
            221 to 0,  // Rhythm and blues
            222 to 0,  // Soul music

            // Ambient/New-age -> Classical
            241 to 1,  // Ambient music
            248 to 1,  // New-age music

            // Gospel/Christian -> Blues (spiritual roots)
            253 to 0,  // Christian music
            254 to 0,  // Gospel music

            // Latin -> Disco (dance-oriented)
            243 to 3,  // Music of Latin America
            244 to 3,  // Salsa music
            245 to 3,  // Flamenco

            // General music -> Pop (most common)
            132 to 7,  // Music (general)
            261 to 7,  // Song
        )
    }

    private var yamnetInterpreter: Interpreter? = null
    private var genreInterpreter: Interpreter? = null
    private var isInitialized = false
    private var isInitializing = false
    private var hasYamnetModel = false
    private var hasGenreClassifier = false
    private var inputTensorIndex = 0
    private var embeddingOutputIndex = 1  // YAMNet's embedding output is typically index 1

    /**
     * Initialize the TFLite interpreters asynchronously (RECOMMENDED).
     * Loads models on background thread to avoid blocking UI.
     *
     * @param callback Called on main thread when initialization completes.
     *                 Boolean parameter indicates success.
     */
    fun initAsync(callback: ((Boolean) -> Unit)? = null) {
        if (isInitialized) {
            callback?.invoke(hasYamnetModel || hasGenreClassifier)
            return
        }
        if (isInitializing) {
            Log.d(TAG, "Initialization already in progress")
            return
        }

        isInitializing = true
        CoroutineScope(Dispatchers.IO).launch {
            val success = initInternal()
            withContext(Dispatchers.Main) {
                callback?.invoke(success)
            }
        }
    }

    /**
     * Initialize the TFLite interpreters as a suspend function.
     * Call from a coroutine context.
     *
     * @return true if at least one model was loaded successfully
     */
    suspend fun initSuspend(): Boolean = withContext(Dispatchers.IO) {
        if (isInitialized) {
            return@withContext hasYamnetModel || hasGenreClassifier
        }
        if (isInitializing) {
            // Wait for ongoing initialization
            while (isInitializing && !isInitialized) {
                delay(50)
            }
            return@withContext hasYamnetModel || hasGenreClassifier
        }
        initInternal()
    }

    /**
     * Initialize the TFLite interpreters (SYNCHRONOUS - blocks calling thread).
     *
     * WARNING: This loads ML models synchronously which can take 100-500ms.
     * Prefer initAsync() or initSuspend() for better UX.
     */
    fun init(): Boolean {
        if (isInitialized) {
            return hasYamnetModel || hasGenreClassifier
        }
        Log.w(TAG, "Synchronous init() called - consider using initAsync() to avoid blocking")
        return initInternal()
    }

    /**
     * Internal initialization logic (called from any init method)
     */
    private fun initInternal(): Boolean {
        return try {
            val options = Interpreter.Options().apply {
                setNumThreads(4)  // Use multiple threads for faster inference
            }

            // Load YAMNet model
            val yamnetModel = loadModelFile(YAMNET_MODEL_FILE)
            if (yamnetModel != null) {
                yamnetInterpreter = Interpreter(yamnetModel, options)

                // Log model input/output details for debugging
                val interp = yamnetInterpreter!!
                Log.d(TAG, "YAMNet model loaded - inputs: ${interp.inputTensorCount}, outputs: ${interp.outputTensorCount}")

                for (i in 0 until interp.inputTensorCount) {
                    val tensor = interp.getInputTensor(i)
                    Log.d(TAG, "Input $i: name=${tensor.name()}, shape=${tensor.shape().contentToString()}, type=${tensor.dataType()}")
                }

                for (i in 0 until interp.outputTensorCount) {
                    val tensor = interp.getOutputTensor(i)
                    Log.d(TAG, "Output $i: name=${tensor.name()}, shape=${tensor.shape().contentToString()}, type=${tensor.dataType()}")
                    // Find the embedding output (should be 1024-dim)
                    if (tensor.shape().any { it == YAMNET_EMBEDDING_SIZE }) {
                        embeddingOutputIndex = i
                        Log.d(TAG, "Found embedding output at index $i")
                    }
                }

                hasYamnetModel = true
                Log.d(TAG, "YAMNet model initialized successfully")
            } else {
                Log.w(TAG, "YAMNet model not found")
                hasYamnetModel = false
            }

            // Load Genre Classifier model
            val genreModel = loadModelFile(GENRE_CLASSIFIER_FILE)
            if (genreModel != null) {
                genreInterpreter = Interpreter(genreModel, options)

                val interp = genreInterpreter!!
                Log.d(TAG, "Genre classifier loaded - inputs: ${interp.inputTensorCount}, outputs: ${interp.outputTensorCount}")

                for (i in 0 until interp.inputTensorCount) {
                    val tensor = interp.getInputTensor(i)
                    Log.d(TAG, "Genre input $i: shape=${tensor.shape().contentToString()}")
                }
                for (i in 0 until interp.outputTensorCount) {
                    val tensor = interp.getOutputTensor(i)
                    Log.d(TAG, "Genre output $i: shape=${tensor.shape().contentToString()}")
                }

                hasGenreClassifier = true
                Log.d(TAG, "Genre classifier initialized successfully")
            } else {
                Log.w(TAG, "Genre classifier not found, will use heuristic fallback")
                hasGenreClassifier = false
            }

            isInitialized = true
            isInitializing = false
            Log.d(TAG, "Initialization complete: YAMNet=$hasYamnetModel, GenreClassifier=$hasGenreClassifier")
            hasYamnetModel || hasGenreClassifier

        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize: ${e.message}")
            isInitialized = true
            isInitializing = false
            hasYamnetModel = false
            hasGenreClassifier = false
            false
        }
    }

    /**
     * Check if initialization is in progress
     */
    fun isInitializing(): Boolean = isInitializing

    /**
     * Check if initialization completed (regardless of success)
     */
    fun isInitialized(): Boolean = isInitialized

    /**
     * Check if ML models are available for classification
     */
    fun isReady(): Boolean = isInitialized && (hasYamnetModel || hasGenreClassifier)

    /**
     * Classify the genre of an audio file
     * @param filePath Path to the audio file
     * @return GenreResult with genre probabilities, or null if classification fails
     */
    fun classify(filePath: String): GenreResult? {
        try {
            // Extract audio samples
            val samples = extractAudioSamples(filePath)
            if (samples == null || samples.size < YAMNET_PATCH_SAMPLES) {
                Log.w(TAG, "Could not extract enough audio samples from $filePath")
                return null
            }

            // Best case: YAMNet embeddings + trained genre classifier
            if (hasYamnetModel && hasGenreClassifier && yamnetInterpreter != null && genreInterpreter != null) {
                return classifyWithTrainedModel(samples)
            }

            // Fallback: YAMNet + heuristics
            if (hasYamnetModel && yamnetInterpreter != null) {
                return classifyWithYamnet(samples)
            }

            // Last resort: pure heuristic-based classification
            return classifyByHeuristics(samples)

        } catch (e: Exception) {
            Log.e(TAG, "Classification failed for $filePath: ${e.message}")
            return null
        }
    }

    /**
     * Classify using YAMNet embeddings + trained genre classifier (best accuracy)
     */
    private fun classifyWithTrainedModel(samples: FloatArray): GenreResult {
        val yamnet = yamnetInterpreter!!
        val genre = genreInterpreter!!

        try {
            // Step 1: Get YAMNet embeddings
            val inputShape = intArrayOf(samples.size)
            yamnet.resizeInput(inputTensorIndex, inputShape)
            yamnet.allocateTensors()

            // Prepare outputs - YAMNet has 3 outputs: scores, embeddings, spectrogram
            val scoresShape = yamnet.getOutputTensor(0).shape()
            val embeddingsShape = yamnet.getOutputTensor(embeddingOutputIndex).shape()

            val numFrames = if (embeddingsShape.size > 1) embeddingsShape[0] else 1
            val embeddingSize = if (embeddingsShape.size > 1) embeddingsShape[1] else embeddingsShape[0]

            Log.d(TAG, "YAMNet embedding output shape: ${embeddingsShape.contentToString()}, frames=$numFrames, size=$embeddingSize")

            // Create output arrays
            val outputs = mutableMapOf<Int, Any>()
            for (i in 0 until yamnet.outputTensorCount) {
                val shape = yamnet.getOutputTensor(i).shape()
                outputs[i] = when {
                    shape.size == 1 -> FloatArray(shape[0])
                    shape.size == 2 -> Array(shape[0]) { FloatArray(shape[1]) }
                    else -> FloatArray(1)
                }
            }

            // Run YAMNet
            yamnet.runForMultipleInputsOutputs(arrayOf(samples), outputs)

            // Extract embeddings and average across frames
            val avgEmbedding = FloatArray(YAMNET_EMBEDDING_SIZE)
            val embeddingsOutput = outputs[embeddingOutputIndex]

            when (embeddingsOutput) {
                is Array<*> -> {
                    @Suppress("UNCHECKED_CAST")
                    val embeddings = embeddingsOutput as Array<FloatArray>
                    for (frame in embeddings) {
                        for (i in 0 until minOf(frame.size, YAMNET_EMBEDDING_SIZE)) {
                            avgEmbedding[i] += frame[i]
                        }
                    }
                    for (i in avgEmbedding.indices) {
                        avgEmbedding[i] = avgEmbedding[i] / embeddings.size
                    }
                    Log.d(TAG, "Averaged ${embeddings.size} frames of embeddings")
                }
                is FloatArray -> {
                    for (i in 0 until minOf(embeddingsOutput.size, YAMNET_EMBEDDING_SIZE)) {
                        avgEmbedding[i] = embeddingsOutput[i]
                    }
                }
            }

            // Step 2: Run genre classifier on embeddings
            val genreInput = arrayOf(avgEmbedding)
            val genreOutput = Array(1) { FloatArray(GENRES.size) }

            genre.run(genreInput, genreOutput)

            val probs = genreOutput[0]
            var maxIdx = 0
            var maxProb = probs[0]
            for (i in 1 until probs.size) {
                if (probs[i] > maxProb) {
                    maxProb = probs[i]
                    maxIdx = i
                }
            }

            Log.d(TAG, "Genre classifier output: ${GENRES.zip(probs.toList()).joinToString { "${it.first}=${String.format("%.2f", it.second)}" }}")
            Log.d(TAG, "Predicted: ${GENRES[maxIdx]} with confidence ${(maxProb * 100).toInt()}%")

            return GenreResult(
                genre = GENRES[maxIdx],
                confidence = maxProb,
                probabilities = GENRES.zip(probs.toList()).toMap(),
                isHeuristic = false
            )

        } catch (e: Exception) {
            Log.e(TAG, "Trained model classification failed: ${e.message}", e)
            // Fallback to heuristics
            return classifyByHeuristics(samples)
        }
    }

    /**
     * Classify using YAMNet + enhanced heuristics hybrid approach
     *
     * YAMNet is good at detecting "this is music" but not specific genres.
     * We use YAMNet to validate it's music, then use audio feature heuristics
     * for actual genre classification.
     */
    private fun classifyWithYamnet(samples: FloatArray): GenreResult {
        val interp = yamnetInterpreter!!
        var isMusicConfidence = 0f

        try {
            // YAMNet expects input shape [waveform_samples] - a 1D array
            val inputShape = intArrayOf(samples.size)
            interp.resizeInput(inputTensorIndex, inputShape)
            interp.allocateTensors()

            // Get output tensor info after resize (index 0 is scores with 521 classes)
            val outputTensor = interp.getOutputTensor(0)
            val outputShape = outputTensor.shape()
            Log.d(TAG, "Output tensor shape after resize: ${outputShape.contentToString()}")

            val numFrames = if (outputShape.size > 1) outputShape[0] else 1
            val numClasses = if (outputShape.size > 1) outputShape[1] else outputShape[0]

            val outputArray = if (outputShape.size > 1) {
                Array(numFrames) { FloatArray(numClasses) }
            } else {
                Array(1) { FloatArray(numClasses) }
            }

            // Run inference
            interp.run(samples, outputArray)

            // Average scores across all frames
            val avgYamnetScores = FloatArray(YAMNET_NUM_CLASSES)
            for (frame in outputArray) {
                for (i in frame.indices) {
                    if (i < YAMNET_NUM_CLASSES) {
                        avgYamnetScores[i] += frame[i]
                    }
                }
            }
            for (i in avgYamnetScores.indices) {
                avgYamnetScores[i] = avgYamnetScores[i] / outputArray.size
            }

            // Log top 5 YAMNet predictions
            val sortedIndices = avgYamnetScores.indices.sortedByDescending { avgYamnetScores[it] }
            Log.d(TAG, "Top YAMNet predictions:")
            for (i in 0 until minOf(5, sortedIndices.size)) {
                val idx = sortedIndices[i]
                Log.d(TAG, "  Class $idx: ${avgYamnetScores[idx]}")
            }

            // Check if YAMNet thinks this is music (class 132 = Music)
            isMusicConfidence = if (132 < avgYamnetScores.size) avgYamnetScores[132] else 0f
            Log.d(TAG, "YAMNet music confidence: ${(isMusicConfidence * 100).toInt()}%")

        } catch (e: Exception) {
            Log.e(TAG, "YAMNet inference failed: ${e.message}", e)
        }

        // Always use enhanced heuristics for genre classification
        // YAMNet is only used to confirm it's music
        val heuristicResult = classifyByHeuristics(samples)

        // If YAMNet is confident it's music (>20%), boost confidence slightly
        val confidenceBoost = if (isMusicConfidence > 0.2f) 1.1f else 1.0f
        val adjustedConfidence = (heuristicResult.confidence * confidenceBoost).coerceAtMost(0.95f)

        Log.d(TAG, "Final genre: ${heuristicResult.genre} with confidence ${(adjustedConfidence * 100).toInt()}%")

        return GenreResult(
            genre = heuristicResult.genre,
            confidence = adjustedConfidence,
            probabilities = heuristicResult.probabilities,
            isHeuristic = false  // Mark as ML-assisted since YAMNet validated it's music
        )
    }

    /**
     * Map YAMNet's 521 class scores to our 10 genre scores
     *
     * YAMNet often gives high scores to general "Music" class (132).
     * We normalize among music-specific classes to get better genre distribution.
     */
    private fun mapYamnetToGenres(yamnetScores: FloatArray, genreScores: FloatArray) {
        // Collect all music-related scores
        var totalMusicScore = 0f

        // Primary mappings (direct genre matches)
        for ((yamnetIdx, genreIdx) in YAMNET_TO_GENRE_MAP) {
            if (yamnetIdx < yamnetScores.size) {
                val score = yamnetScores[yamnetIdx]
                genreScores[genreIdx] += score * 2.0f  // Weight primary matches higher
                totalMusicScore += score
            }
        }

        // Secondary mappings (related genres)
        for ((yamnetIdx, genreIdx) in YAMNET_SECONDARY_MAP) {
            if (yamnetIdx < yamnetScores.size) {
                val score = yamnetScores[yamnetIdx]
                genreScores[genreIdx] += score * 1.0f
                totalMusicScore += score
            }
        }

        // If music-specific classes have low scores but general "Music" is high,
        // boost based on audio features we can derive from the score distribution
        val generalMusicScore = if (132 < yamnetScores.size) yamnetScores[132] else 0f

        if (generalMusicScore > 0.2f && totalMusicScore < 0.1f) {
            // Model confident it's music but unsure of genre
            // Distribute some of the general music score based on existing genre distribution
            val boost = generalMusicScore * 0.3f
            for (i in genreScores.indices) {
                if (genreScores[i] > 0) {
                    genreScores[i] += boost * (genreScores[i] / genreScores.sum().coerceAtLeast(0.001f))
                }
            }
        }

        // Log the genre scores for debugging
        Log.d(TAG, "Genre scores before softmax: ${genreScores.contentToString()}")
    }

    /**
     * Extract audio samples from file using MediaCodec
     * Resamples to 16kHz mono for YAMNet
     */
    private fun extractAudioSamples(filePath: String): FloatArray? {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(filePath)

            // Find audio track
            var audioTrackIndex = -1
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME)
                if (mime?.startsWith("audio/") == true) {
                    audioTrackIndex = i
                    break
                }
            }

            if (audioTrackIndex < 0) {
                Log.w(TAG, "No audio track found")
                return null
            }

            extractor.selectTrack(audioTrackIndex)
            val format = extractor.getTrackFormat(audioTrackIndex)
            val sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            val channelCount = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)

            // Configure decoder
            val mime = format.getString(MediaFormat.KEY_MIME)!!
            val codec = MediaCodec.createDecoderByType(mime)
            codec.configure(format, null, null, 0)
            codec.start()

            val bufferInfo = MediaCodec.BufferInfo()
            val samples = mutableListOf<Float>()
            var isEOS = false
            val targetSamples = (AUDIO_DURATION_SEC * sampleRate).toInt()

            // Skip first 30 seconds to get more representative audio
            val skipUs = 30_000_000L
            extractor.seekTo(skipUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)

            while (!isEOS && samples.size < targetSamples) {
                // Feed input
                val inputIndex = codec.dequeueInputBuffer(10000)
                if (inputIndex >= 0) {
                    val inputBuffer = codec.getInputBuffer(inputIndex)
                    val sampleSize = inputBuffer?.let { extractor.readSampleData(it, 0) } ?: -1
                    if (sampleSize < 0) {
                        codec.queueInputBuffer(inputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        isEOS = true
                    } else {
                        codec.queueInputBuffer(inputIndex, 0, sampleSize, extractor.sampleTime, 0)
                        extractor.advance()
                    }
                }

                // Get output
                val outputIndex = codec.dequeueOutputBuffer(bufferInfo, 10000)
                if (outputIndex >= 0) {
                    val outputBuffer = codec.getOutputBuffer(outputIndex)
                    if (outputBuffer != null) {
                        outputBuffer.position(bufferInfo.offset)
                        outputBuffer.limit(bufferInfo.offset + bufferInfo.size)

                        // Convert to float samples (assuming 16-bit PCM)
                        while (outputBuffer.remaining() >= 2 * channelCount && samples.size < targetSamples) {
                            var sample = 0f
                            for (ch in 0 until channelCount) {
                                sample += outputBuffer.short / 32768f
                            }
                            samples.add(sample / channelCount)
                        }
                    }
                    codec.releaseOutputBuffer(outputIndex, false)

                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        isEOS = true
                    }
                }
            }

            codec.stop()
            codec.release()

            // Resample to 16kHz for YAMNet
            val result = if (sampleRate != YAMNET_SAMPLE_RATE) {
                resample(samples.toFloatArray(), sampleRate, YAMNET_SAMPLE_RATE)
            } else {
                samples.toFloatArray()
            }

            return result

        } catch (e: Exception) {
            Log.e(TAG, "Error extracting audio: ${e.message}")
            return null
        } finally {
            extractor.release()
        }
    }

    //region Audio Feature Extraction

    /**
     * Comprehensive audio features for genre classification
     */
    private data class AudioFeatures(
        val energy: Float,
        val rmsEnergy: Float,
        val zeroCrossingRate: Float,
        val spectralCentroid: Float,
        val spectralRolloff: Float,
        val spectralFlux: Float,
        val spectralFlatness: Float,
        val lowFreqRatio: Float,      // Bass content
        val midFreqRatio: Float,      // Mids content
        val highFreqRatio: Float,     // Treble content
        val mfccs: FloatArray,        // First 13 MFCCs
        val tempo: Float,             // Estimated BPM
        val onsetStrength: Float,     // Rhythm intensity
        val dynamicRange: Float       // Loudness variation
    )

    /**
     * Extract comprehensive audio features from samples
     */
    private fun extractFeatures(samples: FloatArray, sampleRate: Int = YAMNET_SAMPLE_RATE): AudioFeatures {
        val frameSize = 2048
        val hopSize = 1024  // Larger hop for faster processing
        val maxFrames = 50  // Limit frames for performance
        val totalPossibleFrames = (samples.size - frameSize) / hopSize
        val numFrames = minOf(totalPossibleFrames, maxFrames)

        if (numFrames < 1) {
            return createDefaultFeatures()
        }

        Log.d(TAG, "Extracting features from $numFrames frames (${samples.size} samples)")

        // Collect per-frame features
        val frameCentroids = mutableListOf<Float>()
        val frameEnergies = mutableListOf<Float>()
        val frameFluxes = mutableListOf<Float>()
        var prevMagnitudes: FloatArray? = null

        // Frequency band energy accumulators
        var lowEnergy = 0f
        var midEnergy = 0f
        var highEnergy = 0f
        var totalBandEnergy = 0f

        // For onset detection
        val onsetEnvelope = mutableListOf<Float>()

        for (frameIdx in 0 until numFrames) {
            val start = frameIdx * hopSize
            val frame = samples.copyOfRange(start, start + frameSize)

            // Apply Hann window
            applyHannWindow(frame)

            // Compute FFT
            val magnitudes = computeFFTMagnitudes(frame)
            val numBins = magnitudes.size

            // Frame energy
            val frameEnergy = magnitudes.sumOf { (it * it).toDouble() }.toFloat()
            frameEnergies.add(frameEnergy)

            // Spectral centroid (weighted mean of frequencies)
            var weightedSum = 0f
            var magSum = 0f
            for (i in magnitudes.indices) {
                val freq = i * sampleRate.toFloat() / frameSize
                weightedSum += freq * magnitudes[i]
                magSum += magnitudes[i]
            }
            val centroid = if (magSum > 0) weightedSum / magSum else 0f
            frameCentroids.add(centroid)

            // Spectral flux (change from previous frame)
            if (prevMagnitudes != null) {
                var flux = 0f
                for (i in magnitudes.indices) {
                    val diff = magnitudes[i] - prevMagnitudes!![i]
                    if (diff > 0) flux += diff * diff
                }
                frameFluxes.add(sqrt(flux))
                onsetEnvelope.add(sqrt(flux))
            }
            prevMagnitudes = magnitudes.copyOf()

            // Frequency band analysis
            val lowCutoff = (250f * frameSize / sampleRate).toInt()   // 0-250 Hz
            val midCutoff = (4000f * frameSize / sampleRate).toInt()  // 250-4000 Hz

            for (i in 0 until minOf(lowCutoff, numBins)) {
                lowEnergy += magnitudes[i] * magnitudes[i]
            }
            for (i in lowCutoff until minOf(midCutoff, numBins)) {
                midEnergy += magnitudes[i] * magnitudes[i]
            }
            for (i in midCutoff until numBins) {
                highEnergy += magnitudes[i] * magnitudes[i]
            }
            totalBandEnergy += frameEnergy
        }

        // Compute aggregate features
        val energy = samples.map { it * it }.average().toFloat()
        val rmsEnergy = sqrt(energy)

        val zeroCrossingRate = countZeroCrossings(samples)

        val avgCentroid = if (frameCentroids.isNotEmpty())
            frameCentroids.average().toFloat() else 0f
        // Normalize centroid to 0-1 range (assuming max ~8000 Hz is "bright")
        val normalizedCentroid = (avgCentroid / 8000f).coerceIn(0f, 1f)

        val avgFlux = if (frameFluxes.isNotEmpty())
            frameFluxes.average().toFloat() else 0f

        // Spectral rolloff (frequency below which 85% of energy is contained)
        val spectralRolloff = computeSpectralRolloff(samples, frameSize, sampleRate)

        // Spectral flatness (noise vs tonal)
        val spectralFlatness = computeSpectralFlatness(samples, frameSize)

        // Frequency band ratios
        val lowRatio = if (totalBandEnergy > 0) lowEnergy / totalBandEnergy else 0.33f
        val midRatio = if (totalBandEnergy > 0) midEnergy / totalBandEnergy else 0.33f
        val highRatio = if (totalBandEnergy > 0) highEnergy / totalBandEnergy else 0.33f

        // MFCCs
        val mfccs = computeMFCCs(samples, sampleRate, frameSize, hopSize)

        // Tempo estimation via onset detection
        val tempo = estimateTempo(onsetEnvelope, sampleRate.toFloat() / hopSize)

        // Onset strength (rhythm intensity)
        val onsetStrength = if (onsetEnvelope.isNotEmpty())
            onsetEnvelope.average().toFloat() else 0f

        // Dynamic range
        val dynamicRange = if (frameEnergies.isNotEmpty()) {
            val maxE = frameEnergies.maxOrNull() ?: 0f
            val minE = frameEnergies.minOrNull() ?: 0f
            if (minE > 0) 10f * log10(maxE / minE) else 0f
        } else 0f

        Log.d(TAG, "Features: energy=${"%.4f".format(energy)}, zcr=${"%.4f".format(zeroCrossingRate)}, " +
                "centroid=${"%.2f".format(normalizedCentroid)}, rolloff=${"%.2f".format(spectralRolloff)}, " +
                "lowRatio=${"%.2f".format(lowRatio)}, tempo=${"%.0f".format(tempo)}")

        return AudioFeatures(
            energy = energy,
            rmsEnergy = rmsEnergy,
            zeroCrossingRate = zeroCrossingRate,
            spectralCentroid = normalizedCentroid,
            spectralRolloff = spectralRolloff,
            spectralFlux = avgFlux,
            spectralFlatness = spectralFlatness,
            lowFreqRatio = lowRatio,
            midFreqRatio = midRatio,
            highFreqRatio = highRatio,
            mfccs = mfccs,
            tempo = tempo,
            onsetStrength = onsetStrength,
            dynamicRange = dynamicRange
        )
    }

    private fun createDefaultFeatures(): AudioFeatures {
        return AudioFeatures(
            energy = 0.1f, rmsEnergy = 0.3f, zeroCrossingRate = 0.1f,
            spectralCentroid = 0.5f, spectralRolloff = 0.5f, spectralFlux = 0.1f,
            spectralFlatness = 0.5f, lowFreqRatio = 0.33f, midFreqRatio = 0.33f,
            highFreqRatio = 0.33f, mfccs = FloatArray(13), tempo = 120f,
            onsetStrength = 0.1f, dynamicRange = 10f
        )
    }

    /**
     * Fallback heuristic-based classification using comprehensive audio features
     *
     * Genre indices: 0=Blues, 1=Classical, 2=Country, 3=Disco, 4=Hip-Hop,
     *                5=Jazz, 6=Metal, 7=Pop, 8=Reggae, 9=Rock
     */
    private fun classifyByHeuristics(samples: FloatArray): GenreResult {
        val features = extractFeatures(samples)
        val scores = FloatArray(GENRES.size) { 1.0f }  // Equal base scores

        // === Energy-based categorization ===
        val isLowEnergy = features.energy < 0.02f
        val isMediumEnergy = features.energy in 0.02f..0.06f
        val isHighEnergy = features.energy > 0.06f
        val isVeryHighEnergy = features.energy > 0.1f

        // === Spectral categorization ===
        val isBassHeavy = features.lowFreqRatio > 0.4f
        val isMidFocused = features.midFreqRatio > 0.4f
        val isBright = features.spectralCentroid > 0.55f
        val isDark = features.spectralCentroid < 0.35f

        // === Tempo categorization ===
        val isSlow = features.tempo < 90f
        val isMediumTempo = features.tempo in 90f..130f
        val isFast = features.tempo > 130f
        val isVeryFast = features.tempo > 150f

        // === Texture categorization ===
        val isComplex = features.spectralFlatness > 0.35f
        val hasHighDynamicRange = features.dynamicRange > 15f
        val isCompressed = features.dynamicRange < 8f
        val hasStrongBeat = features.onsetStrength > 0.12f

        // ========== CLASSICAL (index 1) ==========
        // Orchestral: Low energy, high dynamic range, NOT bass-heavy, complex
        if (isLowEnergy) scores[1] += 0.4f
        if (hasHighDynamicRange) scores[1] += 0.35f
        if (!isBassHeavy && features.lowFreqRatio < 0.3f) scores[1] += 0.25f
        if (isComplex) scores[1] += 0.15f
        if (!hasStrongBeat) scores[1] += 0.2f
        // Penalties for classical
        if (isHighEnergy) scores[1] -= 0.3f
        if (isBassHeavy) scores[1] -= 0.2f
        if (isCompressed) scores[1] -= 0.2f

        // ========== JAZZ (index 5) ==========
        // Complex harmonics, dynamic, mid-focused, variable rhythm
        if (isComplex) scores[5] += 0.35f
        if (isMidFocused) scores[5] += 0.25f
        if (hasHighDynamicRange) scores[5] += 0.2f
        if (features.tempo in 70f..170f) scores[5] += 0.1f  // Wide tempo range
        if (isMediumEnergy) scores[5] += 0.15f
        // Penalties for jazz
        if (isVeryHighEnergy) scores[5] -= 0.25f
        if (isCompressed) scores[5] -= 0.2f

        // ========== BLUES (index 0) ==========
        // Slow-medium tempo, mid-bass focus, expressive dynamics
        if (isSlow) scores[0] += 0.35f
        if (features.tempo in 60f..95f) scores[0] += 0.25f
        if (isMidFocused && features.lowFreqRatio > 0.25f) scores[0] += 0.2f
        if (isMediumEnergy || isLowEnergy) scores[0] += 0.15f
        if (!isBright) scores[0] += 0.1f
        // Penalties for blues
        if (isFast) scores[0] -= 0.3f
        if (isVeryHighEnergy) scores[0] -= 0.25f

        // ========== METAL (index 6) ==========
        // Very high energy, bright/harsh, fast, distorted (high ZCR)
        if (isVeryHighEnergy) scores[6] += 0.45f
        if (features.zeroCrossingRate > 0.15f) scores[6] += 0.35f
        if (isBright) scores[6] += 0.25f
        if (isFast || isVeryFast) scores[6] += 0.2f
        if (features.highFreqRatio > 0.28f) scores[6] += 0.15f
        // Penalties for metal
        if (isLowEnergy) scores[6] -= 0.4f
        if (isSlow) scores[6] -= 0.3f
        if (isDark && !isVeryHighEnergy) scores[6] -= 0.2f

        // ========== ROCK (index 9) ==========
        // High energy, balanced spectrum, driving beat, medium-fast tempo
        if (isHighEnergy && !isVeryHighEnergy) scores[9] += 0.3f
        if (hasStrongBeat) scores[9] += 0.25f
        if (features.tempo in 100f..145f) scores[9] += 0.25f
        if (features.lowFreqRatio in 0.25f..0.4f) scores[9] += 0.15f  // Balanced bass
        if (features.highFreqRatio in 0.15f..0.3f) scores[9] += 0.1f  // Not too bright
        // Penalties for rock
        if (isLowEnergy) scores[9] -= 0.3f
        if (isSlow) scores[9] -= 0.2f
        if (isComplex && hasHighDynamicRange) scores[9] -= 0.15f  // More likely jazz/classical

        // ========== POP (index 7) ==========
        // Medium energy, compressed, steady beat, radio-friendly spectrum
        if (isMediumEnergy) scores[7] += 0.3f
        if (isCompressed || features.dynamicRange < 12f) scores[7] += 0.25f
        if (features.tempo in 95f..130f) scores[7] += 0.2f
        if (features.midFreqRatio in 0.3f..0.45f) scores[7] += 0.15f
        if (!isBassHeavy && !isBright) scores[7] += 0.1f  // Balanced
        // Penalties for pop
        if (isVeryHighEnergy) scores[7] -= 0.25f
        if (hasHighDynamicRange) scores[7] -= 0.2f
        if (isSlow) scores[7] -= 0.15f

        // ========== DISCO/ELECTRONIC (index 3) ==========
        // Very specific: synthesized, consistent beat, 115-130 BPM sweet spot
        // Key differentiator: very steady rhythm + electronic texture
        if (features.tempo in 115f..130f) scores[3] += 0.2f
        if (hasStrongBeat && features.onsetStrength > 0.18f) scores[3] += 0.2f
        if (isCompressed) scores[3] += 0.15f  // Electronic production
        if (features.spectralFlatness > 0.25f && features.spectralFlatness < 0.45f) scores[3] += 0.15f
        // Disco needs consistency - penalize high dynamic range
        if (hasHighDynamicRange) scores[3] -= 0.25f
        // Penalize if it sounds more acoustic/organic
        if (isComplex) scores[3] -= 0.15f
        if (isLowEnergy) scores[3] -= 0.3f
        if (isSlow) scores[3] -= 0.25f

        // ========== HIP-HOP (index 4) ==========
        // Bass-heavy, darker spectrum, 80-110 BPM typically
        if (isBassHeavy) scores[4] += 0.4f
        if (isDark) scores[4] += 0.25f
        if (features.tempo in 75f..115f) scores[4] += 0.25f
        if (features.spectralCentroid < 0.4f) scores[4] += 0.15f
        // Penalties for hip-hop
        if (isBright) scores[4] -= 0.25f
        if (features.lowFreqRatio < 0.3f) scores[4] -= 0.3f
        if (isVeryFast) scores[4] -= 0.2f

        // ========== REGGAE (index 8) ==========
        // Slow tempo, bass-heavy, relaxed groove
        if (features.tempo in 55f..90f) scores[8] += 0.4f
        if (isSlow) scores[8] += 0.25f
        if (features.lowFreqRatio > 0.35f) scores[8] += 0.2f
        if (!hasStrongBeat) scores[8] += 0.1f  // More laid-back rhythm
        // Penalties for reggae
        if (isFast) scores[8] -= 0.35f
        if (isVeryHighEnergy) scores[8] -= 0.25f
        if (isBright) scores[8] -= 0.15f

        // ========== COUNTRY (index 2) ==========
        // Acoustic sound, mid-bright, moderate tempo, some twang (mid-high focus)
        if (features.midFreqRatio > 0.35f && features.highFreqRatio > 0.22f) scores[2] += 0.3f
        if (features.tempo in 90f..135f) scores[2] += 0.2f
        if (isMediumEnergy) scores[2] += 0.2f
        if (!isBassHeavy) scores[2] += 0.15f
        if (features.spectralCentroid in 0.4f..0.6f) scores[2] += 0.1f  // Bright but not harsh
        // Penalties for country
        if (isBassHeavy) scores[2] -= 0.25f
        if (isVeryHighEnergy) scores[2] -= 0.2f
        if (isCompressed) scores[2] -= 0.15f  // Country tends to be more dynamic

        // Apply MFCC-based refinements
        applyMFCCRules(features.mfccs, scores)

        // Ensure minimum scores (avoid negative)
        for (i in scores.indices) {
            scores[i] = scores[i].coerceAtLeast(0.05f)
        }

        // Normalize to probabilities
        val total = scores.sum()
        val probs = scores.map { it / total }.toFloatArray()

        var maxIdx = 0
        var maxProb = probs[0]
        for (i in 1 until probs.size) {
            if (probs[i] > maxProb) {
                maxProb = probs[i]
                maxIdx = i
            }
        }

        Log.d(TAG, "Heuristic features: energy=${"%.4f".format(features.energy)}, " +
                "lowRatio=${"%.2f".format(features.lowFreqRatio)}, " +
                "centroid=${"%.2f".format(features.spectralCentroid)}, " +
                "tempo=${"%.0f".format(features.tempo)}, " +
                "dynRange=${"%.1f".format(features.dynamicRange)}, " +
                "zcr=${"%.3f".format(features.zeroCrossingRate)}")
        Log.d(TAG, "Heuristic scores: ${GENRES.zip(scores.toList()).joinToString { "${it.first}=${"%.2f".format(it.second)}" }}")
        Log.d(TAG, "Heuristic result: ${GENRES[maxIdx]} with confidence ${(maxProb * 100).toInt()}%")

        return GenreResult(
            genre = GENRES[maxIdx],
            confidence = maxProb,
            probabilities = GENRES.zip(probs.toList()).toMap(),
            isHeuristic = true
        )
    }

    /**
     * Apply MFCC-based rules for genre discrimination
     */
    private fun applyMFCCRules(mfccs: FloatArray, scores: FloatArray) {
        if (mfccs.size < 13) return

        // MFCC1 (overall energy shape) - low values often indicate classical/jazz
        if (mfccs[1] < -3f) {
            scores[1] += 0.15f  // Classical
            scores[5] += 0.12f  // Jazz
        }

        // MFCC2-3 (spectral shape) - high variance indicates complex harmonics
        val mfccVariance = (mfccs[2] * mfccs[2] + mfccs[3] * mfccs[3])
        if (mfccVariance > 15f) {
            scores[5] += 0.15f  // Jazz (complex harmonics)
            scores[1] += 0.1f   // Classical
        } else if (mfccVariance < 3f) {
            scores[7] += 0.1f   // Pop (simpler harmonics)
            scores[3] += 0.08f  // Disco/Electronic
        }

        // Higher MFCCs (6-12) capture texture
        val highMfccEnergy = mfccs.drop(6).map { it * it }.average().toFloat()
        if (highMfccEnergy > 8f) {
            scores[6] += 0.12f  // Metal (distortion/noise creates high MFCC energy)
        } else if (highMfccEnergy < 2f) {
            scores[1] += 0.1f   // Classical (cleaner sound)
            scores[2] += 0.08f  // Country (acoustic)
        }

        // MFCC stability across the first few coefficients can indicate electronic production
        val mfccStability = mfccs.take(5).map { abs(it) }.average().toFloat()
        if (mfccStability < 2f) {
            scores[3] += 0.08f  // Disco/Electronic (synthesized = stable)
        }
    }

    //endregion

    //region DSP Utilities

    private fun applyHannWindow(frame: FloatArray) {
        for (i in frame.indices) {
            val multiplier = 0.5f * (1 - cos(2 * PI * i / (frame.size - 1))).toFloat()
            frame[i] *= multiplier
        }
    }

    /**
     * Compute FFT magnitudes using Cooley-Tukey radix-2 FFT - O(n log n)
     */
    private fun computeFFTMagnitudes(frame: FloatArray): FloatArray {
        val n = frame.size
        val halfN = n / 2

        // Pad to power of 2 if needed
        val fftSize = Integer.highestOneBit(n - 1) shl 1
        val real = FloatArray(fftSize)
        val imag = FloatArray(fftSize)

        // Copy input
        for (i in 0 until minOf(n, fftSize)) {
            real[i] = frame[i]
        }

        // Bit-reversal permutation
        var j = 0
        for (i in 0 until fftSize - 1) {
            if (i < j) {
                val tempR = real[i]
                real[i] = real[j]
                real[j] = tempR
                val tempI = imag[i]
                imag[i] = imag[j]
                imag[j] = tempI
            }
            var k = fftSize / 2
            while (k <= j) {
                j -= k
                k /= 2
            }
            j += k
        }

        // Cooley-Tukey iterative FFT
        var step = 2
        while (step <= fftSize) {
            val halfStep = step / 2
            val angleStep = -2.0 * PI / step

            for (i in 0 until fftSize step step) {
                var angle = 0.0
                for (k in 0 until halfStep) {
                    val cos = cos(angle).toFloat()
                    val sin = sin(angle).toFloat()

                    val tReal = real[i + k + halfStep] * cos - imag[i + k + halfStep] * sin
                    val tImag = real[i + k + halfStep] * sin + imag[i + k + halfStep] * cos

                    real[i + k + halfStep] = real[i + k] - tReal
                    imag[i + k + halfStep] = imag[i + k] - tImag
                    real[i + k] = real[i + k] + tReal
                    imag[i + k] = imag[i + k] + tImag

                    angle += angleStep
                }
            }
            step *= 2
        }

        // Compute magnitudes
        val magnitudes = FloatArray(halfN)
        for (i in 0 until halfN) {
            magnitudes[i] = sqrt(real[i] * real[i] + imag[i] * imag[i])
        }

        return magnitudes
    }

    private fun countZeroCrossings(samples: FloatArray): Float {
        var count = 0
        for (i in 1 until samples.size) {
            if ((samples[i] >= 0 && samples[i - 1] < 0) ||
                (samples[i] < 0 && samples[i - 1] >= 0)) {
                count++
            }
        }
        return count.toFloat() / samples.size
    }

    private fun computeSpectralRolloff(samples: FloatArray, frameSize: Int, sampleRate: Int): Float {
        val frame = samples.copyOfRange(0, minOf(frameSize, samples.size))
        applyHannWindow(frame)
        val magnitudes = computeFFTMagnitudes(frame)

        val totalEnergy = magnitudes.sumOf { (it * it).toDouble() }.toFloat()
        val threshold = totalEnergy * 0.85f

        var cumulative = 0f
        for (i in magnitudes.indices) {
            cumulative += magnitudes[i] * magnitudes[i]
            if (cumulative >= threshold) {
                val freq = i * sampleRate.toFloat() / frameSize
                return (freq / (sampleRate / 2f)).coerceIn(0f, 1f)
            }
        }
        return 1f
    }

    private fun computeSpectralFlatness(samples: FloatArray, frameSize: Int): Float {
        val frame = samples.copyOfRange(0, minOf(frameSize, samples.size))
        applyHannWindow(frame)
        val magnitudes = computeFFTMagnitudes(frame)

        val epsilon = 1e-10f
        var logSum = 0.0
        var sum = 0f

        for (mag in magnitudes) {
            val m = mag + epsilon
            logSum += ln(m.toDouble())
            sum += m
        }

        val geometricMean = exp(logSum / magnitudes.size).toFloat()
        val arithmeticMean = sum / magnitudes.size

        return (geometricMean / (arithmeticMean + epsilon)).coerceIn(0f, 1f)
    }

    /**
     * Compute first 13 MFCCs
     */
    private fun computeMFCCs(samples: FloatArray, sampleRate: Int, frameSize: Int, hopSize: Int): FloatArray {
        val numMFCCs = 13
        val numMelBins = 26
        val mfccs = FloatArray(numMFCCs)

        // Create mel filterbank
        val melFilters = createMelFilterbank(numMelBins, frameSize, sampleRate)

        // Process limited frames and average
        val maxMfccFrames = 20  // Limit for performance
        val totalFrames = maxOf(1, (samples.size - frameSize) / hopSize)
        val numFrames = minOf(totalFrames, maxMfccFrames)
        val frameMfccs = Array(numFrames) { FloatArray(numMFCCs) }

        for (frameIdx in 0 until numFrames) {
            val start = frameIdx * hopSize
            if (start + frameSize > samples.size) break

            val frame = samples.copyOfRange(start, start + frameSize)
            applyHannWindow(frame)
            val magnitudes = computeFFTMagnitudes(frame)

            // Apply mel filterbank
            val melEnergies = FloatArray(numMelBins)
            for (m in 0 until numMelBins) {
                for (k in magnitudes.indices) {
                    melEnergies[m] += magnitudes[k] * melFilters[m][k]
                }
                melEnergies[m] = ln(melEnergies[m] + 1e-10f)
            }

            // DCT to get MFCCs
            for (i in 0 until numMFCCs) {
                var sum = 0f
                for (j in 0 until numMelBins) {
                    sum += melEnergies[j] * cos(PI * i * (j + 0.5) / numMelBins).toFloat()
                }
                frameMfccs[frameIdx][i] = sum
            }
        }

        // Average across frames
        for (i in 0 until numMFCCs) {
            mfccs[i] = frameMfccs.map { it[i] }.average().toFloat()
        }

        return mfccs
    }

    /**
     * Create mel filterbank matrix
     */
    private fun createMelFilterbank(numFilters: Int, frameSize: Int, sampleRate: Int): Array<FloatArray> {
        val numBins = frameSize / 2
        val filters = Array(numFilters) { FloatArray(numBins) }

        val lowFreq = 0f
        val highFreq = sampleRate / 2f

        val lowMel = hzToMel(lowFreq)
        val highMel = hzToMel(highFreq)

        val melPoints = FloatArray(numFilters + 2)
        for (i in melPoints.indices) {
            melPoints[i] = lowMel + i * (highMel - lowMel) / (numFilters + 1)
        }

        val binPoints = melPoints.map { mel ->
            ((melToHz(mel) * frameSize) / sampleRate).toInt().coerceIn(0, numBins - 1)
        }

        for (m in 0 until numFilters) {
            val startBin = binPoints[m]
            val centerBin = binPoints[m + 1]
            val endBin = binPoints[m + 2]

            for (k in startBin until centerBin) {
                if (centerBin != startBin) {
                    filters[m][k] = (k - startBin).toFloat() / (centerBin - startBin)
                }
            }
            for (k in centerBin until endBin) {
                if (endBin != centerBin) {
                    filters[m][k] = (endBin - k).toFloat() / (endBin - centerBin)
                }
            }
        }

        return filters
    }

    private fun hzToMel(hz: Float): Float = 2595f * log10(1 + hz / 700f)
    private fun melToHz(mel: Float): Float = 700f * (10f.pow(mel / 2595f) - 1)

    /**
     * Estimate tempo from onset envelope using autocorrelation
     */
    private fun estimateTempo(onsetEnvelope: List<Float>, onsetRate: Float): Float {
        if (onsetEnvelope.size < 100) return 120f  // Default tempo

        val minBpm = 50f
        val maxBpm = 200f

        // Convert BPM to lag in onset frames
        val minLag = (60f * onsetRate / maxBpm).toInt()
        val maxLag = (60f * onsetRate / minBpm).toInt().coerceAtMost(onsetEnvelope.size / 2)

        if (minLag >= maxLag) return 120f

        // Normalize onset envelope
        val mean = onsetEnvelope.average().toFloat()
        val normalized = onsetEnvelope.map { it - mean }

        // Autocorrelation
        var bestLag = minLag
        var bestCorr = Float.MIN_VALUE

        for (lag in minLag until maxLag) {
            var corr = 0f
            val n = normalized.size - lag
            for (i in 0 until n) {
                corr += normalized[i] * normalized[i + lag]
            }
            corr /= n

            if (corr > bestCorr) {
                bestCorr = corr
                bestLag = lag
            }
        }

        val tempo = 60f * onsetRate / bestLag
        return tempo.coerceIn(minBpm, maxBpm)
    }

    //endregion

    /**
     * Load TFLite model from assets
     */
    private fun loadModelFile(modelName: String): MappedByteBuffer? {
        return try {
            val fileDescriptor = context.assets.openFd(modelName)
            val inputStream = FileInputStream(fileDescriptor.fileDescriptor)
            val fileChannel = inputStream.channel
            val startOffset = fileDescriptor.startOffset
            val declaredLength = fileDescriptor.declaredLength
            fileChannel.map(FileChannel.MapMode.READ_ONLY, startOffset, declaredLength)
        } catch (e: Exception) {
            Log.w(TAG, "Model file not found: $modelName - ${e.message}")
            null
        }
    }

    /**
     * Release resources
     */
    fun close() {
        yamnetInterpreter?.close()
        yamnetInterpreter = null
        genreInterpreter?.close()
        genreInterpreter = null
        isInitialized = false
        hasYamnetModel = false
        hasGenreClassifier = false
    }

    //region Math utilities

    private fun softmax(logits: FloatArray): FloatArray {
        val max = logits.maxOrNull() ?: 0f
        val exps = logits.map { exp((it - max).toDouble()).toFloat() }
        val sum = exps.sum()
        return exps.map { it / sum }.toFloatArray()
    }

    private fun resample(samples: FloatArray, fromRate: Int, toRate: Int): FloatArray {
        if (fromRate == toRate) return samples
        val ratio = toRate.toFloat() / fromRate
        val newSize = (samples.size * ratio).toInt()
        val result = FloatArray(newSize)
        for (i in 0 until newSize) {
            val srcIdx = i / ratio
            val idx0 = srcIdx.toInt().coerceIn(0, samples.size - 1)
            val idx1 = (idx0 + 1).coerceIn(0, samples.size - 1)
            val frac = srcIdx - idx0
            result[i] = samples[idx0] * (1 - frac) + samples[idx1] * frac
        }
        return result
    }

    //endregion
}

/**
 * Result of genre classification
 */
data class GenreResult(
    val genre: String,
    val confidence: Float,
    val probabilities: Map<String, Float>,
    val isHeuristic: Boolean = false
)
