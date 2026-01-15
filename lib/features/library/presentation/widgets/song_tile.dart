import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/song.dart';
import '../../../../shared/widgets/song_dialogs.dart';
import '../../../player/data/player_provider.dart';
import '../../../youtube/presentation/youtube_upload_screen.dart';
import '../../data/media_scanner.dart';

class SongTile extends ConsumerWidget {
  final Song song;
  final VoidCallback? onTap;
  final bool showAlbumArt;
  final bool isPlaying;

  const SongTile({
    super.key,
    required this.song,
    this.onTap,
    this.showAlbumArt = true,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(currentSongProvider);
    final isCurrentSong = currentSong?.id == song.id;
    final isPlayingNow = ref.watch(isPlayingProvider) && isCurrentSong;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isCurrentSong
            ? AppTheme.primaryColor.withValues(alpha: 0.15)
            : Colors.transparent,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        leading: showAlbumArt ? _buildArtwork(ref, isCurrentSong, isPlayingNow) : null,
        title: Text(
          song.title,
          style: TextStyle(
            color: isCurrentSong ? AppTheme.primaryColor : AppTheme.textPrimary,
            fontWeight: isCurrentSong ? FontWeight.w600 : FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                song.artistDisplay,
                style: TextStyle(
                  color: isCurrentSong
                      ? AppTheme.primaryColor.withValues(alpha: 0.7)
                      : AppTheme.textMuted,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              song.durationFormatted,
              style: TextStyle(
                color: isCurrentSong
                    ? AppTheme.primaryColor.withValues(alpha: 0.7)
                    : AppTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert_rounded,
            color: isCurrentSong ? AppTheme.primaryColor : AppTheme.textMuted,
          ),
          color: AppTheme.darkCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'play_next',
              child: Row(
                children: [
                  Icon(Icons.queue_play_next_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Play Next'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'add_to_queue',
              child: Row(
                children: [
                  Icon(Icons.add_to_queue_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Add to Queue'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'add_to_playlist',
              child: Row(
                children: [
                  Icon(Icons.playlist_add_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Add to Playlist'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit_tags',
              child: Row(
                children: [
                  Icon(Icons.edit_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Edit Tags'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'info',
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Song Info'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'youtube_upload',
              child: Row(
                children: [
                  Icon(Icons.upload_rounded, size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Upload to YouTube', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'youtube_upload') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => YouTubeUploadScreen(song: song),
                ),
              );
            } else {
              handleSongMenuAction(context, ref, song, value);
            }
          },
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildArtwork(WidgetRef ref, bool isCurrentSong, bool isPlayingNow) {
    final artworkAsync = ref.watch(
      artworkProvider((song.albumId ?? song.id, ArtworkType.AUDIO)),
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.3),
                AppTheme.secondaryColor.withValues(alpha: 0.3),
              ],
            ),
          ),
          child: artworkAsync.when(
            data: (bytes) {
              if (bytes != null) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                  ),
                );
              }
              return const Icon(
                Icons.music_note_rounded,
                color: AppTheme.textMuted,
              );
            },
            loading: () => const SizedBox(),
            error: (_, __) => const Icon(
              Icons.music_note_rounded,
              color: AppTheme.textMuted,
            ),
          ),
        ),
        if (isPlayingNow)
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.black.withValues(alpha: 0.5),
            ),
            child: const Icon(
              Icons.equalizer_rounded,
              color: AppTheme.primaryColor,
              size: 24,
            ),
          ),
      ],
    );
  }
}
