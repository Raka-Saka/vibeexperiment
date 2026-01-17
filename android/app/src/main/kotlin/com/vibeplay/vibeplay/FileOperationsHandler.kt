package com.vibeplay.vibeplay

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

/**
 * Handles file operations that require special permissions on Android 10+
 * Uses MediaStore API for writing to external storage
 */
class FileOperationsHandler(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "FileOperationsHandler"
    }

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasManageStoragePermission" -> {
                val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    Environment.isExternalStorageManager()
                } else {
                    true // Not needed on Android 9 and below
                }
                result.success(hasPermission)
            }
            "openManageStorageSettings" -> {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                            data = Uri.parse("package:${context.packageName}")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } else {
                        result.success(false) // Not needed on older Android
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to open storage settings: ${e.message}")
                    // Fallback to general settings
                    try {
                        val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e2: Exception) {
                        result.error("SETTINGS_ERROR", e2.message, null)
                    }
                }
            }
            "writeFileBytes" -> {
                val filePath = call.argument<String>("filePath")
                val bytes = call.argument<ByteArray>("bytes")

                if (filePath == null || bytes == null) {
                    result.error("INVALID_ARGS", "Missing filePath or bytes", null)
                    return
                }

                scope.launch {
                    try {
                        val success = writeFileBytes(filePath, bytes)
                        withContext(Dispatchers.Main) {
                            result.success(success)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error writing file: ${e.message}", e)
                        withContext(Dispatchers.Main) {
                            result.error("WRITE_ERROR", e.message, null)
                        }
                    }
                }
            }
            "copyFileToMediaStore" -> {
                val sourcePath = call.argument<String>("sourcePath")
                val targetPath = call.argument<String>("targetPath")

                if (sourcePath == null || targetPath == null) {
                    result.error("INVALID_ARGS", "Missing sourcePath or targetPath", null)
                    return
                }

                scope.launch {
                    try {
                        val success = copyFileToMediaStore(sourcePath, targetPath)
                        withContext(Dispatchers.Main) {
                            result.success(success)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error copying file: ${e.message}", e)
                        withContext(Dispatchers.Main) {
                            result.error("COPY_ERROR", e.message, null)
                        }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private suspend fun writeFileBytes(filePath: String, bytes: ByteArray): Boolean {
        return withContext(Dispatchers.IO) {
            val file = File(filePath)

            // Try direct file write first (works for app-private storage)
            try {
                FileOutputStream(file).use { it.write(bytes) }
                Log.d(TAG, "Direct write succeeded for $filePath")
                return@withContext true
            } catch (e: Exception) {
                Log.d(TAG, "Direct write failed, trying MediaStore: ${e.message}")
            }

            // For Android 10+ external storage, use MediaStore
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                return@withContext writeViaMediaStore(filePath, bytes)
            }

            // For older Android, the direct write should have worked
            false
        }
    }

    private suspend fun copyFileToMediaStore(sourcePath: String, targetPath: String): Boolean {
        return withContext(Dispatchers.IO) {
            val sourceFile = File(sourcePath)
            if (!sourceFile.exists()) {
                Log.e(TAG, "Source file does not exist: $sourcePath")
                return@withContext false
            }

            Log.d(TAG, "Copying from $sourcePath to $targetPath via MediaStore")

            // Read source file
            val bytes = sourceFile.readBytes()
            Log.d(TAG, "Read ${bytes.size} bytes from source file")

            // Try direct write first
            try {
                val targetFile = File(targetPath)
                FileOutputStream(targetFile).use { it.write(bytes) }
                Log.d(TAG, "Direct copy succeeded for $targetPath")
                return@withContext true
            } catch (e: Exception) {
                Log.d(TAG, "Direct copy failed, trying MediaStore: ${e.message}")
            }

            // Use MediaStore for Android 10+
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                return@withContext writeViaMediaStore(targetPath, bytes)
            }

            false
        }
    }

    private fun writeViaMediaStore(filePath: String, bytes: ByteArray): Boolean {
        val file = File(filePath)
        val fileName = file.name
        val mimeType = when {
            fileName.endsWith(".mp3", true) -> "audio/mpeg"
            fileName.endsWith(".flac", true) -> "audio/flac"
            fileName.endsWith(".m4a", true) -> "audio/mp4"
            fileName.endsWith(".ogg", true) -> "audio/ogg"
            fileName.endsWith(".wav", true) -> "audio/wav"
            else -> "audio/*"
        }

        // Find the existing file in MediaStore
        val existingUri = findMediaStoreUri(filePath)

        if (existingUri != null) {
            // Update existing file
            try {
                context.contentResolver.openOutputStream(existingUri, "wt")?.use { outputStream ->
                    outputStream.write(bytes)
                }
                Log.d(TAG, "MediaStore update succeeded for $filePath")
                return true
            } catch (e: Exception) {
                Log.e(TAG, "MediaStore update failed: ${e.message}", e)
            }
        }

        // If we can't find or update the existing file, try to create a new entry
        // This is a fallback and may result in a duplicate
        try {
            val relativePath = getRelativePath(filePath)
            val values = ContentValues().apply {
                put(MediaStore.Audio.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Audio.Media.MIME_TYPE, mimeType)
                put(MediaStore.Audio.Media.RELATIVE_PATH, relativePath)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.Audio.Media.IS_PENDING, 1)
                }
            }

            val uri = context.contentResolver.insert(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                values
            )

            if (uri != null) {
                context.contentResolver.openOutputStream(uri)?.use { outputStream ->
                    outputStream.write(bytes)
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    values.clear()
                    values.put(MediaStore.Audio.Media.IS_PENDING, 0)
                    context.contentResolver.update(uri, values, null, null)
                }

                Log.d(TAG, "MediaStore insert succeeded for $filePath")
                return true
            }
        } catch (e: Exception) {
            Log.e(TAG, "MediaStore insert failed: ${e.message}", e)
        }

        return false
    }

    private fun findMediaStoreUri(filePath: String): Uri? {
        val projection = arrayOf(MediaStore.Audio.Media._ID)
        val selection = "${MediaStore.Audio.Media.DATA} = ?"
        val selectionArgs = arrayOf(filePath)

        context.contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID))
                return Uri.withAppendedPath(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id.toString())
            }
        }
        return null
    }

    private fun getRelativePath(filePath: String): String {
        // Extract relative path from full path
        val musicPath = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC).absolutePath
        val downloadPath = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).absolutePath

        return when {
            filePath.startsWith(musicPath) -> {
                val relative = File(filePath).parentFile?.absolutePath?.removePrefix(musicPath)?.removePrefix("/") ?: ""
                if (relative.isEmpty()) Environment.DIRECTORY_MUSIC else "${Environment.DIRECTORY_MUSIC}/$relative"
            }
            filePath.startsWith(downloadPath) -> {
                val relative = File(filePath).parentFile?.absolutePath?.removePrefix(downloadPath)?.removePrefix("/") ?: ""
                if (relative.isEmpty()) Environment.DIRECTORY_DOWNLOADS else "${Environment.DIRECTORY_DOWNLOADS}/$relative"
            }
            else -> Environment.DIRECTORY_MUSIC
        }
    }

    fun release() {
        scope.cancel()
    }
}
