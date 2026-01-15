package com.vibeplay.vibeplay.widget

import android.content.Context
import android.widget.RemoteViews
import com.vibeplay.vibeplay.R

class MediumWidgetProvider : VibePlayWidgetProvider() {

    override fun getLayoutId(): Int = R.layout.widget_medium

    override fun updateViews(
        context: Context,
        views: RemoteViews,
        title: String,
        artist: String,
        isPlaying: Boolean,
        artworkPath: String?
    ) {
        // Update text views
        views.setTextViewText(R.id.tv_song_title, title)
        views.setTextViewText(R.id.tv_song_artist, artist)

        // Update play/pause button icon
        val playPauseIcon = if (isPlaying) {
            R.drawable.ic_widget_pause
        } else {
            R.drawable.ic_widget_play
        }
        views.setImageViewResource(R.id.btn_play_pause, playPauseIcon)

        // Update album artwork
        val artwork = loadArtwork(artworkPath)
        if (artwork != null) {
            views.setImageViewBitmap(R.id.iv_album_art, artwork)
        } else {
            views.setImageViewResource(R.id.iv_album_art, R.drawable.ic_widget_album_placeholder)
        }
    }

    override fun setupClickHandlers(context: Context, views: RemoteViews) {
        views.setOnClickPendingIntent(
            R.id.btn_prev,
            createPendingIntent(context, ACTION_PREV)
        )
        views.setOnClickPendingIntent(
            R.id.btn_play_pause,
            createPendingIntent(context, ACTION_PLAY_PAUSE)
        )
        views.setOnClickPendingIntent(
            R.id.btn_next,
            createPendingIntent(context, ACTION_NEXT)
        )
        // Tapping artwork or song info opens app
        views.setOnClickPendingIntent(
            R.id.iv_album_art,
            createPendingIntent(context, ACTION_OPEN_APP)
        )
        views.setOnClickPendingIntent(
            R.id.song_info_container,
            createPendingIntent(context, ACTION_OPEN_APP)
        )
    }
}
