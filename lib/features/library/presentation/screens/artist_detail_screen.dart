import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/artist.dart';
import '../../../player/data/player_provider.dart';
import '../../data/media_scanner.dart';
import '../widgets/song_tile.dart';

class ArtistDetailScreen extends ConsumerWidget {
  final Artist artist;

  const ArtistDetailScreen({super.key, required this.artist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(songsByArtistProvider(artist.id));

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor.withValues(alpha:0.3),
              AppTheme.darkBackground,
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            // App bar with artist info
            SliverAppBar(
              expandedHeight: 250,
              pinned: true,
              backgroundColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                background: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                        // Artist avatar
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.primaryColor,
                                AppTheme.secondaryColor,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha:0.4),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              artist.name.isNotEmpty
                                  ? artist.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ).animate().scale(duration: 500.ms, curve: Curves.easeOut),

                        const SizedBox(height: 16),

                        // Artist name
                        Text(
                          artist.name,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 200.ms),

                        const SizedBox(height: 8),

                        // Stats
                        Text(
                          '${artist.songCount} songs • ${artist.albumCount} albums',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ).animate().fadeIn(delay: 300.ms),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Action buttons
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final songs = await ref.read(
                            songsByArtistProvider(artist.id).future,
                          );
                          if (songs.isNotEmpty) {
                            ref.read(playerProvider.notifier).playSong(
                              songs.first,
                              songs,
                            );
                          }
                        },
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play All'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryColor.withValues(alpha:0.2),
                      ),
                      child: IconButton(
                        onPressed: () async {
                          final songs = await ref.read(
                            songsByArtistProvider(artist.id).future,
                          );
                          if (songs.isNotEmpty) {
                            final shuffled = List.of(songs)..shuffle();
                            ref.read(playerProvider.notifier).playSong(
                              shuffled.first,
                              shuffled,
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.shuffle_rounded,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
            ),

            // Songs header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Songs',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),

            // Songs list
            songsAsync.when(
              data: (songs) => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = songs[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SongTile(
                        song: song,
                        onTap: () async {
                          final playerNotifier = ref.read(playerProvider.notifier);
                          await playerNotifier.playSong(song, songs);
                        },
                      ),
                    ).animate(delay: (50 * index).ms)
                        .fadeIn(duration: 300.ms)
                        .slideX(begin: 0.1);
                  },
                  childCount: songs.length,
                ),
              ),
              loading: () => const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
              error: (_, __) => const SliverToBoxAdapter(
                child: Center(
                  child: Text('Failed to load songs'),
                ),
              ),
            ),

            // Bottom spacing
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }
}
