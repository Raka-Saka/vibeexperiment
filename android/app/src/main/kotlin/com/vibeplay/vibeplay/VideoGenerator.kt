package com.vibeplay.vibeplay

import android.content.Context
import android.graphics.*
import android.media.*
import java.io.File
import java.nio.ByteBuffer
import kotlin.math.sin
import kotlin.random.Random

class VideoGenerator(private val context: Context) {

    companion object {
        private const val TAG = "VideoGenerator"
        private const val VIDEO_WIDTH = 1280
        private const val VIDEO_HEIGHT = 720
        private const val FRAME_RATE = 30
        private const val I_FRAME_INTERVAL = 1
        private const val VIDEO_BIT_RATE = 2000000
        private const val AUDIO_BIT_RATE = 128000
        private const val AUDIO_SAMPLE_RATE = 44100
        private const val AUDIO_CHANNEL_COUNT = 2
    }

    fun generateWaveformVideo(
        audioPath: String,
        outputPath: String,
        title: String,
        artist: String,
        onProgress: (Float) -> Unit
    ): Boolean {
        try {
            android.util.Log.d(TAG, "Starting video generation for: $audioPath")

            // Get audio duration
            val retriever = MediaMetadataRetriever()
            retriever.setDataSource(audioPath)
            val durationMs = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLong() ?: 0
            retriever.release()

            if (durationMs == 0L) {
                android.util.Log.e(TAG, "Duration is 0, aborting")
                return false
            }

            android.util.Log.d(TAG, "Audio duration: ${durationMs}ms")

            val durationUs = durationMs * 1000
            val totalFrames = (durationMs * FRAME_RATE / 1000).toInt()

            // First, transcode audio to AAC
            val aacAudioPath = outputPath + ".aac.m4a"
            android.util.Log.d(TAG, "Transcoding audio to AAC...")
            onProgress(0.05f)

            val audioTranscoded = transcodeAudioToAAC(audioPath, aacAudioPath, durationUs)
            if (!audioTranscoded) {
                android.util.Log.e(TAG, "Audio transcoding failed")
                // Continue without audio
            } else {
                android.util.Log.d(TAG, "Audio transcoding complete")
            }

            onProgress(0.2f)

            // Setup video encoder
            val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, VIDEO_WIDTH, VIDEO_HEIGHT)
            format.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            format.setInteger(MediaFormat.KEY_BIT_RATE, VIDEO_BIT_RATE)
            format.setInteger(MediaFormat.KEY_FRAME_RATE, FRAME_RATE)
            format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL)

            val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
            encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)

            val inputSurface = encoder.createInputSurface()
            encoder.start()

            // Setup muxer
            val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            var videoTrackIndex = -1
            var muxerStarted = false

            // Generate frames
            val bufferInfo = MediaCodec.BufferInfo()
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            val random = Random(42)

            // Pre-generate waveform data
            val waveformBars = List(50) { random.nextFloat() * 0.5f + 0.3f }

            android.util.Log.d(TAG, "Generating $totalFrames video frames...")

            for (frameIndex in 0 until totalFrames) {
                // Draw frame on surface
                val canvas = inputSurface.lockHardwareCanvas()
                drawWaveformFrame(canvas, title, artist, frameIndex, totalFrames, waveformBars, paint)
                inputSurface.unlockCanvasAndPost(canvas)

                // Encode frame
                drainEncoder(encoder, bufferInfo, muxer, videoTrackIndex, muxerStarted) { trackIndex, started ->
                    videoTrackIndex = trackIndex
                    muxerStarted = started
                }

                // Progress from 0.2 to 0.8 during frame generation
                onProgress(0.2f + (frameIndex.toFloat() / totalFrames) * 0.6f)
            }

            // Signal end of stream
            encoder.signalEndOfInputStream()
            drainEncoder(encoder, bufferInfo, muxer, videoTrackIndex, muxerStarted, drain = true) { _, _ -> }

            // Cleanup video encoder
            encoder.stop()
            encoder.release()
            muxer.stop()
            muxer.release()
            inputSurface.release()

            android.util.Log.d(TAG, "Video encoding complete, now muxing audio...")
            onProgress(0.85f)

            // Now mux audio if transcoding succeeded
            if (audioTranscoded && File(aacAudioPath).exists()) {
                muxAudio(outputPath, aacAudioPath, durationUs)
                File(aacAudioPath).delete()
            } else {
                android.util.Log.w(TAG, "Skipping audio mux - no transcoded audio available")
            }

            onProgress(1f)
            android.util.Log.d(TAG, "Video generation complete: $outputPath")
            return true
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Video generation failed: ${e.message}")
            e.printStackTrace()
            return false
        }
    }

    private fun transcodeAudioToAAC(inputPath: String, outputPath: String, durationUs: Long): Boolean {
        var decoder: MediaCodec? = null
        var encoder: MediaCodec? = null
        var extractor: MediaExtractor? = null
        var muxer: MediaMuxer? = null

        try {
            // Setup extractor
            extractor = MediaExtractor()
            extractor.setDataSource(inputPath)

            // Find audio track
            var audioTrackIndex = -1
            var inputFormat: MediaFormat? = null
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    inputFormat = format
                    android.util.Log.d(TAG, "Found audio track: $mime")
                    break
                }
            }

            if (audioTrackIndex == -1 || inputFormat == null) {
                android.util.Log.e(TAG, "No audio track found in input file")
                return false
            }

            extractor.selectTrack(audioTrackIndex)

            // Get input audio properties
            val inputMime = inputFormat.getString(MediaFormat.KEY_MIME) ?: ""
            val sampleRate = inputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            val channelCount = try {
                inputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            } catch (e: Exception) {
                2
            }

            android.util.Log.d(TAG, "Input audio: $inputMime, ${sampleRate}Hz, $channelCount channels")

            // Setup decoder
            decoder = MediaCodec.createDecoderByType(inputMime)
            decoder.configure(inputFormat, null, null, 0)
            decoder.start()

            // Setup AAC encoder
            val encoderFormat = MediaFormat.createAudioFormat(
                MediaFormat.MIMETYPE_AUDIO_AAC,
                sampleRate,
                channelCount
            )
            encoderFormat.setInteger(MediaFormat.KEY_BIT_RATE, AUDIO_BIT_RATE)
            encoderFormat.setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)

            encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
            encoder.configure(encoderFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            encoder.start()

            // Setup muxer (will start after getting encoder output format)
            muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            var muxerTrackIndex = -1
            var muxerStarted = false

            val inputBuffer = ByteBuffer.allocate(1024 * 1024)
            val decoderBufferInfo = MediaCodec.BufferInfo()
            val encoderBufferInfo = MediaCodec.BufferInfo()

            var inputDone = false
            var decoderDone = false
            var encoderDone = false
            var samplesProcessed = 0

            while (!encoderDone) {
                // Feed input to decoder
                if (!inputDone) {
                    val inputBufferIndex = decoder.dequeueInputBuffer(10000)
                    if (inputBufferIndex >= 0) {
                        val buffer = decoder.getInputBuffer(inputBufferIndex)!!
                        val sampleSize = extractor.readSampleData(buffer, 0)
                        if (sampleSize < 0) {
                            decoder.queueInputBuffer(inputBufferIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                            android.util.Log.d(TAG, "Decoder input done")
                        } else {
                            val presentationTimeUs = extractor.sampleTime
                            decoder.queueInputBuffer(inputBufferIndex, 0, sampleSize, presentationTimeUs, 0)
                            extractor.advance()
                        }
                    }
                }

                // Get decoded output and feed to encoder
                if (!decoderDone) {
                    val decoderOutputIndex = decoder.dequeueOutputBuffer(decoderBufferInfo, 10000)
                    when {
                        decoderOutputIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {}
                        decoderOutputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            android.util.Log.d(TAG, "Decoder output format changed")
                        }
                        decoderOutputIndex >= 0 -> {
                            if (decoderBufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                                decoderDone = true
                                // Signal encoder end of stream
                                val encoderInputIndex = encoder.dequeueInputBuffer(10000)
                                if (encoderInputIndex >= 0) {
                                    encoder.queueInputBuffer(encoderInputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                }
                                android.util.Log.d(TAG, "Decoder output done")
                            } else {
                                val decodedBuffer = decoder.getOutputBuffer(decoderOutputIndex)
                                if (decodedBuffer != null && decoderBufferInfo.size > 0) {
                                    // Feed to encoder
                                    val encoderInputIndex = encoder.dequeueInputBuffer(10000)
                                    if (encoderInputIndex >= 0) {
                                        val encoderInputBuffer = encoder.getInputBuffer(encoderInputIndex)!!
                                        encoderInputBuffer.clear()

                                        decodedBuffer.position(decoderBufferInfo.offset)
                                        decodedBuffer.limit(decoderBufferInfo.offset + decoderBufferInfo.size)

                                        val bytesToCopy = minOf(decoderBufferInfo.size, encoderInputBuffer.remaining())
                                        val tempBuffer = ByteArray(bytesToCopy)
                                        decodedBuffer.get(tempBuffer)
                                        encoderInputBuffer.put(tempBuffer)

                                        encoder.queueInputBuffer(
                                            encoderInputIndex,
                                            0,
                                            bytesToCopy,
                                            decoderBufferInfo.presentationTimeUs,
                                            0
                                        )
                                        samplesProcessed++
                                    }
                                }
                            }
                            decoder.releaseOutputBuffer(decoderOutputIndex, false)
                        }
                    }
                }

                // Get encoded output and write to muxer
                val encoderOutputIndex = encoder.dequeueOutputBuffer(encoderBufferInfo, 10000)
                when {
                    encoderOutputIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {}
                    encoderOutputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        if (!muxerStarted) {
                            muxerTrackIndex = muxer.addTrack(encoder.outputFormat)
                            muxer.start()
                            muxerStarted = true
                            android.util.Log.d(TAG, "AAC muxer started")
                        }
                    }
                    encoderOutputIndex >= 0 -> {
                        val encodedBuffer = encoder.getOutputBuffer(encoderOutputIndex)
                        if (encodedBuffer != null && encoderBufferInfo.size > 0 && muxerStarted) {
                            if (encoderBufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0) {
                                encodedBuffer.position(encoderBufferInfo.offset)
                                encodedBuffer.limit(encoderBufferInfo.offset + encoderBufferInfo.size)
                                muxer.writeSampleData(muxerTrackIndex, encodedBuffer, encoderBufferInfo)
                            }
                        }
                        encoder.releaseOutputBuffer(encoderOutputIndex, false)

                        if (encoderBufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            encoderDone = true
                            android.util.Log.d(TAG, "Encoder output done, samples processed: $samplesProcessed")
                        }
                    }
                }
            }

            android.util.Log.d(TAG, "Audio transcoding complete")
            return true

        } catch (e: Exception) {
            android.util.Log.e(TAG, "Audio transcoding failed: ${e.message}")
            e.printStackTrace()
            return false
        } finally {
            try {
                decoder?.stop()
                decoder?.release()
                encoder?.stop()
                encoder?.release()
                extractor?.release()
                muxer?.stop()
                muxer?.release()
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Cleanup error: ${e.message}")
            }
        }
    }

    private fun drawWaveformFrame(
        canvas: Canvas,
        title: String,
        artist: String,
        frameIndex: Int,
        totalFrames: Int,
        waveformBars: List<Float>,
        paint: Paint
    ) {
        // Background gradient
        val gradient = LinearGradient(
            0f, 0f, VIDEO_WIDTH.toFloat(), VIDEO_HEIGHT.toFloat(),
            intArrayOf(Color.parseColor("#1a1a2e"), Color.parseColor("#16213e"), Color.parseColor("#0f3460")),
            null, Shader.TileMode.CLAMP
        )
        paint.shader = gradient
        canvas.drawRect(0f, 0f, VIDEO_WIDTH.toFloat(), VIDEO_HEIGHT.toFloat(), paint)
        paint.shader = null

        // Waveform bars with animation
        val barWidth = VIDEO_WIDTH / (waveformBars.size * 1.5f)
        val spacing = barWidth * 0.5f
        val maxHeight = VIDEO_HEIGHT * 0.5f
        val centerY = VIDEO_HEIGHT / 2f
        val animationPhase = (frameIndex.toFloat() / totalFrames) * Math.PI * 4

        val barGradient = LinearGradient(
            0f, centerY - maxHeight / 2, 0f, centerY + maxHeight / 2,
            intArrayOf(Color.parseColor("#6366f1"), Color.parseColor("#a855f7"), Color.parseColor("#ec4899")),
            null, Shader.TileMode.CLAMP
        )
        paint.shader = barGradient

        for (i in waveformBars.indices) {
            val animatedHeight = waveformBars[i] * (0.7f + 0.3f * sin(animationPhase + i * 0.3).toFloat())
            val barHeight = maxHeight * animatedHeight
            val x = (i * (barWidth + spacing)) + spacing
            val top = centerY - barHeight / 2
            val bottom = centerY + barHeight / 2

            canvas.drawRoundRect(x, top, x + barWidth, bottom, barWidth / 2, barWidth / 2, paint)
        }
        paint.shader = null

        // Title
        paint.color = Color.WHITE
        paint.textSize = 48f
        paint.textAlign = Paint.Align.CENTER
        paint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        canvas.drawText(title, VIDEO_WIDTH / 2f, VIDEO_HEIGHT * 0.85f, paint)

        // Artist
        paint.textSize = 32f
        paint.alpha = 180
        paint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
        canvas.drawText(artist, VIDEO_WIDTH / 2f, VIDEO_HEIGHT * 0.92f, paint)
        paint.alpha = 255
    }

    private fun drainEncoder(
        encoder: MediaCodec,
        bufferInfo: MediaCodec.BufferInfo,
        muxer: MediaMuxer,
        videoTrackIndex: Int,
        muxerStarted: Boolean,
        drain: Boolean = false,
        onTrackAdded: (Int, Boolean) -> Unit
    ) {
        var trackIndex = videoTrackIndex
        var started = muxerStarted

        while (true) {
            val outputBufferIndex = encoder.dequeueOutputBuffer(bufferInfo, if (drain) 10000 else 0)

            when {
                outputBufferIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!drain) break
                }
                outputBufferIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    trackIndex = muxer.addTrack(encoder.outputFormat)
                    muxer.start()
                    started = true
                    onTrackAdded(trackIndex, started)
                }
                outputBufferIndex >= 0 -> {
                    val encodedData = encoder.getOutputBuffer(outputBufferIndex) ?: continue

                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                        bufferInfo.size = 0
                    }

                    if (bufferInfo.size != 0 && started) {
                        encodedData.position(bufferInfo.offset)
                        encodedData.limit(bufferInfo.offset + bufferInfo.size)
                        muxer.writeSampleData(trackIndex, encodedData, bufferInfo)
                    }

                    encoder.releaseOutputBuffer(outputBufferIndex, false)

                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        break
                    }
                }
            }
        }
    }

    private fun muxAudio(videoPath: String, aacAudioPath: String, durationUs: Long) {
        val tempVideoPath = videoPath + ".temp"
        File(videoPath).renameTo(File(tempVideoPath))

        try {
            val videoExtractor = MediaExtractor()
            videoExtractor.setDataSource(tempVideoPath)

            val audioExtractor = MediaExtractor()
            audioExtractor.setDataSource(aacAudioPath)

            val muxer = MediaMuxer(videoPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

            // Add video track
            var videoTrackIndex = -1
            var videoFormat: MediaFormat? = null
            for (i in 0 until videoExtractor.trackCount) {
                val format = videoExtractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("video/")) {
                    videoExtractor.selectTrack(i)
                    videoFormat = format
                    videoTrackIndex = muxer.addTrack(format)
                    android.util.Log.d(TAG, "Video track added: $mime")
                    break
                }
            }

            // Add audio track (AAC)
            var audioTrackIndex = -1
            for (i in 0 until audioExtractor.trackCount) {
                val format = audioExtractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("audio/")) {
                    audioExtractor.selectTrack(i)
                    audioTrackIndex = muxer.addTrack(format)
                    android.util.Log.d(TAG, "Audio track added: $mime")
                    break
                }
            }

            if (audioTrackIndex == -1) {
                android.util.Log.e(TAG, "No audio track found in AAC file")
                throw Exception("No audio track found")
            }

            muxer.start()

            val buffer = ByteBuffer.allocate(2 * 1024 * 1024)
            val bufferInfo = MediaCodec.BufferInfo()

            val videoDuration = videoFormat?.getLong(MediaFormat.KEY_DURATION) ?: durationUs

            // Write video samples
            var videoSamplesWritten = 0
            while (true) {
                buffer.clear()
                val sampleSize = videoExtractor.readSampleData(buffer, 0)
                if (sampleSize < 0) break

                bufferInfo.offset = 0
                bufferInfo.size = sampleSize
                bufferInfo.presentationTimeUs = videoExtractor.sampleTime
                bufferInfo.flags = videoExtractor.sampleFlags

                muxer.writeSampleData(videoTrackIndex, buffer, bufferInfo)
                videoSamplesWritten++
                videoExtractor.advance()
            }
            android.util.Log.d(TAG, "Video samples written: $videoSamplesWritten")

            // Write audio samples
            var audioSamplesWritten = 0
            while (true) {
                buffer.clear()
                val sampleSize = audioExtractor.readSampleData(buffer, 0)
                if (sampleSize < 0) break

                val sampleTime = audioExtractor.sampleTime
                if (sampleTime > videoDuration) break

                bufferInfo.offset = 0
                bufferInfo.size = sampleSize
                bufferInfo.presentationTimeUs = sampleTime
                bufferInfo.flags = audioExtractor.sampleFlags

                muxer.writeSampleData(audioTrackIndex, buffer, bufferInfo)
                audioSamplesWritten++
                audioExtractor.advance()
            }
            android.util.Log.d(TAG, "Audio samples written: $audioSamplesWritten")

            muxer.stop()
            muxer.release()
            videoExtractor.release()
            audioExtractor.release()

            File(tempVideoPath).delete()
            android.util.Log.d(TAG, "Final muxing complete! Video has $videoSamplesWritten video and $audioSamplesWritten audio samples")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Muxing failed: ${e.message}")
            e.printStackTrace()
            // Fallback: just use video without audio
            if (File(tempVideoPath).exists()) {
                File(videoPath).delete()
                File(tempVideoPath).renameTo(File(videoPath))
            }
        }
    }
}
