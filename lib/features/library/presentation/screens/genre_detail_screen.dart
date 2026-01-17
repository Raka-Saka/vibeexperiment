import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/genre.dart';
import '../../../player/data/player_provider.dart';
import '../../data/media_scanner.dart';
import '../widgets/song_tile.dart';

class GenreDetailScreen extends ConsumerWidget {
  final Genre genre;

  const GenreDetailScreen({super.key, required this.genre});

  // Generate a consistent color based on genre name
  Color _getGenreColor() {
    final colors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEC4899), // Pink
      const Color(0xFFEF4444), // Red
      const Color(0xFFF97316), // Orange
      const Color(0xFFEAB308), // Yellow
      const Color(0xFF22C55E), // Green
      const Color(0xFF14B8A6), // Teal
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFF3B82F6), // Blue
    ];

    final hash = genre.name.hashCode.abs();
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(songsByGenreProvider(genre.name));
    final color = _getGenreColor();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.2),
              AppTheme.darkBackground,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: AppTheme.darkSurface.withValues(alpha: 0.9),
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  genre.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: 0.4),
                        color.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.category_rounded,
                      size: 80,
                      color: color.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              actions: [
                // Shuffle play button
                songsAsync.whenData((songs) {
                  if (songs.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(Icons.shuffle_rounded),
                    tooltip: 'Shuffle Play',
                    onPressed: () async {
                      final shuffled = List.of(songs)..shuffle();
                      await ref.read(playerProvider.notifier).playSong(
                        shuffled.first,
                        shuffled,
                      );
                    },
                  );
                }).value ?? const SizedBox.shrink(),
              ],
            ),

            // Stats Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.music_note_rounded, size: 16, color: color),
                          const SizedBox(width: 6),
                          Text(
                            '${genre.songCount} ${genre.songCount == 1 ? 'song' : 'songs'}',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Play all button
                    songsAsync.whenData((songs) {
                      if (songs.isEmpty) return const SizedBox.shrink();
                      return TextButton.icon(
                        onPressed: () async {
                          await ref.read(playerProvider.notifier).playSong(
                            songs.first,
                            songs,
                          );
                        },
                        icon: Icon(Icons.play_arrow_rounded, color: color),
                        label: Text('Play All', style: TextStyle(color: color)),
                      );
                    }).value ?? const SizedBox.shrink(),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms),
            ),

            // Songs List
            songsAsync.when(
              data: (songs) {
                if (songs.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
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
                            'No songs in this genre',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = songs[index];
                      return SongTile(
                        song: song,
                        onTap: () async {
                          await ref.read(playerProvider.notifier).playSong(
                            song,
                            songs,
                          );
                        },
                      ).animate(delay: (30 * (index % 15)).ms)
                          .fadeIn(duration: 200.ms)
                          .slideX(begin: 0.05);
                    },
                    childCount: songs.length,
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryColor),
                ),
              ),
              error: (_, __) => const SliverFillRemaining(
                child: Center(
                  child: Text('Failed to load songs'),
                ),
              ),
            ),

            // Bottom padding for mini player
            const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
          ],
        ),
      ),
    );
  }
}
