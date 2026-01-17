import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/genre_classifier_service.dart';
import '../../../../shared/models/song.dart';
import '../../data/media_scanner.dart';

/// Screen for batch genre classification of the music library
class GenreClassifierScreen extends ConsumerStatefulWidget {
  const GenreClassifierScreen({super.key});

  @override
  ConsumerState<GenreClassifierScreen> createState() => _GenreClassifierScreenState();
}

class _GenreClassifierScreenState extends ConsumerState<GenreClassifierScreen> {
  final _classifier = GenreClassifierService();

  bool _isClassifying = false;
  bool _isPaused = false;
  int _processedCount = 0;
  int _totalCount = 0;
  String _currentSong = '';

  final Map<Song, GenreClassificationResult?> _results = {};
  final List<_ClassificationEntry> _recentResults = [];

  // Filter options
  bool _onlyUntagged = true;
  double _minConfidence = 0.3;

  @override
  void initState() {
    super.initState();
    _classifier.initialize();
  }

  Future<void> _startClassification() async {
    final songsAsync = ref.read(songsProvider);
    final songs = songsAsync.valueOrNull ?? [];

    if (songs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No songs found in library')),
      );
      return;
    }

    // Filter songs based on options
    final songsToClassify = _onlyUntagged
        ? songs.where((s) => s.genre == null || s.genre!.isEmpty || s.genre == 'Unknown').toList()
        : songs.toList();

    if (songsToClassify.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All songs already have genres tagged')),
      );
      return;
    }

    setState(() {
      _isClassifying = true;
      _isPaused = false;
      _processedCount = 0;
      _totalCount = songsToClassify.length;
      _results.clear();
      _recentResults.clear();
    });

    for (int i = 0; i < songsToClassify.length; i++) {
      // Check if cancelled or paused
      if (!_isClassifying) break;
      while (_isPaused && _isClassifying) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (!_isClassifying) break;

      final song = songsToClassify[i];

      setState(() {
        _currentSong = song.title;
        _processedCount = i;
      });

      try {
        final result = await _classifier.classifySong(song);

        if (mounted) {
          setState(() {
            _results[song] = result;
            if (result != null) {
              _recentResults.insert(0, _ClassificationEntry(
                song: song,
                result: result,
              ));
              // Keep only last 20 results visible
              if (_recentResults.length > 20) {
                _recentResults.removeLast();
              }
            }
          });
        }
      } catch (e) {
        // Continue on error
      }
    }

    if (mounted) {
      setState(() {
        _isClassifying = false;
        _processedCount = _totalCount;
        _currentSong = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Classification complete: ${_results.length} songs processed'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _pauseClassification() {
    setState(() => _isPaused = !_isPaused);
  }

  void _stopClassification() {
    setState(() {
      _isClassifying = false;
      _isPaused = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songsProvider);
    final totalSongs = songsAsync.valueOrNull?.length ?? 0;
    final untaggedCount = songsAsync.valueOrNull
        ?.where((s) => s.genre == null || s.genre!.isEmpty || s.genre == 'Unknown')
        .length ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text('AI Genre Detection'),
        actions: [
          if (_results.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.save_alt),
              tooltip: 'Export results',
              onPressed: _showExportDialog,
            ),
        ],
      ),
      body: Column(
        children: [
          // Info card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Batch Genre Classification',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Analyze your music library using AI to detect genres. '
                  'Currently using heuristic analysis (ML model coming soon).',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatChip('Total', totalSongs.toString(), Icons.library_music),
                    const SizedBox(width: 12),
                    _buildStatChip('Untagged', untaggedCount.toString(), Icons.help_outline),
                  ],
                ),
              ],
            ),
          ),

          // Options
          if (!_isClassifying) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Only untagged toggle
                  SwitchListTile(
                    title: const Text('Only songs without genre'),
                    subtitle: Text('$untaggedCount songs'),
                    value: _onlyUntagged,
                    onChanged: (v) => setState(() => _onlyUntagged = v),
                    activeColor: AppTheme.primaryColor,
                    contentPadding: EdgeInsets.zero,
                  ),

                  // Confidence threshold
                  ListTile(
                    title: const Text('Minimum confidence'),
                    subtitle: Text('${(_minConfidence * 100).toInt()}%'),
                    trailing: SizedBox(
                      width: 150,
                      child: Slider(
                        value: _minConfidence,
                        min: 0.1,
                        max: 0.9,
                        divisions: 8,
                        onChanged: (v) => setState(() => _minConfidence = v),
                        activeColor: AppTheme.primaryColor,
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ],

          // Progress section
          if (_isClassifying) ...[
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isPaused ? 'Paused' : 'Analyzing...',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$_processedCount / $_totalCount',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _totalCount > 0 ? _processedCount / _totalCount : 0,
                    backgroundColor: AppTheme.darkSurface,
                    valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentSong,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pauseClassification,
                        icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                        label: Text(_isPaused ? 'Resume' : 'Pause'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.darkCard,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _stopClassification,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.withValues(alpha: 0.2),
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Results list
          Expanded(
            child: _recentResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.music_note,
                          size: 64,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isClassifying
                              ? 'Processing songs...'
                              : 'Start classification to see results',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _recentResults.length,
                    itemBuilder: (context, index) {
                      final entry = _recentResults[index];
                      final meetsThreshold = entry.result.confidence >= _minConfidence;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.darkCard,
                          borderRadius: BorderRadius.circular(8),
                          border: meetsThreshold
                              ? Border.all(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.song.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    entry.song.artistDisplay,
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: meetsThreshold
                                        ? AppTheme.primaryColor.withValues(alpha: 0.2)
                                        : AppTheme.textMuted.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    entry.result.genre,
                                    style: TextStyle(
                                      color: meetsThreshold
                                          ? AppTheme.primaryColor
                                          : AppTheme.textMuted,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(entry.result.confidence * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: meetsThreshold
                                        ? AppTheme.textSecondary
                                        : AppTheme.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: !_isClassifying
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _startClassification,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(
                    'Start Classification (${_onlyUntagged ? untaggedCount : totalSongs} songs)',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildStatChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showExportDialog() {
    final highConfidence = _results.entries
        .where((e) => e.value != null && e.value!.confidence >= _minConfidence)
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Classification Results'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total processed: ${_results.length}'),
            Text('Above ${(_minConfidence * 100).toInt()}% confidence: ${highConfidence.length}'),
            const SizedBox(height: 16),
            Text(
              'Apply genres to ${highConfidence.length} songs that meet the confidence threshold?',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: highConfidence.isEmpty
                ? null
                : () {
                    Navigator.pop(context);
                    _applyAllGenres(highConfidence);
                  },
            icon: const Icon(Icons.save, size: 18),
            label: Text('Apply ${highConfidence.length} Genres'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyAllGenres(List<MapEntry<Song, GenreClassificationResult?>> entries) async {
    int successCount = 0;
    int failCount = 0;

    final scanner = ref.read(mediaScannerProvider);

    setState(() {
      _isClassifying = true;
      _processedCount = 0;
      _totalCount = entries.length;
      _currentSong = 'Applying genres...';
    });

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final song = entry.key;
      final result = entry.value;

      if (result == null) continue;

      setState(() {
        _processedCount = i;
        _currentSong = 'Applying: ${song.title}';
      });

      try {
        final success = await GenreClassifierService.applyGenreToSong(
          song,
          result.genre,
          scanner: scanner,
        );
        if (success) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
      }
    }

    if (mounted) {
      setState(() {
        _isClassifying = false;
        _processedCount = _totalCount;
        _currentSong = '';
      });

      // Refresh the library to show updated genres
      ref.invalidate(songsProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Applied genres: $successCount successful, $failCount failed'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}

class _ClassificationEntry {
  final Song song;
  final GenreClassificationResult result;

  _ClassificationEntry({required this.song, required this.result});
}
