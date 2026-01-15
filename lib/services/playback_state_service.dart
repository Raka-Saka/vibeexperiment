import 'dart:convert';
import 'package:hive/hive.dart';
import '../shared/models/song.dart';
import 'log_service.dart';

/// Service to persist and restore playback state across app restarts
class PlaybackStateService {
  static const _boxName = 'playback_state';
  Box? _box;
  bool _initialized = false;

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

  /// Save the current playback state
  Future<void> saveState({
    required Song? currentSong,
    required List<Song> queue,
    required int currentIndex,
    required Duration position,
  }) async {
    if (_box == null) await init();

    try {
      await _box?.put('currentSongPath', currentSong?.path);
      await _box?.put('currentIndex', currentIndex);
      await _box?.put('position', position.inMilliseconds);

      // Save current song as full JSON for restoration
      if (currentSong != null) {
        await _box?.put('currentSongJson', jsonEncode(currentSong.toJson()));
      } else {
        await _box?.delete('currentSongJson');
      }

      // Save queue as list of full song JSON objects
      final queueJson = queue
          .where((s) => s.path != null)
          .map((s) => s.toJson())
          .toList();
      await _box?.put('queueJson', jsonEncode(queueJson));

      Log.storage.d('PlaybackStateService: State saved (${queue.length} songs)');
    } catch (e) {
      Log.storage.d('PlaybackStateService: Failed to save: $e');
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

  /// Get the saved queue paths (legacy/lightweight)
  List<String> get savedQueuePaths {
    try {
      final json = _box?.get('queuePaths');
      if (json != null) {
        return List<String>.from(jsonDecode(json));
      }
    } catch (e) {
      Log.storage.d('PlaybackStateService: Failed to get queue paths: $e');
    }
    return [];
  }

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
