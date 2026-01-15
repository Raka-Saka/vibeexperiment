import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/album.dart';
import '../../data/media_scanner.dart';
import 'album_detail_screen.dart';

class AlbumsScreen extends ConsumerWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(albumsProvider);

    return albumsAsync.when(
      data: (albums) {
        if (albums.isEmpty) {
          return _buildEmptyState(context);
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(albumsProvider);
          },
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              return _AlbumCard(album: album)
                  .animate(delay: (50 * (index % 6)).ms)
                  .fadeIn(duration: 300.ms)
                  .scale(begin: const Offset(0.9, 0.9));
            },
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      ),
      error: (_, __) => const Center(
        child: Text('Failed to load albums'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.album_rounded,
            size: 64,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'No Albums Found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _AlbumCard extends ConsumerWidget {
  final Album album;

  const _AlbumCard({required this.album});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artworkAsync = ref.watch(artworkProvider((album.id, ArtworkType.ALBUM)));

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlbumDetailScreen(album: album),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppTheme.darkCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album art
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor.withValues(alpha:0.3),
                      AppTheme.secondaryColor.withValues(alpha:0.3),
                    ],
                  ),
                ),
                child: artworkAsync.when(
                  data: (bytes) {
                    if (bytes != null) {
                      return ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: Image.memory(
                          bytes,
                          fit: BoxFit.cover,
                        ),
                      );
                    }
                    return const Center(
                      child: Icon(
                        Icons.album_rounded,
                        size: 48,
                        color: AppTheme.textMuted,
                      ),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  error: (_, __) => const Center(
                    child: Icon(
                      Icons.album_rounded,
                      size: 48,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ),
            ),

            // Album info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    album.artistDisplay,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
