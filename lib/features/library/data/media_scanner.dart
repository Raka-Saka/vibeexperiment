import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../shared/models/song.dart';
import '../../../shared/models/album.dart';
import '../../../shared/models/artist.dart';
import '../../../shared/models/genre.dart';
import '../../settings/data/settings_provider.dart';
import '../../../services/log_service.dart';

/// LRU cache for artwork to prevent repeated disk reads
class _ArtworkCache {
  final int maxSize;
  final Map<String, Uint8List> _cache = {};
  final List<String> _accessOrder = [];

  _ArtworkCache({this.maxSize = 50}); // Cache up to 50 artworks

  Uint8List? get(String key) {
    if (_cache.containsKey(key)) {
      // Move to end (most recently used)
      _accessOrder.remove(key);
      _accessOrder.add(key);
      return _cache[key];
    }
    return null;
  }

  void put(String key, Uint8List value) {
    if (_cache.containsKey(key)) {
      _accessOrder.remove(key);
    } else if (_cache.length >= maxSize) {
      // Remove least recently used
      final lruKey = _accessOrder.removeAt(0);
      _cache.remove(lruKey);
    }
    _cache[key] = value;
    _accessOrder.add(key);
  }

  void clear() {
    _cache.clear();
    _accessOrder.clear();
  }
}

class MediaScanner {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  // Artwork cache to prevent repeated disk reads
  static final _ArtworkCache _artworkCache = _ArtworkCache(maxSize: 50);

  // Cached songs list to avoid re-querying
  List<Song>? _cachedSongs;
  DateTime? _cacheTime;

  // Minimum duration in milliseconds (filter out short system sounds)
  static const int _minDurationMs = 30000; // 30 seconds

  // System paths to exclude
  static final List<String> _excludedPaths = [
    '/system/',
    '/product/',
    'Ringtones',
    'Alarms',
    'Notifications',
    'ringtones',
    'alarms',
    'notifications',
    'Android/media/com.', // App-specific media
    '/oem/',
    '/vendor/',
  ];

  /// Check if a song should be excluded based on path and duration
  bool _shouldExcludeSong(String? path, int duration) {
    // Filter by minimum duration
    if (duration < _minDurationMs) {
      return true;
    }

    // Filter by path
    if (path != null) {
      final lowerPath = path.toLowerCase();
      for (final excluded in _excludedPaths) {
        if (lowerPath.contains(excluded.toLowerCase())) {
          return true;
        }
      }
    }

    return false;
  }

  Future<bool> requestPermission() async {
    // Check if permission is already granted
    if (await Permission.audio.isGranted) {
      return true;
    }

    // Request permission based on Android version
    final status = await Permission.audio.request();
    if (status.isGranted) {
      return true;
    }

    // Fallback to storage permission for older Android
    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  /// Cache validity duration (5 minutes)
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Check if cache is valid
  bool get _isCacheValid =>
      _cachedSongs != null &&
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < _cacheDuration;

  /// Force refresh on next query
  void invalidateCache() {
    _cachedSongs = null;
    _cacheTime = null;
  }

  /// Rescan a specific file to update MediaStore after tag changes
  /// This tells Android to re-read the file's metadata
  Future<bool> rescanFile(String filePath) async {
    if (!Platform.isAndroid) return true;

    try {
      Log.storage.d('MediaScanner: Requesting rescan for $filePath');

      // Use on_audio_query's scan method if available, otherwise use platform channel
      // The on_audio_query package has scanMedia method
      final result = await _audioQuery.scanMedia(filePath);
      Log.storage.d('MediaScanner: scanMedia result: $result');

      // Invalidate our cache so next query gets fresh data
      invalidateCache();
      _artworkCache.clear();

      // Small delay to allow MediaStore to process
      await Future.delayed(const Duration(milliseconds: 500));

      return true;
    } catch (e) {
      Log.storage.d('MediaScanner: Error rescanning file: $e');
      // Try alternative method using method channel
      try {
        const platform = MethodChannel('com.vibeplay.vibeplay/media_scanner');
        await platform.invokeMethod('scanFile', {'path': filePath});
        invalidateCache();
        return true;
      } catch (e2) {
        Log.storage.d('MediaScanner: Alternative rescan also failed: $e2');
        // Even if rescan fails, invalidate cache so we at least re-query
        invalidateCache();
        return false;
      }
    }
  }

  /// Rescan multiple files
  Future<void> rescanFiles(List<String> filePaths) async {
    for (final path in filePaths) {
      await rescanFile(path);
    }
  }

  Future<List<Song>> querySongs({bool forceRefresh = false}) async {
    // Return cached songs if available and not forcing refresh
    if (!forceRefresh && _isCacheValid) {
      return _cachedSongs!;
    }

    final hasPermission = await requestPermission();
    if (!hasPermission) return [];

    try {
      final songModels = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      // Filter out system audio files
      final filteredModels = songModels.where((model) =>
        !_shouldExcludeSong(model.data, model.duration ?? 0)
      );

      // Convert to Song objects
      final songs = filteredModels.map((model) => Song(
        id: model.id,
        title: model.title,
        artist: model.artist,
        album: model.album,
        albumId: model.albumId,
        artistId: model.artistId,
        path: model.data,
        duration: model.duration ?? 0,
        trackNumber: model.track,
        genre: model.genre,
        year: model.getMap['year'] as int?,
        fileExtension: model.fileExtension,
        size: model.size,
      )).toList();

      // Cache the results
      _cachedSongs = songs;
      _cacheTime = DateTime.now();

      return songs;
    } catch (e) {
      return [];
    }
  }

  Future<List<Album>> queryAlbums() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return [];

    try {
      final albumModels = await _audioQuery.queryAlbums(
        sortType: AlbumSortType.ALBUM,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      return albumModels.map((model) => Album(
        id: model.id,
        name: model.album,
        artist: model.artist,
        artistId: model.artistId,
        songCount: model.numOfSongs,
      )).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Artist>> queryArtists() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return [];

    try {
      final artistModels = await _audioQuery.queryArtists(
        sortType: ArtistSortType.ARTIST,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      return artistModels.map((model) => Artist(
        id: model.id,
        name: model.artist,
        songCount: model.numberOfTracks ?? 0,
        albumCount: model.numberOfAlbums ?? 0,
      )).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Song>> querySongsByAlbum(int albumId) async {
    try {
      final songModels = await _audioQuery.queryAudiosFrom(
        AudiosFromType.ALBUM_ID,
        albumId,
        sortType: SongSortType.DISPLAY_NAME,
        orderType: OrderType.ASC_OR_SMALLER,
      );

      // Filter out system audio files
      final filteredModels = songModels.where((model) =>
        !_shouldExcludeSong(model.data, model.duration ?? 0)
      );

      return filteredModels.map((model) => Song(
        id: model.id,
        title: model.title,
        artist: model.artist,
        album: model.album,
        albumId: model.albumId,
        artistId: model.artistId,
        path: model.data,
        duration: model.duration ?? 0,
        trackNumber: model.track,
        genre: model.genre,
        fileExtension: model.fileExtension,
        size: model.size,
      )).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Song>> querySongsByArtist(int artistId) async {
    try {
      final songModels = await _audioQuery.queryAudiosFrom(
        AudiosFromType.ARTIST_ID,
        artistId,
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
      );

      // Filter out system audio files
      final filteredModels = songModels.where((model) =>
        !_shouldExcludeSong(model.data, model.duration ?? 0)
      );

      return filteredModels.map((model) => Song(
        id: model.id,
        title: model.title,
        artist: model.artist,
        album: model.album,
        albumId: model.albumId,
        artistId: model.artistId,
        path: model.data,
        duration: model.duration ?? 0,
        trackNumber: model.track,
        genre: model.genre,
        fileExtension: model.fileExtension,
        size: model.size,
      )).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Uint8List?> queryArtwork(int id, ArtworkType type, {int size = 300, int quality = 80}) async {
    // Create cache key
    final cacheKey = '${type.name}_${id}_$size';

    // Check cache first
    final cached = _artworkCache.get(cacheKey);
    if (cached != null) {
      return cached;
    }

    try {
      final artwork = await _audioQuery.queryArtwork(
        id,
        type,
        format: ArtworkFormat.JPEG,
        size: size,    // Reduced from 500 to 300 default
        quality: quality, // Reduced from 100 to 80 default
      );

      // Cache the result if not null
      if (artwork != null) {
        _artworkCache.put(cacheKey, artwork);
      }

      return artwork;
    } catch (e) {
      return null;
    }
  }

  /// Clear artwork cache (useful when memory is low)
  static void clearArtworkCache() {
    _artworkCache.clear();
  }

  /// Search songs - uses cached songs list if available
  Future<List<Song>> searchSongs(String query) async {
    // This uses the cached songs, avoiding a re-query
    final songs = await querySongs();
    final lowerQuery = query.toLowerCase();
    return songs.where((song) =>
      song.title.toLowerCase().contains(lowerQuery) ||
      (song.artist?.toLowerCase().contains(lowerQuery) ?? false) ||
      (song.album?.toLowerCase().contains(lowerQuery) ?? false)
    ).toList();
  }
}

// Providers
final mediaScannerProvider = Provider<MediaScanner>((ref) => MediaScanner());

final songsProvider = FutureProvider<List<Song>>((ref) async {
  final scanner = ref.read(mediaScannerProvider);
  final settings = ref.watch(settingsProvider);
  final songs = await scanner.querySongs();

  // Apply sort from settings
  songs.sort((a, b) {
    int comparison;
    switch (settings.defaultSort) {
      case SortOrder.title:
        comparison = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      case SortOrder.artist:
        comparison = (a.artist ?? '').toLowerCase().compareTo((b.artist ?? '').toLowerCase());
      case SortOrder.album:
        comparison = (a.album ?? '').toLowerCase().compareTo((b.album ?? '').toLowerCase());
      case SortOrder.dateAdded:
        // Use ID as proxy for date added (higher ID = more recent)
        comparison = a.id.compareTo(b.id);
      case SortOrder.duration:
        comparison = a.duration.compareTo(b.duration);
    }
    return settings.sortAscending ? comparison : -comparison;
  });

  return songs;
});

final albumsProvider = FutureProvider<List<Album>>((ref) async {
  final scanner = ref.read(mediaScannerProvider);
  return scanner.queryAlbums();
});

final artistsProvider = FutureProvider<List<Artist>>((ref) async {
  final scanner = ref.read(mediaScannerProvider);
  return scanner.queryArtists();
});

/// Provider for all genres extracted from the music library
final genresProvider = FutureProvider<List<Genre>>((ref) async {
  final songsAsync = await ref.watch(songsProvider.future);

  // Group songs by genre
  final genreMap = <String, List<int>>{};
  for (final song in songsAsync) {
    final genre = song.genre?.trim();
    if (genre != null && genre.isNotEmpty) {
      genreMap.putIfAbsent(genre, () => []).add(song.id);
    } else {
      genreMap.putIfAbsent('Unknown', () => []).add(song.id);
    }
  }

  // Convert to Genre objects and sort by song count (descending)
  final genres = genreMap.entries.map((entry) {
    return Genre(
      name: entry.key,
      songCount: entry.value.length,
      songIds: entry.value,
    );
  }).toList();

  genres.sort((a, b) => b.songCount.compareTo(a.songCount));

  return genres;
});

/// Provider for songs in a specific genre
final songsByGenreProvider = FutureProvider.family<List<Song>, String>((ref, genreName) async {
  final songsAsync = await ref.watch(songsProvider.future);

  if (genreName == 'Unknown') {
    return songsAsync.where((song) =>
      song.genre == null || song.genre!.trim().isEmpty
    ).toList();
  }

  return songsAsync.where((song) =>
    song.genre?.trim() == genreName
  ).toList();
});

final songsByAlbumProvider = FutureProvider.family<List<Song>, int>((ref, albumId) async {
  final scanner = ref.read(mediaScannerProvider);
  return scanner.querySongsByAlbum(albumId);
});

final songsByArtistProvider = FutureProvider.family<List<Song>, int>((ref, artistId) async {
  final scanner = ref.read(mediaScannerProvider);
  return scanner.querySongsByArtist(artistId);
});

final artworkProvider = FutureProvider.family<Uint8List?, (int, ArtworkType)>((ref, params) async {
  final scanner = ref.read(mediaScannerProvider);
  return scanner.queryArtwork(params.$1, params.$2);
});

final searchResultsProvider = FutureProvider.family<List<Song>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final scanner = ref.read(mediaScannerProvider);
  return scanner.searchSongs(query);
});
