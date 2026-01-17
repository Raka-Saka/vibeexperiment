import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/song.dart';
import '../../../../shared/widgets/song_dialogs.dart';
import '../../../../services/play_statistics_service.dart';
import '../../../player/data/player_provider.dart';
import '../../../youtube/presentation/youtube_upload_screen.dart';
import '../../data/media_scanner.dart';
import '../../data/file_deletion_service.dart';

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
            // Play count indicator
            _buildPlayCountBadge(isCurrentSong),
            const SizedBox(width: 8),
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
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Delete from Device', style: TextStyle(color: Colors.red)),
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
            } else if (value == 'delete') {
              _showDeleteConfirmation(context, ref, song);
            } else {
              handleSongMenuAction(context, ref, song, value);
            }
          },
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildPlayCountBadge(bool isCurrentSong) {
    final stats = playStatisticsService.getSongStats(song.id);
    if (stats == null || stats.playCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isCurrentSong
            ? AppTheme.primaryColor.withValues(alpha: 0.2)
            : AppTheme.darkCard,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_arrow_rounded,
            size: 10,
            color: isCurrentSong ? AppTheme.primaryColor : AppTheme.textMuted,
          ),
          const SizedBox(width: 2),
          Text(
            '${stats.playCount}',
            style: TextStyle(
              color: isCurrentSong ? AppTheme.primaryColor : AppTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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

void _showDeleteConfirmation(BuildContext context, WidgetRef ref, Song song) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.darkCard,
      title: const Text('Delete Song'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Are you sure you want to delete this song from your device?'),
          const SizedBox(height: 12),
          Text(
            song.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            song.artistDisplay,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Text(
            'This action cannot be undone.',
            style: TextStyle(color: Colors.red.shade300, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            Navigator.pop(context);
            final deletionService = ref.read(fileDeletionServiceProvider);
            final result = await deletionService.deleteSong(song);

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result.success
                        ? '${song.title} deleted'
                        : 'Failed to delete: ${result.error}',
                  ),
                  duration: const Duration(seconds: 3),
                ),
              );

              if (result.success) {
                // Refresh the library
                ref.invalidate(songsProvider);
              }
            }
          },
          icon: const Icon(Icons.delete, size: 18),
          label: const Text('Delete'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),
  );
}
