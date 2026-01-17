import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../features/playlists/data/playlist_repository.dart';
import '../../features/tag_editor/presentation/screens/tag_editor_screen.dart';
import '../../features/tag_editor/data/tag_editor_service.dart';
import '../../features/library/data/media_scanner.dart';
import '../../services/audio_handler.dart';
import '../../services/genre_classifier_service.dart';
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
    builder: (context) => _SongInfoSheet(song: song),
  );
}

class _SongInfoSheet extends ConsumerStatefulWidget {
  final Song song;

  const _SongInfoSheet({required this.song});

  @override
  ConsumerState<_SongInfoSheet> createState() => _SongInfoSheetState();
}

class _SongInfoSheetState extends ConsumerState<_SongInfoSheet> {
  bool _isDetectingGenre = false;
  bool _isApplyingGenre = false;
  GenreClassificationResult? _detectedGenre;
  String? _actualGenre; // Genre read directly from file
  bool _isLoadingGenre = true;

  @override
  void initState() {
    super.initState();
    _loadActualGenre();
  }

  Future<void> _loadActualGenre() async {
    if (widget.song.path == null) {
      setState(() {
        _isLoadingGenre = false;
        _actualGenre = widget.song.genre;
      });
      return;
    }

    try {
      final tagService = TagEditorService();
      if (tagService.isFormatSupported(widget.song.path)) {
        final tags = await tagService.readTags(widget.song.path!);
        if (mounted) {
          setState(() {
            _actualGenre = tags?.genre ?? widget.song.genre;
            _isLoadingGenre = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _actualGenre = widget.song.genre;
            _isLoadingGenre = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _actualGenre = widget.song.genre;
          _isLoadingGenre = false;
        });
      }
    }
  }

  Future<void> _detectGenre() async {
    if (_isDetectingGenre || widget.song.path == null) return;

    setState(() => _isDetectingGenre = true);

    try {
      final classifier = GenreClassifierService();
      final result = await classifier.classifySong(widget.song);

      if (mounted) {
        setState(() {
          _detectedGenre = result;
          _isDetectingGenre = false;
        });

        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Detected: ${result.genre} (${(result.confidence * 100).toStringAsFixed(0)}%${result.isHeuristic ? ' - heuristic' : ''})',
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDetectingGenre = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Genre detection failed')),
        );
      }
    }
  }

  Future<void> _applyGenre(String genre) async {
    if (_isApplyingGenre) return;

    setState(() => _isApplyingGenre = true);

    try {
      final scanner = ref.read(mediaScannerProvider);
      final success = await GenreClassifierService.applyGenreToSong(
        widget.song,
        genre,
        scanner: scanner,
      );

      if (mounted) {
        setState(() => _isApplyingGenre = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Genre "$genre" applied to ${widget.song.title}'
                  : 'Failed to apply genre (MP3 files only)',
            ),
            duration: const Duration(seconds: 3),
          ),
        );

        if (success) {
          // Refresh the library to show updated genre
          ref.invalidate(songsProvider);
          // Update the displayed genre
          setState(() {
            _actualGenre = genre;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isApplyingGenre = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to apply genre')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
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

            // Genre row with detect button
            _buildGenreRow(song),

            if (song.year != null) _buildInfoRow('Year', song.year.toString()),
            if (song.trackNumber != null)
              _buildInfoRow('Track', song.trackNumber.toString()),
            _buildInfoRow('Format', song.fileExtension?.toUpperCase() ?? 'Unknown'),
            if (song.size != null)
              _buildInfoRow('Size', _formatFileSize(song.size!)),

            // ML detected genre section
            if (_detectedGenre != null) ...[
              const SizedBox(height: 16),
              _buildDetectedGenreSection(),
            ],

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
    );
  }

  Widget _buildGenreRow(Song song) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 80,
            child: Text(
              'Genre',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: _isLoadingGenre
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _actualGenre ?? 'Unknown',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                    ),
                  ),
          ),
          if (song.path != null)
            _isDetectingGenre
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.auto_awesome, size: 20),
                    color: AppTheme.primaryColor,
                    tooltip: 'Detect genre with AI',
                    onPressed: _detectGenre,
                  ),
        ],
      ),
    );
  }

  Widget _buildDetectedGenreSection() {
    final result = _detectedGenre!;
    final topGenres = result.topPredictions(3);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AppTheme.primaryColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'AI Genre Detection',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (result.isHeuristic) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Heuristic',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ...topGenres.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      color: entry.key == result.genre
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                      fontWeight: entry.key == result.genre
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                Expanded(
                  child: LinearProgressIndicator(
                    value: entry.value,
                    backgroundColor: AppTheme.darkSurface,
                    valueColor: AlwaysStoppedAnimation(
                      entry.key == result.genre
                          ? AppTheme.primaryColor
                          : AppTheme.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${(entry.value * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 12),
          // Apply button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isApplyingGenre ? null : () => _applyGenre(result.genre),
              icon: _isApplyingGenre
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save, size: 18),
              label: Text(_isApplyingGenre ? 'Applying...' : 'Apply "${result.genre}" to song'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
