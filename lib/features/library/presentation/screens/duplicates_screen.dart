import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/song.dart';
import '../../data/duplicate_finder.dart';
import '../../data/file_deletion_service.dart';
import '../../data/media_scanner.dart';
import '../../../../services/log_service.dart';

class DuplicatesScreen extends ConsumerStatefulWidget {
  final List<Song> songs;

  const DuplicatesScreen({super.key, required this.songs});

  @override
  ConsumerState<DuplicatesScreen> createState() => _DuplicatesScreenState();
}

class _DuplicatesScreenState extends ConsumerState<DuplicatesScreen> {
  List<DuplicateGroup> _duplicateGroups = [];
  final Set<String> _selectedForDeletion = {};
  bool _isLoading = true;
  String _scanStatus = 'Scanning files...';

  @override
  void initState() {
    super.initState();
    _findDuplicates();
  }

  Future<void> _findDuplicates() async {
    Log.d('DuplicateFinder: Starting scan of ${widget.songs.length} songs');

    // Always use filesystem to get accurate file sizes
    final Map<int, List<Song>> sizeGroups = {};

    for (int i = 0; i < widget.songs.length; i++) {
      final song = widget.songs[i];

      if (!mounted) return;

      // Update progress every 10 songs
      if (i % 10 == 0) {
        setState(() {
          _scanStatus = 'Scanning ${i + 1}/${widget.songs.length}...';
        });
        // Yield to UI thread
        await Future.delayed(Duration.zero);
      }

      if (song.path == null) continue;

      try {
        final file = File(song.path!);
        if (await file.exists()) {
          final size = await file.length();
          if (size > 0) {
            sizeGroups.putIfAbsent(size, () => []).add(song);
          }
        }
      } catch (e) {
        Log.d('Error getting size for ${song.path}: $e');
      }
    }

    // Filter to only groups with 2+ songs (actual duplicates)
    final groups = sizeGroups.entries
        .where((e) => e.value.length > 1)
        .map((e) => DuplicateGroup(fileSize: e.key, songs: e.value))
        .toList()
      ..sort((a, b) => b.fileSize.compareTo(a.fileSize));

    Log.d('DuplicateFinder: Found ${groups.length} duplicate groups');

    if (!mounted) return;

    setState(() {
      _duplicateGroups = groups;
      _isLoading = false;

      // Auto-select all but first song in each group for deletion
      for (final group in _duplicateGroups) {
        for (int i = 1; i < group.songs.length; i++) {
          if (group.songs[i].path != null) {
            _selectedForDeletion.add(group.songs[i].path!);
          }
        }
      }
    });
  }

  void _toggleSelection(Song song) {
    if (song.path == null) return;
    setState(() {
      if (_selectedForDeletion.contains(song.path)) {
        _selectedForDeletion.remove(song.path);
      } else {
        _selectedForDeletion.add(song.path!);
      }
    });
  }

  int get _totalDuplicateFiles {
    return _duplicateGroups.fold(0, (sum, g) => sum + g.songs.length);
  }

  int get _totalPotentialSavings {
    int savings = 0;
    for (final group in _duplicateGroups) {
      // Count selected files in this group
      int selectedCount = 0;
      for (final song in group.songs) {
        if (song.path != null && _selectedForDeletion.contains(song.path)) {
          selectedCount++;
        }
      }
      savings += group.fileSize * selectedCount;
    }
    return savings;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  String _getDirectory(String? path) {
    if (path == null) return '';
    final lastSlash = path.lastIndexOf('/');
    if (lastSlash == -1) return '';
    return path.substring(0, lastSlash);
  }

  Future<void> _confirmAndDelete() async {
    if (_selectedForDeletion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No files selected for deletion')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Delete Duplicates?'),
        content: Text(
          'This will permanently delete ${_selectedForDeletion.length} files.\n\n'
          'Space to be freed: ${_formatBytes(_totalPotentialSavings)}\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _performDeletion();
    }
  }

  Future<void> _performDeletion() async {
    // Get songs to delete
    final songsToDelete = <Song>[];
    for (final group in _duplicateGroups) {
      for (final song in group.songs) {
        if (song.path != null && _selectedForDeletion.contains(song.path)) {
          songsToDelete.add(song);
        }
      }
    }

    if (songsToDelete.isEmpty) return;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DeletionProgressDialog(
        songs: songsToDelete,
        onComplete: (deleted, failed) {
          // Refresh the songs list
          ref.invalidate(songsProvider);

          // Show result and pop back
          if (mounted) {
            Navigator.pop(context); // Close progress dialog
            Navigator.pop(context); // Return to songs list

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Deleted $deleted files${failed > 0 ? ', $failed failed' : ''}. '
                  'Freed ${_formatBytes(_totalPotentialSavings)}',
                ),
                backgroundColor: failed > 0 ? Colors.orange : Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Remove Duplicates'),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppTheme.primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    _scanStatus,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.songs.length} songs total',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            )
          : _duplicateGroups.isEmpty
              ? _buildEmptyState()
              : _buildDuplicatesList(),
      floatingActionButton: _duplicateGroups.isNotEmpty && _selectedForDeletion.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _confirmAndDelete,
              backgroundColor: Colors.red,
              icon: const Icon(Icons.delete_rounded, color: Colors.white),
              label: Text(
                'Delete ${_selectedForDeletion.length}',
                style: const TextStyle(color: Colors.white),
              ),
            ).animate().scale(delay: 300.ms)
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.withValues(alpha: 0.2),
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 48,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Duplicates Found',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Your music library is clean!',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ).animate().fadeIn(),
    );
  }

  Widget _buildDuplicatesList() {
    return Column(
      children: [
        // Summary header
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.darkSurface,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_duplicateGroups.length} duplicate groups',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_selectedForDeletion.length} files selected (${_formatBytes(_totalPotentialSavings)})',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selectedForDeletion.length == _totalDuplicateFiles - _duplicateGroups.length) {
                      // All duplicates selected, deselect all
                      _selectedForDeletion.clear();
                    } else {
                      // Select all duplicates (skip first in each group)
                      _selectedForDeletion.clear();
                      for (final group in _duplicateGroups) {
                        for (int i = 1; i < group.songs.length; i++) {
                          if (group.songs[i].path != null) {
                            _selectedForDeletion.add(group.songs[i].path!);
                          }
                        }
                      }
                    }
                  });
                },
                child: Text(
                  _selectedForDeletion.isEmpty ? 'Select All' : 'Deselect All',
                ),
              ),
            ],
          ),
        ),
        // Duplicate groups list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: _duplicateGroups.length,
            itemBuilder: (context, index) {
              return _buildDuplicateGroupCard(_duplicateGroups[index], index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDuplicateGroupCard(DuplicateGroup group, int groupIndex) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.darkCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.file_copy_rounded,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${group.formattedSize} - ${group.totalCount} copies',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Save ${group.formattedSavings}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Songs in group
          ...group.songs.asMap().entries.map((entry) {
            final index = entry.key;
            final song = entry.value;
            final isSelected = song.path != null && _selectedForDeletion.contains(song.path);
            final isFirst = index == 0;

            return InkWell(
              onTap: () => _toggleSelection(song),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    top: index > 0
                        ? BorderSide(color: AppTheme.darkSurface, width: 1)
                        : BorderSide.none,
                  ),
                ),
                child: Row(
                  children: [
                    // Checkbox
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.red : AppTheme.textMuted,
                          width: 2,
                        ),
                        color: isSelected ? Colors.red : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(Icons.close, size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    // Song info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isFirst)
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'KEEP',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  song.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? AppTheme.textMuted
                                        : AppTheme.textPrimary,
                                    decoration: isSelected
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            song.artist ?? 'Unknown Artist',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                              decoration: isSelected
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getDirectory(song.path),
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.textMuted.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    ).animate(delay: (50 * groupIndex).ms).fadeIn().slideX(begin: 0.1);
  }
}

/// Progress dialog for batch deletion
class _DeletionProgressDialog extends ConsumerStatefulWidget {
  final List<Song> songs;
  final void Function(int deleted, int failed) onComplete;

  const _DeletionProgressDialog({
    required this.songs,
    required this.onComplete,
  });

  @override
  ConsumerState<_DeletionProgressDialog> createState() => _DeletionProgressDialogState();
}

class _DeletionProgressDialogState extends ConsumerState<_DeletionProgressDialog> {
  int _processed = 0;
  int _deleted = 0;
  int _failed = 0;
  String _currentFile = '';
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _performDeletion();
  }

  Future<void> _performDeletion() async {
    final deletionService = ref.read(fileDeletionServiceProvider);

    await for (final progress in deletionService.deleteMultiple(widget.songs)) {
      if (!mounted) break;

      setState(() {
        _processed = progress.current;
        _deleted = progress.deleted;
        _failed = progress.failed;
        _currentFile = progress.currentFile;
      });
    }

    // Invalidate cache to refresh library
    ref.read(mediaScannerProvider).invalidateCache();

    setState(() => _isComplete = true);

    // Small delay before completing
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      widget.onComplete(_deleted, _failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.songs.isEmpty ? 1.0 : _processed / widget.songs.length;

    return AlertDialog(
      backgroundColor: AppTheme.darkCard,
      title: Text(_isComplete ? 'Complete' : 'Deleting Files...'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppTheme.darkSurface,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
          ),
          const SizedBox(height: 16),
          Text(
            '$_processed / ${widget.songs.length} files processed',
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
              'Deleted $_deleted files${_failed > 0 ? ', $_failed failed' : ''}',
              style: TextStyle(
                color: _failed > 0 ? Colors.orange : Colors.green,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
