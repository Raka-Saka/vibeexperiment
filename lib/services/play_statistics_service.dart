import 'package:hive/hive.dart';
import '../shared/models/song.dart';
import 'log_service.dart';

/// Statistics for a single song
class SongStatistics {
  final int songId;
  final String? songPath;
  int playCount;
  int skipCount;
  int totalListenTimeMs;
  DateTime? lastPlayedAt;
  DateTime firstPlayedAt;

  SongStatistics({
    required this.songId,
    this.songPath,
    this.playCount = 0,
    this.skipCount = 0,
    this.totalListenTimeMs = 0,
    this.lastPlayedAt,
    DateTime? firstPlayedAt,
  }) : firstPlayedAt = firstPlayedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'songId': songId,
    'songPath': songPath,
    'playCount': playCount,
    'skipCount': skipCount,
    'totalListenTimeMs': totalListenTimeMs,
    'lastPlayedAt': lastPlayedAt?.toIso8601String(),
    'firstPlayedAt': firstPlayedAt.toIso8601String(),
  };

  factory SongStatistics.fromJson(Map<String, dynamic> json) => SongStatistics(
    songId: json['songId'] as int,
    songPath: json['songPath'] as String?,
    playCount: json['playCount'] as int? ?? 0,
    skipCount: json['skipCount'] as int? ?? 0,
    totalListenTimeMs: json['totalListenTimeMs'] as int? ?? 0,
    lastPlayedAt: json['lastPlayedAt'] != null
        ? DateTime.parse(json['lastPlayedAt'] as String)
        : null,
    firstPlayedAt: json['firstPlayedAt'] != null
        ? DateTime.parse(json['firstPlayedAt'] as String)
        : DateTime.now(),
  );
}

/// A single listening history entry
class ListeningHistoryEntry {
  final int songId;
  final String? songPath;
  final String songTitle;
  final String? artistName;
  final DateTime playedAt;
  final int listenDurationMs;
  final bool completed; // Did they listen to >80% of the song?

  ListeningHistoryEntry({
    required this.songId,
    this.songPath,
    required this.songTitle,
    this.artistName,
    required this.playedAt,
    required this.listenDurationMs,
    this.completed = false,
  });

  Map<String, dynamic> toJson() => {
    'songId': songId,
    'songPath': songPath,
    'songTitle': songTitle,
    'artistName': artistName,
    'playedAt': playedAt.toIso8601String(),
    'listenDurationMs': listenDurationMs,
    'completed': completed,
  };

  factory ListeningHistoryEntry.fromJson(Map<String, dynamic> json) => ListeningHistoryEntry(
    songId: json['songId'] as int,
    songPath: json['songPath'] as String?,
    songTitle: json['songTitle'] as String,
    artistName: json['artistName'] as String?,
    playedAt: DateTime.parse(json['playedAt'] as String),
    listenDurationMs: json['listenDurationMs'] as int? ?? 0,
    completed: json['completed'] as bool? ?? false,
  );
}

/// Daily listening summary
class DailyStats {
  final DateTime date;
  int totalListenTimeMs;
  int songsPlayed;
  int songsCompleted;

  DailyStats({
    required this.date,
    this.totalListenTimeMs = 0,
    this.songsPlayed = 0,
    this.songsCompleted = 0,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'totalListenTimeMs': totalListenTimeMs,
    'songsPlayed': songsPlayed,
    'songsCompleted': songsCompleted,
  };

  factory DailyStats.fromJson(Map<String, dynamic> json) => DailyStats(
    date: DateTime.parse(json['date'] as String),
    totalListenTimeMs: json['totalListenTimeMs'] as int? ?? 0,
    songsPlayed: json['songsPlayed'] as int? ?? 0,
    songsCompleted: json['songsCompleted'] as int? ?? 0,
  );

  String get dateKey => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// Service for tracking play statistics and listening history
class PlayStatisticsService {
  static const String _boxName = 'play_statistics';
  static const int _maxHistoryEntries = 1000; // Keep last 1000 plays

  Box? _box;
  bool _isInitialized = false;
  final Map<int, SongStatistics> _songStats = {};
  final List<ListeningHistoryEntry> _history = [];
  final Map<String, DailyStats> _dailyStats = {};

  // Current session tracking
  int? _currentSongId;
  DateTime? _currentPlayStartTime;
  int _currentListenedMs = 0;

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;

  /// Get stats count (for debugging)
  int get statsCount => _songStats.length;

  Future<void> init() async {
    if (_isInitialized) {
      Log.audio.d('PlayStats: Already initialized, skipping');
      return;
    }

    Log.audio.d('PlayStats: Initializing...');
    _box = await Hive.openBox(_boxName);
    Log.audio.d('PlayStats: Hive box opened');

    // Load song statistics
    final statsData = _box?.get('songStats') as Map<dynamic, dynamic>?;
    Log.audio.d('PlayStats: Raw stats data: ${statsData?.length ?? 0} entries');
    if (statsData != null) {
      for (final entry in statsData.entries) {
        try {
          final stats = SongStatistics.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
          _songStats[stats.songId] = stats;
        } catch (e) {
          Log.audio.d('PlayStats: Error loading song stats: $e');
        }
      }
    }

    // Load history
    final historyData = _box?.get('history') as List<dynamic>?;
    if (historyData != null) {
      for (final item in historyData) {
        try {
          _history.add(ListeningHistoryEntry.fromJson(
            Map<String, dynamic>.from(item as Map),
          ));
        } catch (e) {
          Log.audio.d('PlayStats: Error loading history: $e');
        }
      }
    }

    // Load daily stats
    final dailyData = _box?.get('dailyStats') as Map<dynamic, dynamic>?;
    if (dailyData != null) {
      for (final entry in dailyData.entries) {
        try {
          final stats = DailyStats.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
          _dailyStats[entry.key as String] = stats;
        } catch (e) {
          Log.audio.d('PlayStats: Error loading daily stats: $e');
        }
      }
    }

    _isInitialized = true;
    Log.audio.d('PlayStats: Initialized! Loaded ${_songStats.length} song stats, ${_history.length} history entries');
  }

  Future<void> _saveAll() async {
    if (_box == null) return;

    // Save song stats
    final statsData = <String, Map<String, dynamic>>{};
    for (final entry in _songStats.entries) {
      statsData[entry.key.toString()] = entry.value.toJson();
    }
    await _box!.put('songStats', statsData);

    // Save history (trim if too large)
    if (_history.length > _maxHistoryEntries) {
      _history.removeRange(0, _history.length - _maxHistoryEntries);
    }
    await _box!.put('history', _history.map((e) => e.toJson()).toList());

    // Save daily stats
    final dailyData = <String, Map<String, dynamic>>{};
    for (final entry in _dailyStats.entries) {
      dailyData[entry.key] = entry.value.toJson();
    }
    await _box!.put('dailyStats', dailyData);

    // Force immediate write to disk
    await _box!.flush();
  }

  // ============ Playback Tracking ============

  /// Call when a song starts playing
  void onSongStarted(Song song) {
    // Save any previous session first
    if (_currentSongId != null) {
      _finishCurrentSession(skipped: true);
    }

    _currentSongId = song.id;
    _currentPlayStartTime = DateTime.now();
    _currentListenedMs = 0;

    Log.audio.d('PlayStats: Started tracking ${song.title}');
  }

  /// Call periodically to update listen time (e.g., every 10 seconds)
  void updateListenTime(int additionalMs) {
    _currentListenedMs += additionalMs;
  }

  /// Call when song completes naturally
  void onSongCompleted(Song song) {
    if (_currentSongId == song.id) {
      _finishCurrentSession(skipped: false);
    }
  }

  /// Call when user skips to next song
  void onSongSkipped(Song song) {
    if (_currentSongId == song.id) {
      _finishCurrentSession(skipped: true);
    }
  }

  /// Call when playback stops
  void onPlaybackStopped() {
    if (_currentSongId != null) {
      _finishCurrentSession(skipped: false);
    }
  }

  void _finishCurrentSession({required bool skipped}) {
    if (_currentSongId == null || _currentPlayStartTime == null) return;

    final songId = _currentSongId!;
    final startTime = _currentPlayStartTime!;
    final listenedMs = _currentListenedMs;

    // Get or create song stats
    final stats = _songStats.putIfAbsent(
      songId,
      () => SongStatistics(songId: songId),
    );

    // Update stats
    stats.playCount++;
    if (skipped && listenedMs < 30000) {
      // Consider it a skip if less than 30 seconds listened
      stats.skipCount++;
    }
    stats.totalListenTimeMs += listenedMs;
    stats.lastPlayedAt = startTime;

    // Update daily stats
    final today = DateTime.now();
    final dayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final daily = _dailyStats.putIfAbsent(
      dayKey,
      () => DailyStats(date: DateTime(today.year, today.month, today.day)),
    );
    daily.totalListenTimeMs += listenedMs;
    daily.songsPlayed++;
    if (!skipped) {
      daily.songsCompleted++;
    }

    // Clear current session
    _currentSongId = null;
    _currentPlayStartTime = null;
    _currentListenedMs = 0;

    // Save asynchronously
    _saveAll();

    Log.audio.d('PlayStats: Finished session for song $songId, listened ${listenedMs}ms, skipped: $skipped');
  }

  /// Record a history entry (call after song finishes or is skipped)
  void addHistoryEntry(Song song, int listenDurationMs, bool completed) {
    final entry = ListeningHistoryEntry(
      songId: song.id,
      songPath: song.path,
      songTitle: song.title,
      artistName: song.artist,
      playedAt: DateTime.now(),
      listenDurationMs: listenDurationMs,
      completed: completed,
    );

    _history.add(entry);
    _saveAll();
  }

  // ============ Getters ============

  /// Get statistics for a specific song
  SongStatistics? getSongStats(int songId) => _songStats[songId];

  /// Get play count for a song
  int getPlayCount(int songId) => _songStats[songId]?.playCount ?? 0;

  /// Get last played time for a song
  DateTime? getLastPlayed(int songId) => _songStats[songId]?.lastPlayedAt;

  /// Get all song statistics
  List<SongStatistics> getAllSongStats() => _songStats.values.toList();

  /// Get listening history (most recent first)
  List<ListeningHistoryEntry> getHistory({int? limit}) {
    final sorted = List<ListeningHistoryEntry>.from(_history)
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    if (limit != null && sorted.length > limit) {
      return sorted.sublist(0, limit);
    }
    return sorted;
  }

  /// Get recently played song IDs (for smart playlist)
  List<int> getRecentlyPlayedSongIds({int limit = 50}) {
    final seen = <int>{};
    final result = <int>[];

    for (final entry in getHistory()) {
      if (!seen.contains(entry.songId)) {
        seen.add(entry.songId);
        result.add(entry.songId);
        if (result.length >= limit) break;
      }
    }

    return result;
  }

  /// Get most played song IDs (for smart playlist)
  List<int> getMostPlayedSongIds({int limit = 50, int minPlays = 2}) {
    final sorted = _songStats.values
        .where((s) => s.playCount >= minPlays)
        .toList()
      ..sort((a, b) => b.playCount.compareTo(a.playCount));

    return sorted.take(limit).map((s) => s.songId).toList();
  }

  /// Get daily stats for a date range
  List<DailyStats> getDailyStats({int days = 30}) {
    final now = DateTime.now();
    final result = <DailyStats>[];

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final dayKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final stats = _dailyStats[dayKey] ?? DailyStats(date: DateTime(date.year, date.month, date.day));
      result.add(stats);
    }

    return result;
  }

  /// Get total listening time (all time)
  Duration getTotalListeningTime() {
    int totalMs = 0;
    for (final stats in _songStats.values) {
      totalMs += stats.totalListenTimeMs;
    }
    return Duration(milliseconds: totalMs);
  }

  /// Get total listening time for a period
  Duration getListeningTimeForPeriod({int days = 7}) {
    int totalMs = 0;
    final cutoff = DateTime.now().subtract(Duration(days: days));

    for (final entry in _history) {
      if (entry.playedAt.isAfter(cutoff)) {
        totalMs += entry.listenDurationMs;
      }
    }

    return Duration(milliseconds: totalMs);
  }

  /// Get total songs played count
  int getTotalSongsPlayed() {
    int total = 0;
    for (final stats in _songStats.values) {
      total += stats.playCount;
    }
    return total;
  }

  /// Get unique songs played count
  int getUniqueSongsPlayed() => _songStats.length;

  /// Clear all statistics
  Future<void> clearAll() async {
    _songStats.clear();
    _history.clear();
    _dailyStats.clear();
    await _box?.clear();
  }
}

// Global instance
final playStatisticsService = PlayStatisticsService();
