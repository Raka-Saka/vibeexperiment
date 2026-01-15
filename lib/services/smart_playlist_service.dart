import '../shared/models/song.dart';
import 'play_statistics_service.dart';

/// Types of smart playlists
enum SmartPlaylistType {
  recentlyPlayed,
  mostPlayed,
  recentlyAdded,
  leastPlayed,
  favorites, // Songs with high play count and completion rate
  forgotten, // Songs not played in a long time
}

/// A smart playlist definition
class SmartPlaylist {
  final SmartPlaylistType type;
  final String name;
  final String description;
  final String icon;
  final int maxSongs;

  const SmartPlaylist({
    required this.type,
    required this.name,
    required this.description,
    this.icon = 'playlist_play',
    this.maxSongs = 50,
  });

  static const all = [
    SmartPlaylist(
      type: SmartPlaylistType.recentlyPlayed,
      name: 'Recently Played',
      description: 'Songs you listened to recently',
      icon: 'history',
      maxSongs: 50,
    ),
    SmartPlaylist(
      type: SmartPlaylistType.mostPlayed,
      name: 'Most Played',
      description: 'Your top tracks by play count',
      icon: 'trending_up',
      maxSongs: 50,
    ),
    SmartPlaylist(
      type: SmartPlaylistType.recentlyAdded,
      name: 'Recently Added',
      description: 'Songs added to your library recently',
      icon: 'new_releases',
      maxSongs: 50,
    ),
    SmartPlaylist(
      type: SmartPlaylistType.leastPlayed,
      name: 'Least Played',
      description: 'Songs you rarely listen to',
      icon: 'explore',
      maxSongs: 50,
    ),
    SmartPlaylist(
      type: SmartPlaylistType.favorites,
      name: 'Heavy Rotation',
      description: 'Songs you can\'t stop playing',
      icon: 'favorite',
      maxSongs: 25,
    ),
    SmartPlaylist(
      type: SmartPlaylistType.forgotten,
      name: 'Rediscover',
      description: 'Songs you haven\'t played in a while',
      icon: 'restore',
      maxSongs: 50,
    ),
  ];
}

/// Service for generating smart playlists based on listening statistics
class SmartPlaylistService {
  /// Get song IDs for a smart playlist
  List<int> getSongIds(
    SmartPlaylistType type,
    List<Song> allSongs, {
    int? limit,
  }) {
    final maxSongs = limit ?? SmartPlaylist.all.firstWhere((p) => p.type == type).maxSongs;

    switch (type) {
      case SmartPlaylistType.recentlyPlayed:
        return _getRecentlyPlayed(maxSongs);

      case SmartPlaylistType.mostPlayed:
        return _getMostPlayed(allSongs, maxSongs);

      case SmartPlaylistType.recentlyAdded:
        return _getRecentlyAdded(allSongs, maxSongs);

      case SmartPlaylistType.leastPlayed:
        return _getLeastPlayed(allSongs, maxSongs);

      case SmartPlaylistType.favorites:
        return _getHeavyRotation(allSongs, maxSongs);

      case SmartPlaylistType.forgotten:
        return _getForgotten(allSongs, maxSongs);
    }
  }

  /// Get songs for a smart playlist
  List<Song> getSongs(
    SmartPlaylistType type,
    List<Song> allSongs, {
    int? limit,
  }) {
    final songIds = getSongIds(type, allSongs, limit: limit);
    final songMap = {for (final song in allSongs) song.id: song};

    return songIds
        .map((id) => songMap[id])
        .whereType<Song>()
        .toList();
  }

  // ============ Smart Playlist Generators ============

  /// Recently played songs (from history)
  List<int> _getRecentlyPlayed(int limit) {
    return playStatisticsService.getRecentlyPlayedSongIds(limit: limit);
  }

  /// Most played songs (by play count)
  List<int> _getMostPlayed(List<Song> allSongs, int limit) {
    final stats = playStatisticsService.getAllSongStats();
    if (stats.isEmpty) return [];

    // Sort by play count descending
    stats.sort((a, b) => b.playCount.compareTo(a.playCount));

    // Filter to songs that still exist in library
    final validIds = allSongs.map((s) => s.id).toSet();
    return stats
        .where((s) => validIds.contains(s.songId) && s.playCount >= 2)
        .take(limit)
        .map((s) => s.songId)
        .toList();
  }

  /// Recently added songs (by song ID - higher ID = more recently added)
  List<int> _getRecentlyAdded(List<Song> allSongs, int limit) {
    // Sort by ID descending (higher ID = more recently added to library)
    final sorted = List<Song>.from(allSongs)
      ..sort((a, b) => b.id.compareTo(a.id));

    return sorted.take(limit).map((s) => s.id).toList();
  }

  /// Least played songs (songs with low play counts)
  List<int> _getLeastPlayed(List<Song> allSongs, int limit) {
    final stats = playStatisticsService.getAllSongStats();
    final playedIds = stats.map((s) => s.songId).toSet();

    // First, include songs that have never been played
    final neverPlayed = allSongs
        .where((s) => !playedIds.contains(s.id))
        .map((s) => s.id)
        .toList();

    // Then add songs with low play counts
    final lowPlayCount = stats
        .where((s) => s.playCount <= 2)
        .toList()
      ..sort((a, b) => a.playCount.compareTo(b.playCount));

    final validIds = allSongs.map((s) => s.id).toSet();
    final lowPlayedIds = lowPlayCount
        .where((s) => validIds.contains(s.songId))
        .map((s) => s.songId)
        .toList();

    // Combine and limit
    final result = <int>[];
    result.addAll(neverPlayed.take(limit));
    if (result.length < limit) {
      result.addAll(lowPlayedIds.take(limit - result.length));
    }

    return result.take(limit).toList();
  }

  /// Heavy rotation - songs with high play count and good completion rate
  List<int> _getHeavyRotation(List<Song> allSongs, int limit) {
    final stats = playStatisticsService.getAllSongStats();
    if (stats.isEmpty) return [];

    // Calculate a "love score" based on play count and skip rate
    final scored = <int, double>{};
    for (final stat in stats) {
      if (stat.playCount < 3) continue; // Need at least 3 plays

      final skipRate = stat.skipCount / stat.playCount;
      final completionRate = 1.0 - skipRate;

      // Score = playCount * completionRate^2
      // This favors songs with high plays AND high completion
      scored[stat.songId] = stat.playCount * completionRate * completionRate;
    }

    // Sort by score descending
    final sortedIds = scored.keys.toList()
      ..sort((a, b) => scored[b]!.compareTo(scored[a]!));

    // Filter to songs that still exist
    final validIds = allSongs.map((s) => s.id).toSet();
    return sortedIds.where((id) => validIds.contains(id)).take(limit).toList();
  }

  /// Forgotten songs - haven't been played in a long time but were played before
  List<int> _getForgotten(List<Song> allSongs, int limit) {
    final stats = playStatisticsService.getAllSongStats();
    if (stats.isEmpty) return [];

    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // Find songs not played in the last 30 days
    final forgotten = stats
        .where((s) =>
            s.lastPlayedAt != null &&
            s.lastPlayedAt!.isBefore(thirtyDaysAgo) &&
            s.playCount >= 1)
        .toList()
      ..sort((a, b) {
        // Sort by last played (oldest first)
        final aDate = a.lastPlayedAt ?? DateTime(1970);
        final bDate = b.lastPlayedAt ?? DateTime(1970);
        return aDate.compareTo(bDate);
      });

    final validIds = allSongs.map((s) => s.id).toSet();
    return forgotten
        .where((s) => validIds.contains(s.songId))
        .take(limit)
        .map((s) => s.songId)
        .toList();
  }

  /// Get count of songs in a smart playlist (without loading all songs)
  int getCount(SmartPlaylistType type, List<Song> allSongs) {
    return getSongIds(type, allSongs).length;
  }

  /// Check if a smart playlist has any songs
  bool hasContent(SmartPlaylistType type, List<Song> allSongs) {
    return getSongIds(type, allSongs, limit: 1).isNotEmpty;
  }
}

// Global instance
final smartPlaylistService = SmartPlaylistService();
