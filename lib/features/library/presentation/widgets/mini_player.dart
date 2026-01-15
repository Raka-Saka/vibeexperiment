import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../player/data/player_provider.dart';
import '../../../player/presentation/screens/now_playing_screen.dart';
import '../../data/media_scanner.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final song = playerState.currentSong;

    if (song == null) return const SizedBox.shrink();

    final progress = ref.watch(progressProvider);
    final artworkAsync = ref.watch(
      artworkProvider((song.albumId ?? song.id, ArtworkType.AUDIO)),
    );

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) {
              return const NowPlayingScreen();
            },
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              );
            },
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppTheme.darkCard,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                minHeight: 2,
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Album art
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withValues(alpha: 0.3),
                          AppTheme.secondaryColor.withValues(alpha: 0.3),
                        ],
                      ),
                    ),
                    child: artworkAsync.when(
                      data: (bytes) {
                        if (bytes != null) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(bytes, fit: BoxFit.cover),
                          );
                        }
                        return const Icon(
                          Icons.music_note_rounded,
                          color: AppTheme.textMuted,
                        );
                      },
                      loading: () => const SizedBox(),
                      error: (_, __) => const Icon(
                        Icons.music_note_rounded,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Song info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song.title,
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
                          song.artistDisplay,
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

                  // Controls
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded),
                        color: AppTheme.textPrimary,
                        iconSize: 28,
                        onPressed: () {
                          ref.read(playerProvider.notifier).skipToPrevious();
                        },
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.secondaryColor,
                            ],
                          ),
                        ),
                        child: IconButton(
                          icon: Icon(
                            playerState.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                          color: Colors.white,
                          iconSize: 24,
                          onPressed: () {
                            ref.read(playerProvider.notifier).togglePlayPause();
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded),
                        color: AppTheme.textPrimary,
                        iconSize: 28,
                        onPressed: () {
                          ref.read(playerProvider.notifier).skipToNext();
                        },
                      ),
                    ],
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
