import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/play_statistics_service.dart';
import '../../../services/smart_playlist_service.dart';
import '../../../shared/models/song.dart';
import '../../library/data/media_scanner.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.darkSurface,
              AppTheme.darkBackground,
            ],
          ),
        ),
        child: songsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (songs) => _buildContent(songs),
        ),
      ),
    );
  }

  Widget _buildContent(List<Song> songs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overview Stats
          _buildOverviewSection(),
          const SizedBox(height: 24),

          // Listening Time Chart
          _buildListeningTimeSection(),
          const SizedBox(height: 24),

          // Smart Playlists
          _buildSmartPlaylistsSection(songs),
        ],
      ),
    );
  }

  Widget _buildOverviewSection() {
    final totalTime = playStatisticsService.getTotalListeningTime();
    final weekTime = playStatisticsService.getListeningTimeForPeriod(days: 7);
    final totalPlays = playStatisticsService.getTotalSongsPlayed();
    final uniqueSongs = playStatisticsService.getUniqueSongsPlayed();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Listening',
                _formatDuration(totalTime),
                Icons.headphones_rounded,
                AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'This Week',
                _formatDuration(weekTime),
                Icons.calendar_today_rounded,
                AppTheme.secondaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Songs Played',
                totalPlays.toString(),
                Icons.play_circle_rounded,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Unique Songs',
                uniqueSongs.toString(),
                Icons.library_music_rounded,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListeningTimeSection() {
    final dailyStats = playStatisticsService.getDailyStats(days: 7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last 7 Days',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Container(
          height: 120,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: dailyStats.reversed.map((day) {
              final maxMs = dailyStats
                  .map((d) => d.totalListenTimeMs)
                  .reduce((a, b) => a > b ? a : b);
              final heightPercent = maxMs > 0
                  ? day.totalListenTimeMs / maxMs
                  : 0.0;

              return _buildDayBar(day, heightPercent);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDayBar(DailyStats day, double heightPercent) {
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = dayNames[day.date.weekday - 1];
    final isToday = day.date.day == DateTime.now().day &&
        day.date.month == DateTime.now().month;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 32,
          height: 60 * heightPercent.clamp(0.05, 1.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: isToday
                  ? [AppTheme.primaryColor, AppTheme.secondaryColor]
                  : [AppTheme.textMuted.withOpacity(0.3), AppTheme.textMuted.withOpacity(0.5)],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          dayName,
          style: TextStyle(
            color: isToday ? AppTheme.primaryColor : AppTheme.textMuted,
            fontSize: 10,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildSmartPlaylistsSection(List<Song> songs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Smart Playlists',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ...SmartPlaylist.all.map((playlist) {
          final count = smartPlaylistService.getCount(playlist.type, songs);
          return _buildSmartPlaylistTile(playlist, count, songs);
        }),
      ],
    );
  }

  Widget _buildSmartPlaylistTile(SmartPlaylist playlist, int count, List<Song> songs) {
    final hasContent = count > 0;
    final iconData = _getIconData(playlist.icon);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: hasContent
                ? AppTheme.primaryColor.withOpacity(0.2)
                : AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            iconData,
            color: hasContent ? AppTheme.primaryColor : AppTheme.textMuted,
            size: 22,
          ),
        ),
        title: Text(
          playlist.name,
          style: TextStyle(
            color: hasContent ? AppTheme.textPrimary : AppTheme.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          playlist.description,
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 12,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: hasContent
                ? AppTheme.primaryColor.withOpacity(0.1)
                : AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: hasContent ? AppTheme.primaryColor : AppTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        onTap: hasContent
            ? () => _openSmartPlaylist(playlist, songs)
            : null,
      ),
    );
  }

  void _openSmartPlaylist(SmartPlaylist playlist, List<Song> allSongs) {
    final songs = smartPlaylistService.getSongs(playlist.type, allSongs);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SmartPlaylistDetailScreen(
          playlist: playlist,
          songs: songs,
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'history':
        return Icons.history_rounded;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'new_releases':
        return Icons.new_releases_rounded;
      case 'explore':
        return Icons.explore_rounded;
      case 'favorite':
        return Icons.favorite_rounded;
      case 'restore':
        return Icons.restore_rounded;
      default:
        return Icons.playlist_play_rounded;
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return '${hours}h ${minutes}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '0m';
    }
  }
}

/// Detail screen for a smart playlist
class SmartPlaylistDetailScreen extends StatelessWidget {
  final SmartPlaylist playlist;
  final List<Song> songs;

  const SmartPlaylistDetailScreen({
    super.key,
    required this.playlist,
    required this.songs,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.darkSurface,
              AppTheme.darkBackground,
            ],
          ),
        ),
        child: songs.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.music_off_rounded,
                      size: 64,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No songs yet',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: songs.length,
                itemBuilder: (context, index) {
                  final song = songs[index];
                  final stats = playStatisticsService.getSongStats(song.id);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        song.title,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        song.artist ?? 'Unknown Artist',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: stats != null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${stats.playCount} plays',
                                  style: TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                                if (stats.lastPlayedAt != null)
                                  Text(
                                    _formatLastPlayed(stats.lastPlayedAt!),
                                    style: TextStyle(
                                      color: AppTheme.textMuted.withOpacity(0.7),
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            )
                          : null,
                    ),
                  );
                },
              ),
      ),
    );
  }

  String _formatLastPlayed(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()} weeks ago';
    } else {
      return '${(diff.inDays / 30).floor()} months ago';
    }
  }
}
