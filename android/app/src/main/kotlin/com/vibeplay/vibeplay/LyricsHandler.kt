package com.vibeplay.vibeplay

import android.media.MediaMetadataRetriever
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.RandomAccessFile

class LyricsHandler : MethodChannel.MethodCallHandler {
    companion object {
        private const val TAG = "LyricsHandler"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "extractLyrics" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("INVALID_ARGS", "Missing path argument", null)
                    return
                }
                val lyrics = extractLyrics(path)
                result.success(lyrics)
            }
            else -> result.notImplemented()
        }
    }

    private fun extractLyrics(path: String): Map<String, Any?>? {
        val file = File(path)
        if (!file.exists()) {
            Log.w(TAG, "File does not exist: $path")
            return null
        }

        // Try using MediaMetadataRetriever first (limited support)
        val retrieverLyrics = extractWithRetriever(path)
        if (retrieverLyrics != null) {
            return retrieverLyrics
        }

        // Try parsing ID3v2 tags directly for USLT/SYLT frames
        val id3Lyrics = extractFromID3(path)
        if (id3Lyrics != null) {
            return id3Lyrics
        }

        return null
    }

    private fun extractWithRetriever(path: String): Map<String, Any?>? {
        return try {
            val retriever = MediaMetadataRetriever()
            retriever.setDataSource(path)

            // Try to get lyrics - not always available
            val lyrics = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_COMPOSER)
            retriever.release()

            // MediaMetadataRetriever doesn't have direct lyrics support
            // This is just a fallback that rarely works
            null
        } catch (e: Exception) {
            Log.e(TAG, "Error with MediaMetadataRetriever: ${e.message}")
            null
        }
    }

    private fun extractFromID3(path: String): Map<String, Any?>? {
        var raf: RandomAccessFile? = null
        try {
            raf = RandomAccessFile(path, "r")

            // Check for ID3v2 header
            val header = ByteArray(10)
            raf.read(header)

            if (header[0].toInt().toChar() != 'I' ||
                header[1].toInt().toChar() != 'D' ||
                header[2].toInt().toChar() != '3') {
                Log.d(TAG, "No ID3v2 header found")
                return null
            }

            val majorVersion = header[3].toInt()
            val minorVersion = header[4].toInt()
            Log.d(TAG, "ID3v2.$majorVersion.$minorVersion found")

            // Calculate tag size (syncsafe integer)
            val tagSize = ((header[6].toInt() and 0x7F) shl 21) or
                    ((header[7].toInt() and 0x7F) shl 14) or
                    ((header[8].toInt() and 0x7F) shl 7) or
                    (header[9].toInt() and 0x7F)

            Log.d(TAG, "ID3 tag size: $tagSize bytes")

            // Read frames
            var position = 10L
            val endPosition = 10 + tagSize

            while (position < endPosition - 10) {
                raf.seek(position)

                // Read frame header
                val frameHeader = ByteArray(10)
                val bytesRead = raf.read(frameHeader)
                if (bytesRead < 10) break

                val frameId = String(frameHeader, 0, 4)

                // Check for padding (all zeros)
                if (frameId == "\u0000\u0000\u0000\u0000") break

                // Calculate frame size based on version
                val frameSize = if (majorVersion >= 4) {
                    // ID3v2.4 uses syncsafe integers
                    ((frameHeader[4].toInt() and 0x7F) shl 21) or
                    ((frameHeader[5].toInt() and 0x7F) shl 14) or
                    ((frameHeader[6].toInt() and 0x7F) shl 7) or
                    (frameHeader[7].toInt() and 0x7F)
                } else {
                    // ID3v2.3 and earlier use regular integers
                    ((frameHeader[4].toInt() and 0xFF) shl 24) or
                    ((frameHeader[5].toInt() and 0xFF) shl 16) or
                    ((frameHeader[6].toInt() and 0xFF) shl 8) or
                    (frameHeader[7].toInt() and 0xFF)
                }

                if (frameSize <= 0 || frameSize > tagSize) {
                    Log.d(TAG, "Invalid frame size: $frameSize for frame $frameId")
                    break
                }

                Log.d(TAG, "Frame: $frameId, size: $frameSize")

                // Check for lyrics frames
                if (frameId == "USLT" || frameId == "SYLT") {
                    val frameData = ByteArray(frameSize)
                    raf.read(frameData)

                    val lyrics = parseUsltFrame(frameData, frameId == "SYLT")
                    if (lyrics != null) {
                        return lyrics
                    }
                }

                position += 10 + frameSize
            }

            return null
        } catch (e: Exception) {
            Log.e(TAG, "Error extracting ID3 lyrics: ${e.message}")
            e.printStackTrace()
            return null
        } finally {
            try {
                raf?.close()
            } catch (e: Exception) {
                // Ignore
            }
        }
    }

    private fun parseUsltFrame(data: ByteArray, isSynced: Boolean): Map<String, Any?>? {
        if (data.isEmpty()) return null

        try {
            // First byte is text encoding
            val encoding = data[0].toInt()

            // Bytes 1-3 are language code
            val language = if (data.size >= 4) {
                String(data, 1, 3).trim()
            } else "eng"

            // Find content descriptor (null-terminated string) and lyrics
            var contentStart = 4
            val encodingCharset = when (encoding) {
                0 -> Charsets.ISO_8859_1
                1 -> Charsets.UTF_16
                2 -> Charsets.UTF_16BE
                3 -> Charsets.UTF_8
                else -> Charsets.ISO_8859_1
            }

            // Skip content descriptor (find null terminator)
            while (contentStart < data.size) {
                if (encoding == 1 || encoding == 2) {
                    // UTF-16 uses double-null terminator
                    if (contentStart + 1 < data.size &&
                        data[contentStart].toInt() == 0 &&
                        data[contentStart + 1].toInt() == 0) {
                        contentStart += 2
                        break
                    }
                    contentStart++
                } else {
                    if (data[contentStart].toInt() == 0) {
                        contentStart++
                        break
                    }
                    contentStart++
                }
            }

            if (contentStart >= data.size) {
                Log.d(TAG, "No lyrics content found after descriptor")
                return null
            }

            val lyricsBytes = data.copyOfRange(contentStart, data.size)
            val lyricsText = String(lyricsBytes, encodingCharset).trim()

            if (lyricsText.isEmpty()) return null

            Log.d(TAG, "Extracted lyrics (${lyricsText.length} chars), synced: $isSynced")

            return mapOf(
                "lyrics" to lyricsText,
                "isSynced" to isSynced,
                "language" to language
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing USLT frame: ${e.message}")
            return null
        }
    }
}
