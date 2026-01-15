import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/song.dart';
import '../../player/data/player_provider.dart';
import '../data/lyrics_service.dart';

class LyricsScreen extends ConsumerStatefulWidget {
  final Song song;

  const LyricsScreen({super.key, required this.song});

  @override
  ConsumerState<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends ConsumerState<LyricsScreen> {
  final ScrollController _scrollController = ScrollController();
  int _currentLineIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lyricsAsync = ref.watch(lyricsProvider(widget.song));
    final playerState = ref.watch(playerProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          children: [
            Text(
              widget.song.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.song.artistDisplay,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor.withValues(alpha:0.3),
              AppTheme.darkBackground,
              AppTheme.darkBackground,
            ],
          ),
        ),
        child: SafeArea(
          child: lyricsAsync.when(
            data: (lyrics) {
              if (lyrics == null || lyrics.lines.isEmpty) {
                return _buildNoLyrics();
              }
              return _buildLyricsView(lyrics, playerState.position);
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
            error: (error, stack) => _buildNoLyrics(),
          ),
        ),
      ),
    );
  }

  Widget _buildNoLyrics() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lyrics_outlined,
            size: 80,
            color: AppTheme.textMuted.withValues(alpha:0.5),
          ),
          const SizedBox(height: 24),
          const Text(
            'No lyrics found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Place a .lrc file with the same name\nas the audio file to see lyrics',
            style: TextStyle(
              color: AppTheme.textMuted.withValues(alpha:0.8),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildLyricsView(Lyrics lyrics, Duration position) {
    // Update current line index based on position
    if (lyrics.isSynced) {
      final newIndex = lyrics.getCurrentLineIndex(position) ?? -1;
      if (newIndex != _currentLineIndex) {
        _currentLineIndex = newIndex;
        _scrollToCurrentLine(newIndex, lyrics.lines.length);
      }
    }

    return lyrics.isSynced
        ? _buildSyncedLyrics(lyrics, position)
        : _buildPlainLyrics(lyrics);
  }

  Widget _buildSyncedLyrics(Lyrics lyrics, Duration position) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
      itemCount: lyrics.lines.length,
      itemBuilder: (context, index) {
        final line = lyrics.lines[index];
        final isCurrentLine = index == _currentLineIndex;
        final isPastLine = index < _currentLineIndex;

        return GestureDetector(
          onTap: () {
            // Seek to this line's timestamp
            ref.read(playerProvider.notifier).seek(line.timestamp);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              line.text,
              style: TextStyle(
                fontSize: isCurrentLine ? 28 : 20,
                fontWeight: isCurrentLine ? FontWeight.bold : FontWeight.w400,
                color: isCurrentLine
                    ? AppTheme.textPrimary
                    : isPastLine
                        ? AppTheme.textMuted.withValues(alpha:0.6)
                        : AppTheme.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlainLyrics(Lyrics lyrics) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.textMuted.withValues(alpha:0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Unsynchronized lyrics',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 32),
          ...lyrics.lines.map((line) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              line.text,
              style: const TextStyle(
                fontSize: 18,
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          )),
          const SizedBox(height: 100),
        ],
      ),
    ).animate().fadeIn();
  }

  void _scrollToCurrentLine(int index, int totalLines) {
    if (!_scrollController.hasClients || index < 0) return;

    // Calculate approximate position (each line is roughly 60 pixels)
    final lineHeight = 60.0;
    final targetOffset = (index * lineHeight) - (MediaQuery.of(context).size.height / 3);

    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }
}
