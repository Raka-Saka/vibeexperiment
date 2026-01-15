import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/song.dart';
import '../../../player/data/player_provider.dart';
import '../../../tag_editor/data/tag_editor_service.dart';
import '../../../tag_editor/presentation/screens/batch_find_replace_screen.dart';
import '../../data/media_scanner.dart';
import 'duplicates_screen.dart';
import '../widgets/song_tile.dart';

class SongsScreen extends ConsumerWidget {
  const SongsScreen({super.key});

  void _showRemoveUrlsDialog(BuildContext context, WidgetRef ref, List<Song> songs) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Remove URL Tags'),
        content: Text(
          'This will remove URL frames (like WOAS, WOAR) from all ${songs.length} songs.\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _removeUrlsFromAllSongs(context, ref, songs);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove URLs'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeUrlsFromAllSongs(BuildContext context, WidgetRef ref, List<Song> songs) async {
    final tagService = ref.read(tagEditorServiceProvider);
    final scanner = ref.read(mediaScannerProvider);

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _RemoveUrlsProgressDialog(
        songs: songs,
        tagService: tagService,
        scanner: scanner,
        onComplete: () {
          ref.invalidate(songsProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(songsProvider);

    return songsAsync.when(
      data: (songs) {
        if (songs.isEmpty) {
          return _buildEmptyState(context, ref);
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(songsProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: songs.length + 1, // +1 for header
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildHeader(context, ref, songs);
              }

              final song = songs[index - 1];
              return SongTile(
                song: song,
                onTap: () async {
                  final playerNotifier = ref.read(playerProvider.notifier);
                  await playerNotifier.playSong(song, songs);
                },
              ).animate(delay: (50 * (index % 10)).ms)
                  .fadeIn(duration: 300.ms)
                  .slideX(begin: 0.1);
            },
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryColor,
        ),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load songs',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(songsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, List<Song> songs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${songs.length} Songs',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                ),
              ),
              // Shuffle button stays in header
              GestureDetector(
                onTap: () async {
                  final playerNotifier = ref.read(playerProvider.notifier);
                  final shuffled = List.of(songs)..shuffle();
                  if (shuffled.isNotEmpty) {
                    await playerNotifier.playSong(shuffled.first, shuffled);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor.withValues(alpha:0.2),
                        AppTheme.secondaryColor.withValues(alpha:0.2),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shuffle_rounded,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Shuffle',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Tools row - scrollable
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Remove URLs button
                GestureDetector(
                  onTap: () => _showRemoveUrlsDialog(context, ref, songs),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: AppTheme.darkCard,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.link_off_rounded,
                          size: 14,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Remove URLs',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Find & Replace button
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BatchFindReplaceScreen(songs: songs),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: AppTheme.darkCard,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.find_replace_rounded,
                          size: 14,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Find & Replace',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Duplicates button
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DuplicatesScreen(songs: songs),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: AppTheme.darkCard,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.file_copy_outlined,
                          size: 14,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Duplicates',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2);
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withValues(alpha:0.2),
                  AppTheme.secondaryColor.withValues(alpha:0.2),
                ],
              ),
            ),
            child: const Icon(
              Icons.music_off_rounded,
              size: 48,
              color: AppTheme.textMuted,
            ),
          ).animate().scale(duration: 500.ms, curve: Curves.easeOut),
          const SizedBox(height: 24),
          Text(
            'No Songs Found',
            style: Theme.of(context).textTheme.headlineMedium,
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 8),
          Text(
            'Grant storage permission to scan\nyour music library',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              final scanner = ref.read(mediaScannerProvider);
              await scanner.requestPermission();
              ref.invalidate(songsProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Grant Permission & Scan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ).animate().fadeIn(delay: 400.ms).scale(),
        ],
      ),
    );
  }
}

/// Progress dialog for removing URLs from all songs
class _RemoveUrlsProgressDialog extends StatefulWidget {
  final List<Song> songs;
  final TagEditorService tagService;
  final MediaScanner scanner;
  final VoidCallback onComplete;

  const _RemoveUrlsProgressDialog({
    required this.songs,
    required this.tagService,
    required this.scanner,
    required this.onComplete,
  });

  @override
  State<_RemoveUrlsProgressDialog> createState() => _RemoveUrlsProgressDialogState();
}

class _RemoveUrlsProgressDialogState extends State<_RemoveUrlsProgressDialog> {
  int _processed = 0;
  int _removed = 0;
  bool _isComplete = false;
  String _currentFile = '';

  @override
  void initState() {
    super.initState();
    _processFiles();
  }

  Future<void> _processFiles() async {
    for (final song in widget.songs) {
      if (!mounted) break;

      if (song.path == null) {
        setState(() => _processed++);
        continue;
      }

      setState(() {
        _currentFile = song.title;
      });

      final result = await widget.tagService.removeUrlFrames(song.path!);
      if (result.success && result.error == null) {
        _removed++;
        // Rescan file
        await widget.scanner.rescanFile(song.path!);
      }

      setState(() => _processed++);
    }

    widget.onComplete();
    setState(() => _isComplete = true);
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.songs.isEmpty ? 1.0 : _processed / widget.songs.length;

    return AlertDialog(
      backgroundColor: AppTheme.darkCard,
      title: Text(_isComplete ? 'Complete' : 'Removing URLs...'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppTheme.darkSurface,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            '$_processed / ${widget.songs.length} songs processed',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          if (!_isComplete && _currentFile.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _currentFile,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (_isComplete) ...[
            const SizedBox(height: 8),
            Text(
              'Removed URLs from $_removed songs',
              style: const TextStyle(color: Colors.green),
            ),
          ],
        ],
      ),
      actions: _isComplete
          ? [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ]
          : null,
    );
  }
}
