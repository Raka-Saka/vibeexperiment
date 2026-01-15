package com.vibeplay.vibeplay.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class WidgetHandler(private val context: Context) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "updateWidget" -> {
                val title = call.argument<String>("title") ?: "No song playing"
                val artist = call.argument<String>("artist") ?: ""
                val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                val artworkPath = call.argument<String>("artworkPath")

                updateWidgetData(title, artist, isPlaying, artworkPath)
                result.success(true)
            }
            "updatePlayingState" -> {
                val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                updatePlayingState(isPlaying)
                result.success(true)
            }
            "clearWidget" -> {
                clearWidgetData()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun updateWidgetData(title: String, artist: String, isPlaying: Boolean, artworkPath: String?) {
        val prefs = VibePlayWidgetProvider.getWidgetPrefs(context)
        prefs.edit().apply {
            putString(VibePlayWidgetProvider.KEY_SONG_TITLE, title)
            putString(VibePlayWidgetProvider.KEY_SONG_ARTIST, artist)
            putBoolean(VibePlayWidgetProvider.KEY_IS_PLAYING, isPlaying)
            putString(VibePlayWidgetProvider.KEY_ARTWORK_PATH, artworkPath)
            apply()
        }

        // Update all widgets
        updateAllWidgets()
    }

    private fun updatePlayingState(isPlaying: Boolean) {
        val prefs = VibePlayWidgetProvider.getWidgetPrefs(context)
        prefs.edit().apply {
            putBoolean(VibePlayWidgetProvider.KEY_IS_PLAYING, isPlaying)
            apply()
        }

        // Update all widgets
        updateAllWidgets()
    }

    private fun clearWidgetData() {
        val prefs = VibePlayWidgetProvider.getWidgetPrefs(context)
        prefs.edit().apply {
            putString(VibePlayWidgetProvider.KEY_SONG_TITLE, "No song playing")
            putString(VibePlayWidgetProvider.KEY_SONG_ARTIST, "")
            putBoolean(VibePlayWidgetProvider.KEY_IS_PLAYING, false)
            putString(VibePlayWidgetProvider.KEY_ARTWORK_PATH, null)
            apply()
        }

        // Update all widgets
        updateAllWidgets()
    }

    private fun updateAllWidgets() {
        val appWidgetManager = AppWidgetManager.getInstance(context)

        // Update small widgets
        val smallComponent = ComponentName(context, SmallWidgetProvider::class.java)
        val smallIds = appWidgetManager.getAppWidgetIds(smallComponent)
        if (smallIds.isNotEmpty()) {
            SmallWidgetProvider().onUpdate(context, appWidgetManager, smallIds)
        }

        // Update medium widgets
        val mediumComponent = ComponentName(context, MediumWidgetProvider::class.java)
        val mediumIds = appWidgetManager.getAppWidgetIds(mediumComponent)
        if (mediumIds.isNotEmpty()) {
            MediumWidgetProvider().onUpdate(context, appWidgetManager, mediumIds)
        }
    }
}
