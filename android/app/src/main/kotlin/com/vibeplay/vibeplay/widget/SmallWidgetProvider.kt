package com.vibeplay.vibeplay.widget

import android.content.Context
import android.widget.RemoteViews
import com.vibeplay.vibeplay.R

class SmallWidgetProvider : VibePlayWidgetProvider() {

    override fun getLayoutId(): Int = R.layout.widget_small

    override fun updateViews(
        context: Context,
        views: RemoteViews,
        title: String,
        artist: String,
        isPlaying: Boolean,
        artworkPath: String?
    ) {
        // Update play/pause button icon
        val playPauseIcon = if (isPlaying) {
            R.drawable.ic_widget_pause
        } else {
            R.drawable.ic_widget_play
        }
        views.setImageViewResource(R.id.btn_play_pause, playPauseIcon)
    }

    override fun setupClickHandlers(context: Context, views: RemoteViews) {
        views.setOnClickPendingIntent(
            R.id.btn_play_pause,
            createPendingIntent(context, ACTION_PLAY_PAUSE)
        )
        views.setOnClickPendingIntent(
            R.id.btn_next,
            createPendingIntent(context, ACTION_NEXT)
        )
        // Tapping widget background opens app
        views.setOnClickPendingIntent(
            R.id.widget_container,
            createPendingIntent(context, ACTION_OPEN_APP)
        )
    }
}
