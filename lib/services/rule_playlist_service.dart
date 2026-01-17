import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../shared/models/playlist_rule.dart';
import '../shared/models/song.dart';
import 'play_statistics_service.dart' show playStatisticsService;
import 'log_service.dart';

/// Service for managing rule-based smart playlists
class RulePlaylistService extends StateNotifier<List<RuleBasedPlaylist>> {
  static const String _boxName = 'rule_playlists';
  Box? _box;
  final Ref _ref;

  RulePlaylistService(this._ref) : super([]) {
    _init();
  }

  Future<void> _init() async {
    _box = await Hive.openBox(_boxName);
    _loadPlaylists();
  }

  void _loadPlaylists() {
    final data = _box?.get('playlists');
    if (data != null) {
      try {
        final list = jsonDecode(data as String) as List;
        state = list
            .map((item) => RuleBasedPlaylist.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        Log.audio.d('RulePlaylistService: Loaded ${state.length} rule-based playlists');
      } catch (e) {
        Log.audio.d('RulePlaylistService: Failed to load playlists: $e');
        state = [];
      }
    }
  }

  Future<void> _save() async {
    final json = jsonEncode(state.map((p) => p.toJson()).toList());
    await _box?.put('playlists', json);
  }

  /// Get all rule-based playlists
  List<RuleBasedPlaylist> get playlists => state;

  /// Create a new rule-based playlist
  Future<RuleBasedPlaylist> createPlaylist({
    required String name,
    required List<PlaylistRule> rules,
    RuleLogic logic = RuleLogic.and,
    int? maxSongs,
  }) async {
    final playlist = RuleBasedPlaylist(
      id: const Uuid().v4(),
      name: name,
      rules: rules,
      logic: logic,
      maxSongs: maxSongs,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    state = [...state, playlist];
    await _save();
    Log.audio.d('RulePlaylistService: Created playlist "${playlist.name}"');
    return playlist;
  }

  /// Update an existing playlist
  Future<void> updatePlaylist(RuleBasedPlaylist playlist) async {
    state = state.map((p) => p.id == playlist.id ? playlist : p).toList();
    await _save();
    Log.audio.d('RulePlaylistService: Updated playlist "${playlist.name}"');
  }

  /// Delete a playlist
  Future<void> deletePlaylist(String playlistId) async {
    state = state.where((p) => p.id != playlistId).toList();
    await _save();
    Log.audio.d('RulePlaylistService: Deleted playlist $playlistId');
  }

  /// Get a playlist by ID
  RuleBasedPlaylist? getPlaylist(String id) {
    try {
      return state.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Generate songs for a rule-based playlist
  Future<List<Song>> generateSongs(
    RuleBasedPlaylist playlist,
    List<Song> allSongs,
  ) async {
    if (playlist.rules.isEmpty) {
      return [];
    }

    // Filter songs based on rules
    final matchingSongs = allSongs.where((song) {
      final playCount = playStatisticsService.getPlayCount(song.id);

      if (playlist.logic == RuleLogic.and) {
        // All rules must match
        return playlist.rules.every((rule) => rule.matches(song, playCount: playCount));
      } else {
        // Any rule must match
        return playlist.rules.any((rule) => rule.matches(song, playCount: playCount));
      }
    }).toList();

    // Apply limit if specified
    if (playlist.maxSongs != null && matchingSongs.length > playlist.maxSongs!) {
      return matchingSongs.take(playlist.maxSongs!).toList();
    }

    return matchingSongs;
  }
}

/// Provider for rule-based playlist service
final rulePlaylistServiceProvider =
    StateNotifierProvider<RulePlaylistService, List<RuleBasedPlaylist>>((ref) {
  return RulePlaylistService(ref);
});

/// Provider for songs in a specific rule-based playlist
final rulePlaylistSongsProvider =
    FutureProvider.family<List<Song>, String>((ref, playlistId) async {
  final service = ref.read(rulePlaylistServiceProvider.notifier);
  final playlist = service.getPlaylist(playlistId);

  if (playlist == null) return [];

  // Import here to avoid circular dependency
  final songsAsync = await ref.watch(
    FutureProvider<List<Song>>((ref) async {
      // We need to get songs from media scanner
      // This is a bit of a workaround for circular imports
      return [];
    }).future,
  );

  return service.generateSongs(playlist, songsAsync);
});
