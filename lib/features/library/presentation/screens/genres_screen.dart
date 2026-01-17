import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/genre.dart';
import '../../data/media_scanner.dart';
import 'genre_detail_screen.dart';

class GenresScreen extends ConsumerWidget {
  const GenresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genresAsync = ref.watch(genresProvider);

    return genresAsync.when(
      data: (genres) {
        if (genres.isEmpty) {
          return _buildEmptyState(context);
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(genresProvider);
          },
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: genres.length,
            itemBuilder: (context, index) {
              final genre = genres[index];
              return _GenreTile(genre: genre, index: index)
                  .animate(delay: (50 * (index % 10)).ms)
                  .fadeIn(duration: 300.ms)
                  .scale(begin: const Offset(0.95, 0.95));
            },
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      ),
      error: (_, __) => const Center(
        child: Text('Failed to load genres'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.category_rounded,
            size: 64,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'No Genres Found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Add genre tags to your music files',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _GenreTile extends StatelessWidget {
  final Genre genre;
  final int index;

  const _GenreTile({required this.genre, required this.index});

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

    // Use hash of genre name for consistent color
    final hash = genre.name.hashCode.abs();
    return colors[hash % colors.length];
  }

  IconData _getGenreIcon() {
    final nameLower = genre.name.toLowerCase();

    if (nameLower.contains('rock')) return Icons.music_note_rounded;
    if (nameLower.contains('pop')) return Icons.star_rounded;
    if (nameLower.contains('hip') || nameLower.contains('rap')) return Icons.mic_rounded;
    if (nameLower.contains('jazz')) return Icons.piano_rounded;
    if (nameLower.contains('classical')) return Icons.library_music_rounded;
    if (nameLower.contains('electronic') || nameLower.contains('edm')) return Icons.waves_rounded;
    if (nameLower.contains('country')) return Icons.landscape_rounded;
    if (nameLower.contains('r&b') || nameLower.contains('soul')) return Icons.favorite_rounded;
    if (nameLower.contains('metal')) return Icons.bolt_rounded;
    if (nameLower.contains('punk')) return Icons.flash_on_rounded;
    if (nameLower.contains('indie')) return Icons.album_rounded;
    if (nameLower.contains('folk')) return Icons.forest_rounded;
    if (nameLower.contains('blues')) return Icons.nightlight_rounded;
    if (nameLower.contains('reggae')) return Icons.beach_access_rounded;
    if (nameLower.contains('latin')) return Icons.celebration_rounded;
    if (nameLower.contains('ambient')) return Icons.cloud_rounded;
    if (nameLower.contains('soundtrack') || nameLower.contains('score')) return Icons.movie_rounded;
    if (nameLower == 'unknown') return Icons.help_outline_rounded;

    return Icons.music_note_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getGenreColor();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GenreDetailScreen(genre: genre),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.3),
                color.withValues(alpha: 0.1),
              ],
            ),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  _getGenreIcon(),
                  color: color,
                  size: 28,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      genre.displayName,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${genre.songCount} ${genre.songCount == 1 ? 'song' : 'songs'}',
                      style: TextStyle(
                        color: color.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
