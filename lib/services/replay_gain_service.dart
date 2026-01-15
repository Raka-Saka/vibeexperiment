import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../shared/models/song.dart';
import 'log_service.dart';

/// Target loudness level in LUFS (Loudness Units Full Scale)
/// -14 LUFS is the standard for streaming services (Spotify, YouTube, etc.)
const double kTargetLoudness = -14.0;

/// Loudness analysis result for a song
class LoudnessAnalysis {
  final String path;
  final double trackLoudness; // LUFS or estimated dB
  final double trackGain; // dB adjustment needed to reach target
  final double trackPeak; // Peak level (0.0 to 1.0)
  final DateTime analyzedAt;

  LoudnessAnalysis({
    required this.path,
    required this.trackLoudness,
    required this.trackGain,
    this.trackPeak = 1.0,
    DateTime? analyzedAt,
  }) : analyzedAt = analyzedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'path': path,
    'trackLoudness': trackLoudness,
    'trackGain': trackGain,
    'trackPeak': trackPeak,
    'analyzedAt': analyzedAt.toIso8601String(),
  };

  factory LoudnessAnalysis.fromJson(Map<String, dynamic> json) => LoudnessAnalysis(
    path: json['path'] as String,
    trackLoudness: (json['trackLoudness'] as num).toDouble(),
    trackGain: (json['trackGain'] as num).toDouble(),
    trackPeak: (json['trackPeak'] as num?)?.toDouble() ?? 1.0,
    analyzedAt: json['analyzedAt'] != null
        ? DateTime.parse(json['analyzedAt'] as String)
        : DateTime.now(),
  );
}

/// Album loudness data (average of all tracks)
class AlbumLoudness {
  final String albumKey; // album name + artist
  final double albumLoudness;
  final double albumGain;
  final double albumPeak;
  final int trackCount;

  AlbumLoudness({
    required this.albumKey,
    required this.albumLoudness,
    required this.albumGain,
    required this.albumPeak,
    required this.trackCount,
  });

  Map<String, dynamic> toJson() => {
    'albumKey': albumKey,
    'albumLoudness': albumLoudness,
    'albumGain': albumGain,
    'albumPeak': albumPeak,
    'trackCount': trackCount,
  };

  factory AlbumLoudness.fromJson(Map<String, dynamic> json) => AlbumLoudness(
    albumKey: json['albumKey'] as String,
    albumLoudness: (json['albumLoudness'] as num).toDouble(),
    albumGain: (json['albumGain'] as num).toDouble(),
    albumPeak: (json['albumPeak'] as num?)?.toDouble() ?? 1.0,
    trackCount: json['trackCount'] as int? ?? 1,
  );
}

enum NormalizationMode { off, track, album }

/// Service for analyzing and applying ReplayGain / volume normalization
class ReplayGainService {
  static const String _boxName = 'replay_gain';
  static const MethodChannel _channel = MethodChannel('com.vibeplay/audio_analysis');

  Box? _box;
  final Map<String, LoudnessAnalysis> _trackCache = {};
  final Map<String, AlbumLoudness> _albumCache = {};

  // Current normalization settings
  NormalizationMode _mode = NormalizationMode.off;
  double _targetLoudness = kTargetLoudness;
  bool _preventClipping = true;

  NormalizationMode get mode => _mode;
  double get targetLoudness => _targetLoudness;
  bool get preventClipping => _preventClipping;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);

    // Load cached track analyses
    final trackData = _box?.get('trackAnalyses') as Map<dynamic, dynamic>?;
    if (trackData != null) {
      for (final entry in trackData.entries) {
        try {
          _trackCache[entry.key as String] = LoudnessAnalysis.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        } catch (e) {
          Log.audio.d('ReplayGain: Error loading cached track analysis: $e');
        }
      }
    }

    // Load cached album analyses
    final albumData = _box?.get('albumAnalyses') as Map<dynamic, dynamic>?;
    if (albumData != null) {
      for (final entry in albumData.entries) {
        try {
          _albumCache[entry.key as String] = AlbumLoudness.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        } catch (e) {
          Log.audio.d('ReplayGain: Error loading cached album analysis: $e');
        }
      }
    }

    Log.audio.d('ReplayGain: Loaded ${_trackCache.length} track analyses, ${_albumCache.length} album analyses');
  }

  Future<void> _saveCache() async {
    final trackData = <String, Map<String, dynamic>>{};
    for (final entry in _trackCache.entries) {
      trackData[entry.key] = entry.value.toJson();
    }
    await _box?.put('trackAnalyses', trackData);

    final albumData = <String, Map<String, dynamic>>{};
    for (final entry in _albumCache.entries) {
      albumData[entry.key] = entry.value.toJson();
    }
    await _box?.put('albumAnalyses', albumData);
  }

  void setMode(NormalizationMode mode) {
    _mode = mode;
  }

  void setTargetLoudness(double lufs) {
    _targetLoudness = lufs.clamp(-24.0, -6.0);
  }

  void setPreventClipping(bool prevent) {
    _preventClipping = prevent;
  }

  /// Get the gain adjustment for a song based on current mode
  Future<double> getGainForSong(Song song) async {
    if (_mode == NormalizationMode.off || song.path == null) {
      return 0.0; // No adjustment
    }

    final analysis = await getTrackAnalysis(song);
    if (analysis == null) {
      return 0.0;
    }

    double gain;
    double peak;

    if (_mode == NormalizationMode.album) {
      // Use album gain if available
      final albumKey = _getAlbumKey(song);
      final albumAnalysis = _albumCache[albumKey];
      if (albumAnalysis != null) {
        gain = albumAnalysis.albumGain;
        peak = albumAnalysis.albumPeak;
      } else {
        // Fall back to track gain
        gain = analysis.trackGain;
        peak = analysis.trackPeak;
      }
    } else {
      // Track mode
      gain = analysis.trackGain;
      peak = analysis.trackPeak;
    }

    // Adjust for target loudness difference from standard
    gain += (_targetLoudness - kTargetLoudness);

    // Prevent clipping if enabled
    if (_preventClipping && peak > 0) {
      final maxGainBeforeClip = -20 * _log10(peak);
      if (gain > maxGainBeforeClip) {
        gain = maxGainBeforeClip;
      }
    }

    return gain;
  }

  /// Convert gain in dB to linear multiplier for volume
  double gainToMultiplier(double gainDb) {
    // volume_multiplier = 10^(gain_db / 20)
    return _pow10(gainDb / 20.0);
  }

  /// Get or compute loudness analysis for a track
  Future<LoudnessAnalysis?> getTrackAnalysis(Song song) async {
    if (song.path == null) return null;

    // Check cache first
    if (_trackCache.containsKey(song.path)) {
      return _trackCache[song.path];
    }

    // Analyze the track
    final analysis = await _analyzeTrack(song);
    if (analysis != null) {
      _trackCache[song.path!] = analysis;
      await _saveCache();
    }

    return analysis;
  }

  /// Analyze a track for loudness
  Future<LoudnessAnalysis?> _analyzeTrack(Song song) async {
    if (song.path == null) return null;

    Log.audio.d('ReplayGain: Analyzing ${song.title}');

    // Try native LUFS analysis first
    try {
      final result = await _channel.invokeMethod<Map>('analyzeLoudness', {
        'path': song.path,
      });

      if (result != null) {
        final loudness = (result['loudness'] as num).toDouble();
        final peak = (result['peak'] as num?)?.toDouble() ?? 1.0;
        final gain = kTargetLoudness - loudness;

        return LoudnessAnalysis(
          path: song.path!,
          trackLoudness: loudness,
          trackGain: gain,
          trackPeak: peak,
        );
      }
    } catch (e) {
      Log.audio.d('ReplayGain: Native analysis not available, using estimation');
    }

    // Fallback: Estimate based on file properties and heuristics
    return _estimateLoudness(song);
  }

  /// Estimate loudness based on file properties when native analysis isn't available
  Future<LoudnessAnalysis?> _estimateLoudness(Song song) async {
    if (song.path == null) return null;

    // Heuristic estimation based on:
    // 1. Bitrate (higher bitrate often correlates with more dynamic range)
    // 2. Genre (if available)
    // 3. File size relative to duration

    double estimatedLoudness = -14.0; // Default to target

    // Adjust based on bitrate if available
    if (song.bitrate != null && song.bitrate! > 0) {
      // Higher bitrate often means more headroom/dynamic range
      // Lower bitrate (compressed) often means more limiting/louder
      if (song.bitrate! < 128) {
        estimatedLoudness = -12.0; // Likely more compressed/loud
      } else if (song.bitrate! > 256) {
        estimatedLoudness = -16.0; // Likely more dynamic
      }
    }

    // Adjust based on genre if available
    final genre = song.genre?.toLowerCase() ?? '';
    if (genre.contains('classical') || genre.contains('jazz') || genre.contains('acoustic')) {
      estimatedLoudness -= 3.0; // Often more dynamic
    } else if (genre.contains('rock') || genre.contains('metal') || genre.contains('edm') || genre.contains('pop')) {
      estimatedLoudness += 2.0; // Often louder due to mastering
    }

    // Calculate gain needed
    final gain = kTargetLoudness - estimatedLoudness;

    return LoudnessAnalysis(
      path: song.path!,
      trackLoudness: estimatedLoudness,
      trackGain: gain,
      trackPeak: 0.95, // Assume some headroom
    );
  }

  /// Calculate album loudness from a list of songs
  Future<AlbumLoudness?> calculateAlbumLoudness(List<Song> albumSongs) async {
    if (albumSongs.isEmpty) return null;

    final albumKey = _getAlbumKey(albumSongs.first);

    // Check cache
    if (_albumCache.containsKey(albumKey)) {
      return _albumCache[albumKey];
    }

    // Analyze all tracks
    double totalLoudness = 0;
    double maxPeak = 0;
    int analyzedCount = 0;

    for (final song in albumSongs) {
      final analysis = await getTrackAnalysis(song);
      if (analysis != null) {
        // Use power averaging for loudness (not simple average)
        totalLoudness += _pow10(analysis.trackLoudness / 10);
        if (analysis.trackPeak > maxPeak) {
          maxPeak = analysis.trackPeak;
        }
        analyzedCount++;
      }
    }

    if (analyzedCount == 0) return null;

    // Convert back from power to dB
    final albumLoudness = 10 * _log10(totalLoudness / analyzedCount);
    final albumGain = kTargetLoudness - albumLoudness;

    final albumAnalysis = AlbumLoudness(
      albumKey: albumKey,
      albumLoudness: albumLoudness,
      albumGain: albumGain,
      albumPeak: maxPeak,
      trackCount: analyzedCount,
    );

    _albumCache[albumKey] = albumAnalysis;
    await _saveCache();

    return albumAnalysis;
  }

  String _getAlbumKey(Song song) {
    final album = song.album ?? 'Unknown Album';
    final artist = song.artist ?? 'Unknown Artist';
    return '$album|$artist';
  }

  /// Check if a track has been analyzed
  bool hasAnalysis(String? path) {
    if (path == null) return false;
    return _trackCache.containsKey(path);
  }

  /// Clear all cached analyses
  Future<void> clearCache() async {
    _trackCache.clear();
    _albumCache.clear();
    await _box?.delete('trackAnalyses');
    await _box?.delete('albumAnalyses');
  }

  /// Analyze multiple songs in batch with progress callback
  /// Returns the number of successfully analyzed songs
  Future<int> analyzeBatch(
    List<Song> songs, {
    void Function(int completed, int total)? onProgress,
    void Function(Song song, LoudnessAnalysis analysis)? onSongAnalyzed,
  }) async {
    int successCount = 0;
    final total = songs.length;

    Log.audio.d('ReplayGain: Starting batch analysis of $total songs');

    for (int i = 0; i < songs.length; i++) {
      final song = songs[i];

      // Skip if already analyzed
      if (song.path != null && _trackCache.containsKey(song.path)) {
        successCount++;
        onProgress?.call(i + 1, total);
        continue;
      }

      final analysis = await getTrackAnalysis(song);
      if (analysis != null) {
        successCount++;
        onSongAnalyzed?.call(song, analysis);
      }

      onProgress?.call(i + 1, total);

      // Yield to UI thread periodically
      if (i % 5 == 0) {
        await Future.delayed(Duration.zero);
      }
    }

    Log.audio.d('ReplayGain: Batch analysis complete. $successCount/$total succeeded');
    return successCount;
  }

  /// Get analysis statistics
  Map<String, int> getStats() {
    return {
      'tracksAnalyzed': _trackCache.length,
      'albumsAnalyzed': _albumCache.length,
    };
  }

  /// Check if native LUFS analysis is available
  Future<bool> isNativeAnalysisAvailable() async {
    try {
      // Try a quick test call
      await _channel.invokeMethod('analyzeLoudness', {'path': '/test/nonexistent.mp3'});
      return true;
    } catch (e) {
      // If we get "ANALYSIS_FAILED" it means native is available but file doesn't exist
      // If we get "notImplemented" it means native is not available
      final errorStr = e.toString();
      return errorStr.contains('ANALYSIS_FAILED') || errorStr.contains('File not found');
    }
  }

  // Math helpers for dB calculations
  double _log10(double x) {
    if (x <= 0) return -100; // Avoid log(0)
    return math.log(x) / math.ln10;
  }

  double _pow10(double x) {
    return math.pow(10, x).toDouble();
  }
}

// Global instance
final replayGainService = ReplayGainService();
