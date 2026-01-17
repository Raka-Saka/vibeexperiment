import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;
import 'package:on_audio_query/on_audio_query.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/dynamic_colors.dart';
import '../../../../services/sleep_timer_service.dart';
import '../../../../services/vibe_audio_service.dart';
import '../../../../shared/widgets/song_dialogs.dart';
import '../../../library/data/media_scanner.dart';
import '../../../settings/data/settings_provider.dart';
import '../../data/player_provider.dart';
import '../../../equalizer/presentation/equalizer_screen.dart';
import '../../../lyrics/presentation/lyrics_screen.dart';
import '../../../youtube/presentation/youtube_upload_screen.dart';
import '../widgets/shader_visualizer.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _rotationController;
  DynamicColors _colors = DynamicColors.defaultColors();

  // Auto-hide UI after inactivity
  bool _uiVisible = true;
  Timer? _hideTimer;
  static const _hideDelay = Duration(seconds: 4);

  // Lifecycle tracking for battery optimization
  bool _isAppInForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    _startHideTimer();
    // Enable AudioPulse FFT when entering this screen
    _setAudioPulseEnabled(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _rotationController.dispose();
    // Disable AudioPulse FFT when leaving this screen to save battery
    _setAudioPulseEnabled(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause visualizer when app goes to background to save battery
    final wasInForeground = _isAppInForeground;
    _isAppInForeground = state == AppLifecycleState.resumed;

    if (wasInForeground != _isAppInForeground) {
      // Enable/disable AudioPulse based on foreground state
      _setAudioPulseEnabled(_isAppInForeground);
      if (mounted) {
        setState(() {});
      }
    }
  }

  /// Enable or disable AudioPulse FFT analysis for battery optimization
  void _setAudioPulseEnabled(bool enabled) {
    vibeAudioService.setAudioPulseEnabled(enabled);
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDelay, () {
      if (mounted) {
        setState(() => _uiVisible = false);
      }
    });
  }

  void _showUI() {
    if (!_uiVisible) {
      setState(() => _uiVisible = true);
    }
    _startHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final song = playerState.currentSong;

    if (song == null) {
      return const Scaffold(
        body: Center(child: Text('No song playing')),
      );
    }

    final artworkAsync = ref.watch(
      artworkProvider((song.albumId ?? song.id, ArtworkType.AUDIO)),
    );

    // Extract colors from artwork - using ref.listen to avoid issues
    ref.listen(
      artworkProvider((song.albumId ?? song.id, ArtworkType.AUDIO)),
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

    // Control rotation based on playing state
    if (playerState.isPlaying) {
      _rotationController.repeat();
    } else {
      _rotationController.stop();
    }

    final settings = ref.watch(settingsProvider);
    // Show shader only when visualizer is enabled (for battery saving)
    final showShaderVisualizer = settings.visualizerEnabled && settings.isShaderVisualizer;

    return GestureDetector(
      onTap: _showUI,
      onPanDown: (_) => _showUI(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Background layer - shader (when enabled) or static gradient (battery saver)
            if (showShaderVisualizer)
              // Full-screen shader visualizer background
              // Only run visualizer when playing AND app is in foreground (battery optimization)
              _buildShaderBackground(playerState.isPlaying && _isAppInForeground, settings.visualizerStyle)
            else ...[
              // Animated gradient background
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                decoration: BoxDecoration(
                  gradient: _colors.gradient,
                ),
              ),
              // Blur overlay
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(
                  color: Colors.black.withValues(alpha:0.3),
                ),
              ),
            ],

            // Dark overlay for readability when shader is active - fades with UI
            if (showShaderVisualizer)
              AnimatedOpacity(
                opacity: _uiVisible ? 0.25 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: Container(color: Colors.black),
              ),

            // Content - fades in/out
            AnimatedOpacity(
              opacity: _uiVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              child: SafeArea(
                child: Column(
                  children: [
                    // Header
                    _buildHeader(context),

                    const Spacer(),

                    // Album art
                    _buildAlbumArt(artworkAsync),

                    const Spacer(),

                    // Song info
                    _buildSongInfo(song),

                    const SizedBox(height: 32),

                    // Progress bar
                    _buildProgressBar(playerState),

                    const SizedBox(height: 24),

                    // Playback controls
                    _buildControls(playerState),

                    const SizedBox(height: 24),

                    // Additional controls
                    _buildAdditionalControls(playerState),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          Column(
            children: [
              const Text(
                'NOW PLAYING',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: AppTheme.textMuted,
                ),
              ),
              Text(
                'From Library',
                style: TextStyle(
                  fontSize: 14,
                  color: _colors.primary,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => _showOptionsSheet(context),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2);
  }

  Widget _buildShaderBackground(bool isPlaying, VisualizerStyleSetting style) {
    final shaderType = switch (style) {
      VisualizerStyleSetting.resonance => ShaderVisualizerType.resonance,
      VisualizerStyleSetting.ripples => ShaderVisualizerType.ripples,
      VisualizerStyleSetting.lissajous => ShaderVisualizerType.lissajous,
      VisualizerStyleSetting.neonRings => ShaderVisualizerType.neonRings,
      VisualizerStyleSetting.aurora => ShaderVisualizerType.aurora,
      VisualizerStyleSetting.spirograph => ShaderVisualizerType.spirograph,
      VisualizerStyleSetting.voronoi => ShaderVisualizerType.voronoi,
      VisualizerStyleSetting.phyllotaxis => ShaderVisualizerType.phyllotaxis,
      VisualizerStyleSetting.attractors => ShaderVisualizerType.attractors,
      VisualizerStyleSetting.moire => ShaderVisualizerType.moire,
      VisualizerStyleSetting.pendulum => ShaderVisualizerType.pendulum,
      VisualizerStyleSetting.fractalFlames => ShaderVisualizerType.fractalFlames,
      VisualizerStyleSetting.mandelbrot => ShaderVisualizerType.mandelbrot,
      // Pendulum variations
      VisualizerStyleSetting.pendulumCircular => ShaderVisualizerType.pendulumCircular,
      VisualizerStyleSetting.pendulumCradle => ShaderVisualizerType.pendulumCradle,
      VisualizerStyleSetting.pendulumMetronome => ShaderVisualizerType.pendulumMetronome,
      VisualizerStyleSetting.pendulumDouble => ShaderVisualizerType.pendulumDouble,
      VisualizerStyleSetting.pendulumLissajous => ShaderVisualizerType.pendulumLissajous,
      VisualizerStyleSetting.pendulumSpring => ShaderVisualizerType.pendulumSpring,
      VisualizerStyleSetting.pendulumFirefly => ShaderVisualizerType.pendulumFirefly,
      VisualizerStyleSetting.pendulumWave => ShaderVisualizerType.pendulumWave,
      VisualizerStyleSetting.pendulumMirror => ShaderVisualizerType.pendulumMirror,
    };

    return ShaderVisualizer(
      type: shaderType,
      isPlaying: isPlaying,
      width: double.infinity,
      height: double.infinity,
    );
  }

  Widget _buildAlbumArt(AsyncValue<dynamic> artworkAsync) {
    // All visualizers are now shader-based (full-screen background)
    // This widget handles tap gestures for visualizer cycling
    return GestureDetector(
      onTap: () {
        // Cycle through visualizer styles on tap
        ref.read(settingsProvider.notifier).cycleVisualizerStyle();
        // Show feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Visualizer: ${ref.read(settingsProvider).visualizerStyleLabel}'),
            duration: const Duration(milliseconds: 800),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      },
      onLongPress: () => _showVisualizerPicker(context),
      child: const SizedBox.shrink(),
    ).animate().scale(
      duration: 600.ms,
      curve: Curves.easeOutBack,
    );
  }

  void _showVisualizerPicker(BuildContext context) async {
    final settings = ref.read(settingsProvider);

    if (!mounted) return;

    // All visualizer styles (GPU shader-based)
    final visualizerStyles = VisualizerStyleSetting.values;

    IconData getIcon(VisualizerStyleSetting style) {
      return switch (style) {
        VisualizerStyleSetting.resonance => Icons.graphic_eq_rounded,
        VisualizerStyleSetting.ripples => Icons.water_drop_rounded,
        VisualizerStyleSetting.lissajous => Icons.show_chart_rounded,
        VisualizerStyleSetting.neonRings => Icons.lens_blur_rounded,
        VisualizerStyleSetting.aurora => Icons.nights_stay_rounded,
        VisualizerStyleSetting.spirograph => Icons.motion_photos_on_rounded,
        VisualizerStyleSetting.voronoi => Icons.blur_on_rounded,
        VisualizerStyleSetting.phyllotaxis => Icons.local_florist_rounded,
        VisualizerStyleSetting.attractors => Icons.all_inclusive_rounded,
        VisualizerStyleSetting.moire => Icons.blur_circular_rounded,
        VisualizerStyleSetting.pendulum => Icons.swap_vert_rounded,
        VisualizerStyleSetting.fractalFlames => Icons.local_fire_department_rounded,
        VisualizerStyleSetting.mandelbrot => Icons.auto_awesome_rounded,
        // Pendulum variations
        VisualizerStyleSetting.pendulumCircular => Icons.radio_button_unchecked_rounded,
        VisualizerStyleSetting.pendulumCradle => Icons.sports_baseball_rounded,
        VisualizerStyleSetting.pendulumMetronome => Icons.timer_rounded,
        VisualizerStyleSetting.pendulumDouble => Icons.link_rounded,
        VisualizerStyleSetting.pendulumLissajous => Icons.beach_access_rounded,
        VisualizerStyleSetting.pendulumSpring => Icons.expand_rounded,
        VisualizerStyleSetting.pendulumFirefly => Icons.auto_awesome_rounded,
        VisualizerStyleSetting.pendulumWave => Icons.waves_rounded,
        VisualizerStyleSetting.pendulumMirror => Icons.flip_rounded,
      };
    }

    String getLabel(VisualizerStyleSetting style) {
      return switch (style) {
        VisualizerStyleSetting.resonance => 'Resonance',
        VisualizerStyleSetting.ripples => 'Ripples',
        VisualizerStyleSetting.lissajous => 'Harmonograph',
        VisualizerStyleSetting.neonRings => 'Celestial Halos',
        VisualizerStyleSetting.aurora => 'Aurora',
        VisualizerStyleSetting.spirograph => 'Spirograph',
        VisualizerStyleSetting.voronoi => 'Voronoi',
        VisualizerStyleSetting.phyllotaxis => 'Sunflower',
        VisualizerStyleSetting.attractors => 'Attractors',
        VisualizerStyleSetting.moire => 'Moiré',
        VisualizerStyleSetting.pendulum => 'Pendulum',
        VisualizerStyleSetting.fractalFlames => 'Flames',
        VisualizerStyleSetting.mandelbrot => 'Fractal',
        // Pendulum variations
        VisualizerStyleSetting.pendulumCircular => 'Circular',
        VisualizerStyleSetting.pendulumCradle => 'Newton\'s Cradle',
        VisualizerStyleSetting.pendulumMetronome => 'Metronome',
        VisualizerStyleSetting.pendulumDouble => 'Double',
        VisualizerStyleSetting.pendulumLissajous => 'Sand',
        VisualizerStyleSetting.pendulumSpring => 'Spring',
        VisualizerStyleSetting.pendulumFirefly => 'Firefly',
        VisualizerStyleSetting.pendulumWave => 'Wave',
        VisualizerStyleSetting.pendulumMirror => 'Mirror',
      };
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget buildChip(VisualizerStyleSetting style) {
              final isSelected = settings.visualizerStyle == style;
              return FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(getIcon(style), size: 16, color: isSelected ? Colors.white : AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(getLabel(style)),
                  ],
                ),
                selected: isSelected,
                selectedColor: _colors.primary,
                checkmarkColor: Colors.white,
                onSelected: (selected) {
                  ref.read(settingsProvider.notifier).setVisualizerStyle(style);
                  Navigator.pop(sheetContext);
                },
              );
            }

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.graphic_eq_rounded, color: _colors.primary),
                      const SizedBox(width: 12),
                      Text(
                        'Visualizer Style',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // All visualizers are GPU shader-based
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: visualizerStyles.map(buildChip).toList(),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tap album art to cycle visualizers',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSongInfo(song) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Text(
            song.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
          const SizedBox(height: 8),
          Text(
            song.artistDisplay,
            style: TextStyle(
              fontSize: 16,
              color: _colors.primary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
        ],
      ),
    );
  }

  Widget _buildProgressBar(AppPlayerState playerState) {
    final position = playerState.position;
    final duration = playerState.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _colors.primary,
              inactiveTrackColor: Colors.white.withValues(alpha:0.2),
              thumbColor: _colors.primary,
              overlayColor: _colors.primary.withValues(alpha:0.2),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (value) {
                final newPosition = Duration(
                  milliseconds: (value * duration.inMilliseconds).round(),
                );
                ref.read(playerProvider.notifier).seek(newPosition);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(position),
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildControls(AppPlayerState playerState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Shuffle
          IconButton(
            icon: Icon(
              Icons.shuffle_rounded,
              color: playerState.shuffleMode
                  ? _colors.primary
                  : AppTheme.textMuted,
            ),
            iconSize: 28,
            onPressed: () {
              ref.read(playerProvider.notifier).toggleShuffle();
            },
          ),

          // Previous
          IconButton(
            icon: const Icon(Icons.skip_previous_rounded),
            iconSize: 40,
            color: AppTheme.textPrimary,
            onPressed: () {
              ref.read(playerProvider.notifier).skipToPrevious();
            },
          ),

          // Play/Pause
          GestureDetector(
            onTap: () {
              ref.read(playerProvider.notifier).togglePlayPause();
            },
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _colors.primary,
                    _colors.secondary,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _colors.primary.withValues(alpha:0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                playerState.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 40,
                color: Colors.white,
              ),
            ).animate().scale(
              duration: 200.ms,
              curve: Curves.easeOut,
            ),
          ),

          // Next
          IconButton(
            icon: const Icon(Icons.skip_next_rounded),
            iconSize: 40,
            color: AppTheme.textPrimary,
            onPressed: () {
              ref.read(playerProvider.notifier).skipToNext();
            },
          ),

          // Repeat
          IconButton(
            icon: Icon(
              _getRepeatIcon(playerState.loopMode),
              color: playerState.loopMode != LoopMode.off
                  ? _colors.primary
                  : AppTheme.textMuted,
            ),
            iconSize: 28,
            onPressed: () {
              ref.read(playerProvider.notifier).cycleRepeatMode();
            },
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2);
  }

  Widget _buildAdditionalControls(AppPlayerState playerState) {
    final eqState = ref.watch(equalizerProvider);
    final settings = ref.watch(settingsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Equalizer
          _buildControlButton(
            icon: Icons.equalizer_rounded,
            label: 'EQ',
            isActive: eqState.isEnabled,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EqualizerScreen(),
                ),
              );
            },
          ),

          // Visualizer
          _buildControlButton(
            icon: Icons.graphic_eq_rounded,
            label: 'Visual',
            isActive: settings.visualizerEnabled,
            onTap: () => _showVisualizerPicker(context),
          ),

          // Lyrics
          _buildControlButton(
            icon: Icons.lyrics_rounded,
            label: 'Lyrics',
            onTap: () {
              final song = playerState.currentSong;
              if (song != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LyricsScreen(song: song),
                  ),
                );
              }
            },
          ),

          // Queue
          _buildControlButton(
            icon: Icons.queue_music_rounded,
            label: 'Queue',
            onTap: () {
              _showQueueSheet(context);
            },
          ),

          // Spatial
          _buildControlButton(
            icon: Icons.spatial_audio_rounded,
            label: 'Spatial',
            isActive: eqState.spatialAudioEnabled,
            onTap: () {
              ref.read(equalizerProvider.notifier).toggleSpatialAudio();
            },
          ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms);
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isActive
                  ? _colors.primary.withValues(alpha:0.3)
                  : Colors.white.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(12),
              border: isActive
                  ? Border.all(color: _colors.primary.withValues(alpha:0.5), width: 1)
                  : null,
            ),
            child: Icon(
              icon,
              color: isActive ? _colors.primary : AppTheme.textSecondary,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? _colors.primary : AppTheme.textMuted,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getRepeatIcon(LoopMode mode) {
    switch (mode) {
      case LoopMode.off:
        return Icons.repeat_rounded;
      case LoopMode.all:
        return Icons.repeat_rounded;
      case LoopMode.one:
        return Icons.repeat_one_rounded;
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _showOptionsSheet(BuildContext context) {
    final song = ref.read(playerProvider).currentSong;
    if (song == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: const Text('Add to Playlist'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showAddToPlaylistDialog(context, ref, song);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  shareSong(context, song);
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer_rounded),
                title: const Text('Sleep Timer'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showSleepTimerDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Song Info'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showSongInfoDialog(context, song);
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload_rounded, color: Colors.red),
                title: const Text('Upload to YouTube', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => YouTubeUploadScreen(song: song),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSleepTimerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final currentState = ref.watch(sleepTimerProvider);

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.timer_rounded,
                        color: currentState.isActive
                            ? _colors.primary
                            : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Sleep Timer',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      if (currentState.isActive)
                        TextButton(
                          onPressed: () {
                            ref.read(sleepTimerProvider.notifier).cancel();
                          },
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (currentState.isActive) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _colors.primary.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.bedtime_rounded,
                            color: _colors.primary,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Timer Active',
                                style: TextStyle(
                                  color: _colors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${currentState.remainingFormatted} remaining',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              ref.read(sleepTimerProvider.notifier).addTime(
                                const Duration(minutes: 5),
                              );
                            },
                            child: const Text('+5 min'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              ref.read(sleepTimerProvider.notifier).addTime(
                                const Duration(minutes: 10),
                              );
                            },
                            child: const Text('+10 min'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Text(
                      'Stop playback after:',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: SleepTimerPresets.all.map((preset) {
                        return ActionChip(
                          label: Text(preset.$1),
                          onPressed: () {
                            ref.read(sleepTimerProvider.notifier).start(preset.$2);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Sleep timer set for ${preset.$1}'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          backgroundColor: AppTheme.darkSurface,
                          labelStyle: const TextStyle(color: AppTheme.textPrimary),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showQueueSheet(BuildContext context) {
    final playerState = ref.read(playerProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        'Queue',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      Text(
                        '${playerState.queue.length} songs',
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: playerState.queue.length,
                    itemBuilder: (context, index) {
                      final song = playerState.queue[index];
                      final isCurrentSong = index == playerState.currentIndex;

                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: isCurrentSong
                                ? _colors.primary.withValues(alpha:0.2)
                                : AppTheme.darkSurface,
                          ),
                          child: Center(
                            child: isCurrentSong
                                ? Icon(
                                    Icons.equalizer_rounded,
                                    color: _colors.primary,
                                    size: 20,
                                  )
                                : Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                          ),
                        ),
                        title: Text(
                          song.title,
                          style: TextStyle(
                            color: isCurrentSong
                                ? _colors.primary
                                : AppTheme.textPrimary,
                            fontWeight: isCurrentSong
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          song.artistDisplay,
                          style: const TextStyle(color: AppTheme.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () async {
                          await ref.read(playerProvider.notifier).playSong(
                            song,
                            playerState.queue,
                          );
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
