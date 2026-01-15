import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../shared/models/playlist.dart';

class PlaylistRepository {
  static const String _boxName = 'playlists';
  late Box<String> _box;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _box = await Hive.openBox<String>(_boxName);
    _isInitialized = true;

    // Create favorites playlist if it doesn't exist
    if (!_box.containsKey('favorites')) {
      await savePlaylist(Playlist(
        id: 'favorites',
        name: 'Favorites',
        isFavorites: true,
      ));
    }
  }

  Future<List<Playlist>> getAllPlaylists() async {
    await init();
    final playlists = <Playlist>[];
    for (final key in _box.keys) {
      final json = _box.get(key);
      if (json != null) {
        playlists.add(Playlist.fromJson(jsonDecode(json)));
      }
    }
    // Sort: favorites first, then by name
    playlists.sort((a, b) {
      if (a.isFavorites) return -1;
      if (b.isFavorites) return 1;
      return a.name.compareTo(b.name);
    });
    return playlists;
  }

  Future<Playlist?> getPlaylist(String id) async {
    await init();
    final json = _box.get(id);
    if (json != null) {
      return Playlist.fromJson(jsonDecode(json));
    }
    return null;
  }

  Future<void> savePlaylist(Playlist playlist) async {
    await init();
    await _box.put(playlist.id, jsonEncode(playlist.toJson()));
  }

  Future<void> deletePlaylist(String id) async {
    await init();
    await _box.delete(id);
  }

  Future<Playlist> createPlaylist(String name, {String? description}) async {
    await init();
    final playlist = Playlist(
      name: name,
      description: description,
    );
    await savePlaylist(playlist);
    return playlist;
  }

  Future<void> addSongToPlaylist(String playlistId, int songId) async {
    await init();
    final playlist = await getPlaylist(playlistId);
    if (playlist != null) {
      final updated = playlist.addSong(songId);
      await savePlaylist(updated);
    }
  }

  Future<void> removeSongFromPlaylist(String playlistId, int songId) async {
    await init();
    final playlist = await getPlaylist(playlistId);
    if (playlist != null) {
      final updated = playlist.removeSong(songId);
      await savePlaylist(updated);
    }
  }

  Future<bool> isFavorite(int songId) async {
    await init();
    final favorites = await getPlaylist('favorites');
    return favorites?.songIds.contains(songId) ?? false;
  }

  Future<void> toggleFavorite(int songId) async {
    await init();
    final favorites = await getPlaylist('favorites');
    if (favorites != null) {
      if (favorites.songIds.contains(songId)) {
        await removeSongFromPlaylist('favorites', songId);
      } else {
        await addSongToPlaylist('favorites', songId);
      }
    }
  }
}

// Providers
final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  return PlaylistRepository();
});

final playlistsProvider = FutureProvider<List<Playlist>>((ref) async {
  final repository = ref.read(playlistRepositoryProvider);
  return repository.getAllPlaylists();
});

final playlistProvider = FutureProvider.family<Playlist?, String>((ref, id) async {
  final repository = ref.read(playlistRepositoryProvider);
  return repository.getPlaylist(id);
});

final isFavoriteProvider = FutureProvider.family<bool, int>((ref, songId) async {
  final repository = ref.read(playlistRepositoryProvider);
  return repository.isFavorite(songId);
});
