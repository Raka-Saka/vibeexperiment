import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../shared/models/song.dart';
import 'log_service.dart';

/// Top-level function for background queue serialization.
/// Must be top-level or static for use with compute().
String _serializeQueueInBackground(List<Song> queue) {
  final queueJson = queue
      .where((s) => s.path != null)
      .map((s) => s.toJson())
      .toList();
  return jsonEncode(queueJson);
}

/// Service to persist and restore playback state across app restarts.
///
/// Uses debouncing to avoid UI jank when saving large queues frequently.
/// Queue serialization is done on a background isolate for playlists > 100 songs.
class PlaybackStateService {
  static const _boxName = 'playback_state';
  static const _debouncePositionMs = 2000; // Debounce position saves
  static const _debounceQueueMs = 500; // Debounce queue saves
  static const _largeQueueThreshold = 100; // Use isolate for queues larger than this

  Box? _box;
  bool _initialized = false;

  // Debounce timers
  Timer? _positionSaveTimer;
  Timer? _queueSaveTimer;

  // Track last saved queue hash to avoid redundant saves
  int _lastQueueHash = 0;
  int _lastQueueLength = 0;

  /// Initialize the service
  Future<void> init() async {
    if (_initialized) return;
    try {
      _box = await Hive.openBox(_boxName);
      _initialized = true;
      Log.storage.d('PlaybackStateService initialized');
    } catch (e) {
      Log.storage.d('PlaybackStateService: Failed to init: $e');
    }
  }

  /// Save the current playback state with smart debouncing.
  ///
  /// Position updates are heavily debounced (2s) since they happen frequently.
  /// Queue changes are debounced less (500ms) and only saved if actually changed.
  Future<void> saveState({
    required Song? currentSong,
    required List<Song> queue,
    required int currentIndex,
    required Duration position,
  }) async {
    if (_box == null) await init();

    // Always save current song and index immediately (small data)
    try {
      await _box?.put('currentSongPath', currentSong?.path);
      await _box?.put('currentIndex', currentIndex);

      if (currentSong != null) {
        await _box?.put('currentSongJson', jsonEncode(currentSong.toJson()));
      } else {
        await _box?.delete('currentSongJson');
      }
    } catch (e) {
      Log.storage.d('PlaybackStateService: Failed to save current song: $e');
    }

    // Debounce position saves (happens very frequently during playback)
    _positionSaveTimer?.cancel();
    _positionSaveTimer = Timer(
      const Duration(milliseconds: _debouncePositionMs),
      () => _savePosition(position),
    );

    // Check if queue actually changed before scheduling save
    final queueHash = _computeQueueHash(queue);
    if (queueHash != _lastQueueHash || queue.length != _lastQueueLength) {
      _lastQueueHash = queueHash;
      _lastQueueLength = queue.length;

      // Debounce queue saves
      _queueSaveTimer?.cancel();
      _queueSaveTimer = Timer(
        const Duration(milliseconds: _debounceQueueMs),
        () => _saveQueue(queue),
      );
    }
  }

  /// Save position to storage
  Future<void> _savePosition(Duration position) async {
    try {
      await _box?.put('position', position.inMilliseconds);
    } catch (e) {
      Log.storage.d('PlaybackStateService: Failed to save position: $e');
    }
  }

  /// Save queue to storage, using isolate for large queues
  Future<void> _saveQueue(List<Song> queue) async {
    try {
      String queueJsonString;

      if (queue.length > _largeQueueThreshold) {
        // Large queue - serialize on background isolate to avoid jank
        queueJsonString = await compute(_serializeQueueInBackground, queue);
      } else {
        // Small queue - serialize on main thread
        final queueJson = queue
            .where((s) => s.path != null)
            .map((s) => s.toJson())
            .toList();
        queueJsonString = jsonEncode(queueJson);
      }

      await _box?.put('queueJson', queueJsonString);
      Log.storage.d('PlaybackStateService: Queue saved (${queue.length} songs)');
    } catch (e) {
      Log.storage.d('PlaybackStateService: Failed to save queue: $e');
    }
  }

  /// Compute a simple hash of queue for change detection
  int _computeQueueHash(List<Song> queue) {
    if (queue.isEmpty) return 0;
    // Use first, middle, and last song IDs + length as a quick hash
    final first = queue.first.id;
    final last = queue.last.id;
    final mid = queue[queue.length ~/ 2].id;
    return first ^ last ^ mid ^ queue.length;
  }

  /// Force immediate save (call before app termination)
  Future<void> saveStateImmediate({
    required Song? currentSong,
    required List<Song> queue,
    required int currentIndex,
    required Duration position,
  }) async {
    // Cancel any pending debounced saves
    _positionSaveTimer?.cancel();
    _queueSaveTimer?.cancel();

    if (_box == null) await init();

    try {
      await _box?.put('currentSongPath', currentSong?.path);
      await _box?.put('currentIndex', currentIndex);
      await _box?.put('position', position.inMilliseconds);

      if (currentSong != null) {
        await _box?.put('currentSongJson', jsonEncode(currentSong.toJson()));
      } else {
        await _box?.delete('currentSongJson');
      }

      // Serialize queue (on main thread since we need it done now)
      final queueJson = queue
          .where((s) => s.path != null)
          .map((s) => s.toJson())
          .toList();
      await _box?.put('queueJson', jsonEncode(queueJson));

      Log.storage.d('PlaybackStateService: State saved immediately (${queue.length} songs)');
    } catch (e) {
      Log.storage.d('PlaybackStateService: Failed to save immediately: $e');
    }
  }

  /// Get the saved current song path
  String? get savedCurrentSongPath => _box?.get('currentSongPath');

  /// Get the saved current song as full Song object
  Song? get savedCurrentSong {
    try {
      final json = _box?.get('currentSongJson');
      if (json != null) {
        return Song.fromJson(jsonDecode(json) as Map<String, dynamic>);
      }
    } catch (e) {
      Log.storage.d('PlaybackStateService: Failed to get current song: $e');
    }
    return null;
  }

  /// Get the saved queue as full Song objects
  List<Song> get savedQueue {
    try {
      final json = _box?.get('queueJson');
      if (json != null) {
        final List<dynamic> list = jsonDecode(json);
        return list
            .map((item) => Song.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      Log.storage.d('PlaybackStateService: Failed to get queue: $e');
    }
    return [];
  }

  // Note: savedQueuePaths was removed (legacy code, never used).
  // The 'queuePaths' key is still cleared in clearState() for migration cleanup.

  /// Get the saved current index
  int get savedCurrentIndex => _box?.get('currentIndex') ?? 0;

  /// Get the saved position
  Duration get savedPosition =>
      Duration(milliseconds: _box?.get('position') ?? 0);

  /// Check if there's a saved state
  bool get hasSavedState => savedCurrentSongPath != null;

  /// Clear the saved state
  Future<void> clearState() async {
    if (_box == null) await init();
    await _box?.delete('currentSongPath');
    await _box?.delete('currentSongJson');
    await _box?.delete('queueJson');
    await _box?.delete('queuePaths');
    await _box?.delete('currentIndex');
    await _box?.delete('position');
    Log.storage.d('PlaybackStateService: State cleared');
  }
}

/// Global instance
final playbackStateService = PlaybackStateService();
