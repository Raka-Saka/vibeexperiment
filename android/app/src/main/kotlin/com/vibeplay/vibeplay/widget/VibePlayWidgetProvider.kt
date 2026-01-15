package com.vibeplay.vibeplay.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.view.KeyEvent
import android.widget.RemoteViews
import java.io.File

abstract class VibePlayWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_PLAY_PAUSE = "com.vibeplay.vibeplay.WIDGET_PLAY_PAUSE"
        const val ACTION_NEXT = "com.vibeplay.vibeplay.WIDGET_NEXT"
        const val ACTION_PREV = "com.vibeplay.vibeplay.WIDGET_PREV"
        const val ACTION_OPEN_APP = "com.vibeplay.vibeplay.WIDGET_OPEN_APP"

        // Shared preference keys
        const val PREFS_NAME = "vibeplay_widget_prefs"
        const val KEY_SONG_TITLE = "widget_song_title"
        const val KEY_SONG_ARTIST = "widget_song_artist"
        const val KEY_IS_PLAYING = "widget_is_playing"
        const val KEY_ARTWORK_PATH = "widget_artwork_path"

        fun getWidgetPrefs(context: Context): SharedPreferences {
            return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        }
    }

    abstract fun getLayoutId(): Int

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        when (intent.action) {
            ACTION_PLAY_PAUSE -> sendCommandToApp(context, "togglePlayPause")
            ACTION_NEXT -> sendCommandToApp(context, "skipToNext")
            ACTION_PREV -> sendCommandToApp(context, "skipToPrevious")
            ACTION_OPEN_APP -> openApp(context)
        }
    }

    protected fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val prefs = getWidgetPrefs(context)
        val views = RemoteViews(context.packageName, getLayoutId())

        // Get data from shared preferences
        val title = prefs.getString(KEY_SONG_TITLE, "No song playing") ?: "No song playing"
        val artist = prefs.getString(KEY_SONG_ARTIST, "") ?: ""
        val isPlaying = prefs.getBoolean(KEY_IS_PLAYING, false)
        val artworkPath = prefs.getString(KEY_ARTWORK_PATH, null)

        // Update views (subclasses implement specific updates)
        updateViews(context, views, title, artist, isPlaying, artworkPath)

        // Set click handlers
        setupClickHandlers(context, views)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    protected abstract fun updateViews(
        context: Context,
        views: RemoteViews,
        title: String,
        artist: String,
        isPlaying: Boolean,
        artworkPath: String?
    )

    protected abstract fun setupClickHandlers(context: Context, views: RemoteViews)

    protected fun createPendingIntent(context: Context, action: String): PendingIntent {
        val intent = Intent(context, this::class.java).apply {
            this.action = action
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getBroadcast(context, action.hashCode(), intent, flags)
    }

    protected fun loadArtwork(artworkPath: String?): Bitmap? {
        if (artworkPath == null) return null
        return try {
            val file = File(artworkPath)
            if (file.exists()) {
                BitmapFactory.decodeFile(artworkPath)
            } else null
        } catch (e: Exception) {
            null
        }
    }

    private fun sendCommandToApp(context: Context, command: String) {
        // Map command to media key code
        val keyCode = when (command) {
            "togglePlayPause" -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
            "skipToNext" -> KeyEvent.KEYCODE_MEDIA_NEXT
            "skipToPrevious" -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
            else -> return
        }

        // Send media button intent to the MediaButtonReceiver
        val mediaButtonReceiver = ComponentName(
            context,
            "com.ryanheise.audioservice.MediaButtonReceiver"
        )

        // Send key down event
        val downIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            component = mediaButtonReceiver
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        }
        context.sendBroadcast(downIntent)

        // Send key up event
        val upIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            component = mediaButtonReceiver
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_UP, keyCode))
        }
        context.sendBroadcast(upIntent)
    }

    private fun openApp(context: Context) {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    fun updateAllWidgets(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val componentName = ComponentName(context, this::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
        onUpdate(context, appWidgetManager, appWidgetIds)
    }
}
