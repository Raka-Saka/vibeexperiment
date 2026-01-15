import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../shared/models/song.dart';
import 'log_service.dart';

/// Cached analysis data for a song
class SongAnalysis {
  final String path;
  final Duration? silenceStart; // When silence/fade begins at end
  final int? bpm;
  final bool isGaplessTrack;
  final DateTime analyzedAt;

  SongAnalysis({
    required this.path,
    this.silenceStart,
    this.bpm,
    this.isGaplessTrack = false,
    DateTime? analyzedAt,
  }) : analyzedAt = analyzedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'path': path,
    'silenceStartMs': silenceStart?.inMilliseconds,
    'bpm': bpm,
    'isGaplessTrack': isGaplessTrack,
    'analyzedAt': analyzedAt.toIso8601String(),
  };

  factory SongAnalysis.fromJson(Map<String, dynamic> json) => SongAnalysis(
    path: json['path'] as String,
    silenceStart: json['silenceStartMs'] != null
        ? Duration(milliseconds: json['silenceStartMs'] as int)
        : null,
    bpm: json['bpm'] as int?,
    isGaplessTrack: json['isGaplessTrack'] as bool? ?? false,
    analyzedAt: json['analyzedAt'] != null
        ? DateTime.parse(json['analyzedAt'] as String)
        : DateTime.now(),
  );
}

/// Service for analyzing audio tracks for smart crossfade
class AudioAnalysisService {
  static const String _boxName = 'audio_analysis';
  static const MethodChannel _channel = MethodChannel('com.vibeplay/audio_analysis');

  Box? _box;
  final Map<String, SongAnalysis> _cache = {};

  // Keywords that indicate live/continuous albums
  static const List<String> _liveAlbumKeywords = [
    'live', 'concert', 'unplugged', 'acoustic live', 'in concert',
    'mtv unplugged', 'live at', 'live from', 'live in',
    'continuous mix', 'dj mix', 'mixed by', 'nonstop',
  ];

  // Keywords for track titles that shouldn't crossfade
  static const List<String> _gaplessTrackKeywords = [
    'intro', 'outro', 'interlude', 'segue', 'medley',
    'part 1', 'part 2', 'pt. 1', 'pt. 2', 'pt.1', 'pt.2',
    'movement', 'mvt.', 'act i', 'act ii',
  ];

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    // Load cached analyses
    final data = _box?.get('analyses') as Map<dynamic, dynamic>?;
    if (data != null) {
      for (final entry in data.entries) {
        try {
          _cache[entry.key as String] = SongAnalysis.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        } catch (e) {
          Log.audio.d('AudioAnalysis: Error loading cached analysis: $e');
        }
      }
    }
    Log.audio.d('AudioAnalysis: Loaded ${_cache.length} cached analyses');
  }

  Future<void> _saveCache() async {
    final data = <String, Map<String, dynamic>>{};
    for (final entry in _cache.entries) {
      data[entry.key] = entry.value.toJson();
    }
    await _box?.put('analyses', data);
  }

  /// Get or compute analysis for a song
  Future<SongAnalysis?> getAnalysis(Song song) async {
    if (song.path == null) return null;

    // Check cache first
    if (_cache.containsKey(song.path)) {
      return _cache[song.path];
    }

    // Analyze the song
    final analysis = await _analyzeSong(song);
    if (analysis != null) {
      _cache[song.path!] = analysis;
      await _saveCache();
    }

    return analysis;
  }

  /// Analyze a song for crossfade parameters
  Future<SongAnalysis?> _analyzeSong(Song song) async {
    if (song.path == null) return null;

    Log.audio.d('AudioAnalysis: Analyzing ${song.title}');

    // Get BPM from metadata if available
    final bpm = await _getBpmFromMetadata(song);

    // Check if this is a gapless track
    final isGapless = _isGaplessTrack(song);

    // Analyze silence at end of track
    final silenceStart = await _findSilenceStart(song);

    return SongAnalysis(
      path: song.path!,
      silenceStart: silenceStart,
      bpm: bpm,
      isGaplessTrack: isGapless,
    );
  }

  /// Get BPM from song metadata or native extraction
  Future<int?> _getBpmFromMetadata(Song song) async {
    // Try to read BPM from file using native code
    if (song.path != null) {
      try {
        final result = await _channel.invokeMethod<int>('getBpm', {
          'path': song.path,
        });
        return result;
      } catch (e) {
        // Native method not available, that's okay
        Log.audio.d('AudioAnalysis: Native BPM extraction not available');
      }
    }

    return null;
  }

  /// Check if a track should be treated as gapless
  bool _isGaplessTrack(Song song) {
    // Check album name for live/continuous keywords
    final albumLower = song.album?.toLowerCase() ?? '';
    for (final keyword in _liveAlbumKeywords) {
      if (albumLower.contains(keyword)) {
        return true;
      }
    }

    // Check track title for segue/medley keywords
    final titleLower = song.title.toLowerCase();
    for (final keyword in _gaplessTrackKeywords) {
      if (titleLower.contains(keyword)) {
        return true;
      }
    }

    return false;
  }

  /// Find where silence starts at the end of a track
  /// Returns the duration from start where silence begins, or null if no silence detected
  Future<Duration?> _findSilenceStart(Song song) async {
    if (song.path == null || song.duration <= 0) return null;

    // Try native silence detection first
    try {
      final result = await _channel.invokeMethod<int>('findSilenceStart', {
        'path': song.path,
        'thresholdDb': -40.0, // -40 dB threshold for silence
        'analyzeLastMs': 15000, // Analyze last 15 seconds
      });

      if (result != null && result > 0) {
        return Duration(milliseconds: result);
      }
    } catch (e) {
      // Native method not available, use heuristic approach
      Log.audio.d('AudioAnalysis: Native silence detection not available, using heuristic');
    }

    // Heuristic: For tracks that fade out, assume silence starts
    // at roughly 95% of the track duration for most pop/rock songs
    // This is a rough estimate without actual audio analysis
    final trackDuration = Duration(milliseconds: song.duration);

    // Only apply heuristic for tracks longer than 2 minutes
    if (trackDuration.inSeconds > 120) {
      // Assume most tracks have a ~3-5 second fade/silence at the end
      final estimatedSilence = Duration(
        milliseconds: (trackDuration.inMilliseconds * 0.97).round(),
      );
      return estimatedSilence;
    }

    return null;
  }

  /// Detect if an album appears to be a continuous/live recording
  Future<bool> isGaplessAlbum(List<Song> albumSongs) async {
    if (albumSongs.isEmpty) return false;

    // Check if album name suggests live/continuous
    final albumName = albumSongs.first.album?.toLowerCase() ?? '';
    for (final keyword in _liveAlbumKeywords) {
      if (albumName.contains(keyword)) {
        return true;
      }
    }

    // Check if multiple tracks are marked as gapless
    int gaplessCount = 0;
    for (final song in albumSongs) {
      if (_isGaplessTrack(song)) {
        gaplessCount++;
      }
    }

    // If more than half the tracks are gapless-type, consider the album gapless
    return gaplessCount > albumSongs.length / 2;
  }

  /// Calculate optimal crossfade duration based on BPM
  /// Returns duration in milliseconds that aligns with beat grid
  int? getOptimalCrossfadeDuration(int? bpm, int baseDurationMs) {
    if (bpm == null || bpm <= 0) return null;

    // Calculate milliseconds per beat
    final msPerBeat = 60000 / bpm;

    // Find the number of beats closest to the base duration
    final beats = (baseDurationMs / msPerBeat).round();

    // Ensure at least 2 beats for a smooth transition
    final actualBeats = beats < 2 ? 2 : beats;

    // Return duration snapped to beat grid
    return (actualBeats * msPerBeat).round();
  }

  /// Clear all cached analyses
  Future<void> clearCache() async {
    _cache.clear();
    await _box?.delete('analyses');
  }

  /// Check if a song has been analyzed
  bool hasAnalysis(String? path) {
    if (path == null) return false;
    return _cache.containsKey(path);
  }
}

// Global instance
final audioAnalysisService = AudioAnalysisService();
