import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../features/playlists/data/playlist_repository.dart';
import '../../features/tag_editor/presentation/screens/tag_editor_screen.dart';
import '../../services/audio_handler.dart';
import '../models/song.dart';

/// Show song info dialog
void showSongInfoDialog(BuildContext context, Song song) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.darkCard,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Text(
              'Song Info',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            _buildInfoRow('Title', song.title),
            _buildInfoRow('Artist', song.artistDisplay),
            _buildInfoRow('Album', song.album ?? 'Unknown'),
            _buildInfoRow('Duration', song.durationFormatted),
            if (song.genre != null) _buildInfoRow('Genre', song.genre!),
            if (song.year != null) _buildInfoRow('Year', song.year.toString()),
            if (song.trackNumber != null)
              _buildInfoRow('Track', song.trackNumber.toString()),
            _buildInfoRow('Format', song.fileExtension?.toUpperCase() ?? 'Unknown'),
            if (song.size != null)
              _buildInfoRow('Size', _formatFileSize(song.size!)),
            if (song.path != null) ...[
              const SizedBox(height: 16),
              Text(
                'File Path',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        song.path!,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      color: AppTheme.textMuted,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: song.path!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Path copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}

Widget _buildInfoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    ),
  );
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Show add to playlist dialog
void showAddToPlaylistDialog(BuildContext context, WidgetRef ref, Song song) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.darkCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Consumer(
      builder: (context, ref, child) {
        final playlistsAsync = ref.watch(playlistsProvider);

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Add to Playlist',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showCreatePlaylistDialog(context, ref, song);
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              playlistsAsync.when(
                data: (playlists) {
                  if (playlists.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No playlists yet.\nCreate one to get started!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ),
                    );
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: playlists.map((playlist) {
                      final isInPlaylist = playlist.songIds.contains(song.id);
                      return ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: playlist.isFavorites
                                ? Colors.red.withValues(alpha: 0.2)
                                : AppTheme.primaryColor.withValues(alpha: 0.2),
                          ),
                          child: Icon(
                            playlist.isFavorites
                                ? Icons.favorite_rounded
                                : Icons.queue_music_rounded,
                            color: playlist.isFavorites
                                ? Colors.red
                                : AppTheme.primaryColor,
                          ),
                        ),
                        title: Text(
                          playlist.name,
                          style: const TextStyle(color: AppTheme.textPrimary),
                        ),
                        subtitle: Text(
                          '${playlist.songIds.length} songs',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        trailing: isInPlaylist
                            ? const Icon(Icons.check, color: AppTheme.primaryColor)
                            : null,
                        onTap: () async {
                          final repo = ref.read(playlistRepositoryProvider);
                          if (isInPlaylist) {
                            await repo.removeSongFromPlaylist(playlist.id, song.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Removed from ${playlist.name}'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } else {
                            await repo.addSongToPlaylist(playlist.id, song.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added to ${playlist.name}'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                          ref.invalidate(playlistsProvider);
                          if (context.mounted) Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (_, __) => const Center(
                  child: Text('Failed to load playlists'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    ),
  );
}

void _showCreatePlaylistDialog(BuildContext context, WidgetRef ref, Song song) {
  final nameController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.darkCard,
      title: const Text('New Playlist'),
      content: TextField(
        controller: nameController,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Playlist name',
          border: OutlineInputBorder(),
        ),
        textCapitalization: TextCapitalization.sentences,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final name = nameController.text.trim();
            if (name.isEmpty) return;

            final repo = ref.read(playlistRepositoryProvider);
            final playlist = await repo.createPlaylist(name);
            await repo.addSongToPlaylist(playlist.id, song.id);
            ref.invalidate(playlistsProvider);

            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added to $name'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
          ),
          child: const Text('Create'),
        ),
      ],
    ),
  );
}

/// Share song
void shareSong(BuildContext context, Song song) async {
  final text = '${song.title} by ${song.artistDisplay}';

  try {
    if (song.path != null) {
      // Share the actual file
      await Share.shareXFiles(
        [XFile(song.path!)],
        text: text,
      );
    } else {
      // Just share the text
      await Share.share(text);
    }
  } catch (e) {
    // Fallback to text sharing
    await Share.share(text);
  }
}

/// Show snackbar for queue actions
void showQueueSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
      action: SnackBarAction(
        label: 'VIEW QUEUE',
        onPressed: () {
          // This would open the queue, but we need context from NowPlayingScreen
        },
      ),
    ),
  );
}

/// Handle song menu action
Future<void> handleSongMenuAction(
  BuildContext context,
  WidgetRef ref,
  Song song,
  String action,
) async {
  switch (action) {
    case 'play_next':
      audioHandler.playNext(song);
      showQueueSnackbar(context, '"${song.title}" will play next');
      break;
    case 'add_to_queue':
      audioHandler.addToQueue(song);
      showQueueSnackbar(context, 'Added "${song.title}" to queue');
      break;
    case 'add_to_playlist':
      showAddToPlaylistDialog(context, ref, song);
      break;
    case 'edit_tags':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TagEditorScreen(song: song),
        ),
      );
      break;
    case 'info':
      showSongInfoDialog(context, song);
      break;
    case 'share':
      shareSong(context, song);
      break;
  }
}
