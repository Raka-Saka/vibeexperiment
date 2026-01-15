import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/dynamic_colors.dart';
import '../../../../shared/models/album.dart';
import '../../../player/data/player_provider.dart';
import '../../data/media_scanner.dart';
import '../widgets/song_tile.dart';

class AlbumDetailScreen extends ConsumerStatefulWidget {
  final Album album;

  const AlbumDetailScreen({super.key, required this.album});

  @override
  ConsumerState<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends ConsumerState<AlbumDetailScreen> {
  DynamicColors _colors = DynamicColors.defaultColors();

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songsByAlbumProvider(widget.album.id));
    final artworkAsync = ref.watch(artworkProvider((widget.album.id, ArtworkType.ALBUM)));

    // Extract colors from artwork using ref.listen to avoid memory leaks
    ref.listen(
      artworkProvider((widget.album.id, ArtworkType.ALBUM)),
      (previous, next) {
        next.whenData((bytes) async {
          if (bytes != null && mounted) {
            final colors = await DynamicColors.fromImageBytes(bytes);
            if (mounted) {
              setState(() => _colors = colors);
            }
          }
        });
      },
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: _colors.gradient,
        ),
        child: CustomScrollView(
          slivers: [
            // App bar with album art
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              backgroundColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _colors.primary.withValues(alpha:0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),

                    // Album art
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Hero(
                            tag: 'album-${widget.album.id}',
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha:0.4),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: artworkAsync.when(
                                data: (bytes) {
                                  if (bytes != null) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.memory(bytes, fit: BoxFit.cover),
                                    );
                                  }
                                  return _buildPlaceholder();
                                },
                                loading: () => _buildPlaceholder(),
                                error: (_, __) => _buildPlaceholder(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Album info
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.album.name,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ).animate().fadeIn().slideY(begin: 0.2),
                    const SizedBox(height: 8),
                    Text(
                      widget.album.artistDisplay,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _colors.primary,
                      ),
                    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildPlayAllButton(),
                        const SizedBox(width: 12),
                        _buildShuffleButton(),
                      ],
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                  ],
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
                        showAlbumArt: false,
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

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha:0.3),
            AppTheme.secondaryColor.withValues(alpha:0.3),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.album_rounded,
          size: 64,
          color: AppTheme.textMuted,
        ),
      ),
    );
  }

  Widget _buildPlayAllButton() {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: () async {
          final songs = await ref.read(songsByAlbumProvider(widget.album.id).future);
          if (songs.isNotEmpty) {
            ref.read(playerProvider.notifier).playSong(songs.first, songs);
          }
        },
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Play All'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _colors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }

  Widget _buildShuffleButton() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _colors.primary.withValues(alpha:0.2),
      ),
      child: IconButton(
        onPressed: () async {
          final songs = await ref.read(songsByAlbumProvider(widget.album.id).future);
          if (songs.isNotEmpty) {
            final shuffled = List.of(songs)..shuffle();
            ref.read(playerProvider.notifier).playSong(shuffled.first, shuffled);
          }
        },
        icon: Icon(Icons.shuffle_rounded, color: _colors.primary),
      ),
    );
  }
}
