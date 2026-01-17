import 'package:flutter/services.dart';
import 'log_service.dart';
import '../shared/models/song.dart';
import '../features/tag_editor/data/tag_editor_service.dart';
import '../features/library/data/media_scanner.dart';

/// Result of genre classification for a song
class GenreClassificationResult {
  final String genre;
  final double confidence;
  final Map<String, double> probabilities;
  final bool isHeuristic;

  GenreClassificationResult({
    required this.genre,
    required this.confidence,
    required this.probabilities,
    this.isHeuristic = false,
  });

  factory GenreClassificationResult.fromMap(Map<dynamic, dynamic> map) {
    return GenreClassificationResult(
      genre: map['genre'] as String,
      confidence: (map['confidence'] as num).toDouble(),
      probabilities: (map['probabilities'] as Map).map(
        (k, v) => MapEntry(k as String, (v as num).toDouble()),
      ),
      isHeuristic: map['isHeuristic'] as bool? ?? false,
    );
  }

  /// Get top N genre predictions
  List<MapEntry<String, double>> topPredictions(int n) {
    final sorted = probabilities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).toList();
  }

  @override
  String toString() {
    return 'GenreClassificationResult(genre: $genre, confidence: ${(confidence * 100).toStringAsFixed(1)}%, heuristic: $isHeuristic)';
  }
}

/// Batch classification result
class BatchClassificationResult {
  final String path;
  final GenreClassificationResult? result;
  final String? error;

  BatchClassificationResult({
    required this.path,
    this.result,
    this.error,
  });

  bool get isSuccess => result != null;
}

/// Service for on-device ML genre classification
class GenreClassifierService {
  static final GenreClassifierService _instance = GenreClassifierService._internal();
  factory GenreClassifierService() => _instance;
  GenreClassifierService._internal();

  static const _channel = MethodChannel('com.vibeplay/genre_classifier');

  bool _isInitialized = false;
  bool _hasModel = false;
  List<String> _genres = [];

  /// Whether the service is initialized
  bool get isInitialized => _isInitialized;

  /// Whether a TFLite model is available (vs heuristic fallback)
  bool get hasModel => _hasModel;

  /// List of supported genres
  List<String> get genres => _genres;

  /// Initialize the genre classifier
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      final result = await _channel.invokeMethod('initialize');
      if (result != null) {
        _isInitialized = true;
        _hasModel = result['hasModel'] as bool? ?? false;
        _genres = List<String>.from(result['genres'] as List? ?? []);

        Log.audio.d('GenreClassifier: Initialized, hasModel=$_hasModel, genres=${_genres.length}');
        return result['success'] as bool? ?? false;
      }
      return false;
    } on PlatformException catch (e) {
      Log.audio.d('GenreClassifier: Init failed: ${e.message}');
      return false;
    }
  }

  /// Classify a single audio file
  Future<GenreClassificationResult?> classifyFile(String filePath) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final result = await _channel.invokeMethod('classifyFile', {
        'path': filePath,
      });

      if (result != null) {
        return GenreClassificationResult.fromMap(result as Map);
      }
      return null;
    } on PlatformException catch (e) {
      Log.audio.d('GenreClassifier: Classification failed: ${e.message}');
      return null;
    }
  }

  /// Classify a Song object
  Future<GenreClassificationResult?> classifySong(Song song) async {
    if (song.path == null) return null;
    return classifyFile(song.path!);
  }

  /// Classify multiple files in batch
  Future<List<BatchClassificationResult>> classifyBatch(List<String> filePaths) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final results = await _channel.invokeMethod('classifyBatch', {
        'paths': filePaths,
      });

      if (results != null) {
        return (results as List).map((item) {
          final map = item as Map;
          final path = map['path'] as String;

          if (map['genre'] != null) {
            return BatchClassificationResult(
              path: path,
              result: GenreClassificationResult.fromMap(map),
            );
          } else {
            return BatchClassificationResult(
              path: path,
              error: map['error'] as String? ?? 'Unknown error',
            );
          }
        }).toList();
      }
      return [];
    } on PlatformException catch (e) {
      Log.audio.d('GenreClassifier: Batch classification failed: ${e.message}');
      return [];
    }
  }

  /// Classify multiple songs
  Future<Map<Song, GenreClassificationResult?>> classifySongs(List<Song> songs) async {
    final paths = songs
        .where((s) => s.path != null)
        .map((s) => s.path!)
        .toList();

    final results = await classifyBatch(paths);

    final songResults = <Song, GenreClassificationResult?>{};
    for (final song in songs) {
      if (song.path != null) {
        final batchResult = results.firstWhere(
          (r) => r.path == song.path,
          orElse: () => BatchClassificationResult(path: song.path!, error: 'Not found'),
        );
        songResults[song] = batchResult.result;
      } else {
        songResults[song] = null;
      }
    }

    return songResults;
  }

  /// Get available genres
  Future<List<String>> getGenres() async {
    if (_genres.isNotEmpty) return _genres;

    try {
      final result = await _channel.invokeMethod('getGenres');
      if (result != null) {
        _genres = List<String>.from(result as List);
      }
      return _genres;
    } on PlatformException catch (e) {
      Log.audio.d('GenreClassifier: Get genres failed: ${e.message}');
      return [];
    }
  }

  /// Apply a genre to a song's metadata (MP3 only)
  /// Returns true if successful
  static Future<bool> applyGenreToSong(Song song, String genre, {MediaScanner? scanner}) async {
    if (song.path == null) return false;

    try {
      final tagService = TagEditorService();

      // Check if format is supported
      if (!tagService.isFormatSupported(song.path)) {
        Log.audio.d('GenreClassifier: Format not supported for ${song.path}');
        return false;
      }

      // Read existing tags
      final existingTags = await tagService.readTags(song.path!);
      if (existingTags == null) {
        Log.audio.d('GenreClassifier: Could not read tags from ${song.path}');
        return false;
      }

      // Update genre
      final updatedTags = existingTags.copyWith(genre: genre);

      // Write back
      final result = await tagService.writeTags(song.path!, updatedTags);

      if (result.success) {
        Log.audio.d('GenreClassifier: Applied genre "$genre" to ${song.title}');

        // Rescan the file to update MediaStore
        if (scanner != null) {
          await scanner.rescanFile(song.path!);
          Log.audio.d('GenreClassifier: Rescanned ${song.path} in MediaStore');
        }

        return true;
      } else {
        Log.audio.d('GenreClassifier: Failed to write genre: ${result.error}');
        return false;
      }
    } catch (e) {
      Log.audio.d('GenreClassifier: Failed to apply genre: $e');
      return false;
    }
  }
}
