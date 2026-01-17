import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/audio_handler.dart';
import '../../equalizer/presentation/equalizer_screen.dart';
import '../../statistics/presentation/statistics_screen.dart';
import '../../library/data/media_scanner.dart';
import '../../library/presentation/screens/genre_classifier_screen.dart';
import '../../tag_editor/data/tag_editor_service.dart';
import '../data/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navSettings),
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Audio section
            _buildSectionHeader(context, l10n.settingsSectionAudio),
            _buildSettingsTile(
              context,
              icon: Icons.equalizer_rounded,
              title: l10n.settingsEqualizer,
              subtitle: l10n.settingsEqualizerSubtitle,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EqualizerScreen(),
                  ),
                );
              },
            ),
            _buildSettingsTile(
              context,
              icon: Icons.speed_rounded,
              title: l10n.settingsPlaybackSpeed,
              subtitle: settings.playbackSpeedLabel,
              onTap: () => _showPlaybackSpeedDialog(context, ref, settings),
            ),
            _buildSettingsTile(
              context,
              icon: Icons.graphic_eq_rounded,
              title: l10n.settingsAudioQuality,
              subtitle: l10n.settingsAudioQualityHigh,
              trailing: Icon(
                Icons.check_circle_rounded,
                color: AppTheme.primaryColor,
              ),
              onTap: () => _showAudioQualityInfo(context),
            ),
            _buildSettingsTile(
              context,
              icon: Icons.compare_arrows_rounded,
              title: l10n.settingsGaplessPlayback,
              subtitle: l10n.settingsGaplessPlaybackSubtitle,
              trailing: Icon(
                Icons.check_circle_rounded,
                color: AppTheme.primaryColor,
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.toastGaplessAlwaysEnabled),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            _buildSettingsTile(
              context,
              icon: Icons.shuffle_rounded,
              title: l10n.settingsCrossfade,
              subtitle: _getCrossfadeModeLabel(settings),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textMuted,
              ),
              onTap: () => _showCrossfadeDialog(context, ref, settings),
            ),
            _buildSettingsTile(
              context,
              icon: Icons.volume_up_rounded,
              title: l10n.settingsNormalization,
              subtitle: settings.normalizationModeLabel,
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textMuted,
              ),
              onTap: () => _showNormalizationDialog(context, ref, settings),
            ),
            _buildSettingsTile(
              context,
              icon: Icons.spatial_audio_rounded,
              title: l10n.settingsReverb,
              subtitle: settings.reverbLabel,
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textMuted,
              ),
              onTap: () => _showReverbDialog(context, ref, settings),
            ),
            _buildSettingsTile(
              context,
              icon: Icons.music_note_rounded,
              title: l10n.settingsPitch,
              subtitle: settings.pitchLabel,
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textMuted,
              ),
              onTap: () => _showPitchDialog(context, ref, settings),
            ),

            const SizedBox(height: 24),

            // Library section
            _buildSectionHeader(context, l10n.settingsSectionLibrary),
            _buildSettingsTile(
              context,
              icon: Icons.bar_chart_rounded,
              title: l10n.settingsStatistics,
              subtitle: l10n.settingsStatisticsSubtitle,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StatisticsScreen(),
                  ),
                );
              },
            ),
            _buildSettingsTile(
              context,
              icon: Icons.auto_awesome,
              title: l10n.settingsAiGenre,
              subtitle: l10n.settingsAiGenreSubtitle,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GenreClassifierScreen(),
                  ),
                );
              },
            ),
            _buildSettingsTile(
              context,
              icon: Icons.folder_rounded,
              title: l10n.settingsRescan,
              subtitle: l10n.settingsRescanSubtitle,
              onTap: () => _rescanLibrary(context, ref),
            ),
            _buildSettingsTile(
              context,
              icon: Icons.cleaning_services_rounded,
              title: l10n.settingsClearCache,
              subtitle: l10n.settingsClearCacheSubtitle,
              onTap: () => _clearLibraryCache(context, ref),
            ),
            _buildSettingsTile(
              context,
              icon: Icons.sort_rounded,
              title: l10n.settingsDefaultSort,
              subtitle: settings.sortOrderLabel,
              onTap: () => _showSortDialog(context, ref, settings),
            ),
            _buildSettingsTile(
              context,
              icon: settings.sortAscending
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              title: l10n.settingsSortDirection,
              subtitle: settings.sortAscending ? l10n.settingsSortAscending : l10n.settingsSortDescending,
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(settingsProvider.notifier).toggleSortAscending();
              },
            ),
            _buildSettingsTile(
              context,
              icon: Icons.comment_rounded,
              title: l10n.settingsStripComments,
              subtitle: settings.stripCommentsOnImport
                  ? l10n.settingsStripCommentsEnabled
                  : l10n.commonDisabled,
              trailing: Switch(
                value: settings.stripCommentsOnImport,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  ref.read(settingsProvider.notifier).setStripCommentsOnImport(value);
                },
                activeColor: AppTheme.primaryColor,
              ),
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(settingsProvider.notifier).setStripCommentsOnImport(
                  !settings.stripCommentsOnImport,
                );
              },
            ),
            _buildSettingsTile(
              context,
              icon: Icons.cleaning_services_rounded,
              title: l10n.settingsStripCommentsLibrary,
              subtitle: l10n.settingsStripCommentsLibrarySubtitle,
              onTap: () => _stripCommentsFromLibrary(context, ref),
            ),

            const SizedBox(height: 24),

            // Appearance section
            _buildSectionHeader(context, l10n.settingsSectionAppearance),
            _buildSettingsTile(
              context,
              icon: Icons.palette_rounded,
              title: l10n.settingsTheme,
              subtitle: l10n.settingsThemeDark,
              onTap: () => _showThemeInfo(context),
            ),
            _buildSettingsTile(
              context,
              icon: Icons.color_lens_rounded,
              title: l10n.settingsDynamicColors,
              subtitle: l10n.settingsDynamicColorsSubtitle,
              trailing: Icon(
                Icons.schedule_rounded,
                color: AppTheme.textMuted,
              ),
              onTap: () {
                _showComingSoonInfo(context, l10n.settingsDynamicColors, l10n.settingsDynamicColorsDescription);
              },
            ),
            _buildSettingsTile(
              context,
              icon: Icons.animation_rounded,
              title: l10n.settingsVisualizer,
              subtitle: settings.visualizerEnabled
                  ? l10n.settingsVisualizerEnabled
                  : l10n.settingsVisualizerDisabled,
              trailing: Switch(
                value: settings.visualizerEnabled,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).setVisualizerEnabled(value);
                },
                activeColor: AppTheme.primaryColor,
              ),
              onTap: () {
                ref.read(settingsProvider.notifier).setVisualizerEnabled(!settings.visualizerEnabled);
              },
            ),

            const SizedBox(height: 24),

            // About section
            _buildSectionHeader(context, l10n.settingsSectionAbout),
            _buildSettingsTile(
              context,
              icon: Icons.info_rounded,
              title: l10n.settingsAppVersion,
              subtitle: '1.0.0 (Build 1)',
              onTap: () {},
            ),
            _buildSettingsTile(
              context,
              icon: Icons.code_rounded,
              title: l10n.settingsLicenses,
              subtitle: l10n.settingsLicensesSubtitle,
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'VibePlay',
                applicationVersion: '1.0.0',
              ),
            ),
            _buildSettingsTile(
              context,
              icon: Icons.restore_rounded,
              title: l10n.settingsReset,
              subtitle: l10n.settingsResetSubtitle,
              onTap: () => _confirmResetSettings(context, ref),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8, top: 8),
      child: Text(
        title,
        style: TextStyle(
          color: AppTheme.primaryColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: AppTheme.primaryColor,
            size: 22,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 12,
          ),
        ),
        trailing: trailing ?? const Icon(
          Icons.chevron_right_rounded,
          color: AppTheme.textMuted,
        ),
        onTap: onTap,
      ),
    ).animate().fadeIn().slideX(begin: 0.05);
  }

  void _showPlaybackSpeedDialog(BuildContext context, WidgetRef ref, AppSettings settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Playback Speed',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...playbackSpeeds.map((speed) {
              final isSelected = settings.playbackSpeed == speed;
              return ListTile(
                leading: isSelected
                    ? const Icon(Icons.check, color: AppTheme.primaryColor)
                    : const SizedBox(width: 24),
                title: Text(
                  '${speed}x',
                  style: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                subtitle: speed == 1.0 ? const Text('Normal') : null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(settingsProvider.notifier).setPlaybackSpeed(speed);
                  audioHandler.setPlaybackSpeed(speed);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showSortDialog(BuildContext context, WidgetRef ref, AppSettings settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sort Songs By',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...SortOrder.values.map((order) {
              final isSelected = settings.defaultSort == order;
              String title;
              IconData icon;
              switch (order) {
                case SortOrder.title:
                  title = 'Title';
                  icon = Icons.sort_by_alpha_rounded;
                case SortOrder.artist:
                  title = 'Artist';
                  icon = Icons.person_rounded;
                case SortOrder.album:
                  title = 'Album';
                  icon = Icons.album_rounded;
                case SortOrder.dateAdded:
                  title = 'Date Added';
                  icon = Icons.calendar_today_rounded;
                case SortOrder.duration:
                  title = 'Duration';
                  icon = Icons.timer_rounded;
              }
              return ListTile(
                leading: Icon(
                  icon,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: AppTheme.primaryColor)
                    : null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(settingsProvider.notifier).setDefaultSort(order);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _stripCommentsFromLibrary(BuildContext context, WidgetRef ref) async {
    // Check for manage storage permission first (Android 11+)
    final hasPermission = await TagEditorService.hasManageStoragePermission();
    if (!hasPermission) {
      if (!context.mounted) return;
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.darkCard,
          title: const Text('Permission Required'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('To modify music files, VibePlay needs "All files access" permission.'),
              SizedBox(height: 12),
              Text(
                'Tap "Open Settings" and enable "Allow access to manage all files".',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );

      if (shouldOpenSettings == true) {
        await TagEditorService.openManageStorageSettings();
      }
      return;
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Strip Comments'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will remove all comment metadata from MP3 files in your library.'),
            SizedBox(height: 12),
            Text(
              'Only MP3 files are supported. This action cannot be undone.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _performStripComments(context, ref);
            },
            icon: const Icon(Icons.cleaning_services, size: 18),
            label: const Text('Strip Comments'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performStripComments(BuildContext context, WidgetRef ref) async {
    // Show progress indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 16),
            Text('Stripping comments from library...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      // Get all songs from library
      final songs = await ref.read(songsProvider.future);
      final tagService = TagEditorService();
      final scanner = ref.read(mediaScannerProvider);

      // Filter to MP3 files only
      final mp3Songs = songs.where((s) =>
        s.path != null && tagService.isFormatSupported(s.path)
      ).toList();

      if (mp3Songs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No MP3 files found in library'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      int successCount = 0;
      int errorCount = 0;

      // Process each file
      for (final song in mp3Songs) {
        if (song.path != null) {
          final result = await tagService.removeCommentFrames(song.path!);
          if (result.success) {
            successCount++;
            // Rescan file to update MediaStore
            await scanner.rescanFile(song.path!);
          } else {
            errorCount++;
          }
        }
      }

      // Invalidate library to refresh
      ref.invalidate(songsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorCount == 0
                  ? 'Stripped comments from $successCount files'
                  : 'Stripped comments from $successCount files ($errorCount errors)',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _clearLibraryCache(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Clear Library Cache'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will reset the library database. Your music files will NOT be deleted.'),
            SizedBox(height: 12),
            Text(
              'The library will be rebuilt on next scan.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);

              // Clear the media scanner cache
              final scanner = ref.read(mediaScannerProvider);
              scanner.invalidateCache();

              // Invalidate all library providers
              ref.invalidate(songsProvider);
              ref.invalidate(albumsProvider);
              ref.invalidate(artistsProvider);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Library cache cleared. Rescanning...'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.cleaning_services, size: 18),
            label: const Text('Clear Cache'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _rescanLibrary(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Rescan Library'),
        content: const Text(
          'This will scan your device for new music files. Existing library will be refreshed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              // Show scanning indicator
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 16),
                      Text('Scanning for music...'),
                    ],
                  ),
                  duration: Duration(seconds: 3),
                ),
              );

              // Invalidate all library providers to trigger rescan
              ref.invalidate(songsProvider);
              ref.invalidate(albumsProvider);
              ref.invalidate(artistsProvider);

              // Wait a bit then show completion
              await Future.delayed(const Duration(seconds: 2));

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Library scan complete!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Scan'),
          ),
        ],
      ),
    );
  }

  String _getCrossfadeModeLabel(AppSettings settings) {
    switch (settings.crossfadeMode) {
      case CrossfadeMode.off:
        return 'Off';
      case CrossfadeMode.fixed:
        return 'Fixed (${settings.crossfadeDuration}s)';
      case CrossfadeMode.smart:
        return 'Smart (${settings.crossfadeDuration}s)';
    }
  }

  void _showCrossfadeDialog(BuildContext context, WidgetRef ref, AppSettings settings) {
    // Initialize outside StatefulBuilder so they're captured by closure (not re-initialized on rebuild)
    int duration = settings.crossfadeDuration;
    CrossfadeMode mode = settings.crossfadeMode;

    const animDuration = Duration(milliseconds: 200);
    const animCurve = Curves.easeOutCubic;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final showDuration = mode != CrossfadeMode.off;
          final showSmartInfo = mode == CrossfadeMode.smart;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Crossfade',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Smoothly blend between songs',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 20),

                // Mode selection
                Text(
                  'Mode',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ...CrossfadeMode.values.map((m) {
                  final isSelected = mode == m;
                  String title;
                  String subtitle;
                  IconData icon;

                  switch (m) {
                    case CrossfadeMode.off:
                      title = 'Off';
                      subtitle = 'No crossfade between tracks';
                      icon = Icons.stop_rounded;
                    case CrossfadeMode.fixed:
                      title = 'Fixed';
                      subtitle = 'Fade at fixed time before track ends';
                      icon = Icons.timer_rounded;
                    case CrossfadeMode.smart:
                      title = 'Smart';
                      subtitle = 'Detect silence, skip live albums, sync to BPM';
                      icon = Icons.auto_awesome_rounded;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => mode = m);
                          ref.read(settingsProvider.notifier).setCrossfadeMode(m);
                        },
                        child: AnimatedContainer(
                          duration: animDuration,
                          curve: animCurve,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor.withValues(alpha:0.15)
                                : AppTheme.darkSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: animDuration,
                                curve: animCurve,
                                child: Icon(
                                  icon,
                                  color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AnimatedDefaultTextStyle(
                                      duration: animDuration,
                                      curve: animCurve,
                                      style: TextStyle(
                                        color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        fontSize: 16,
                                      ),
                                      child: Text(title),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      style: TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedOpacity(
                                duration: animDuration,
                                curve: animCurve,
                                opacity: isSelected ? 1.0 : 0.0,
                                child: AnimatedScale(
                                  duration: animDuration,
                                  curve: animCurve,
                                  scale: isSelected ? 1.0 : 0.5,
                                  child: Icon(Icons.check_circle, color: AppTheme.primaryColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                // Duration slider with animated appearance
                AnimatedSize(
                  duration: animDuration,
                  curve: animCurve,
                  child: AnimatedOpacity(
                    duration: animDuration,
                    curve: animCurve,
                    opacity: showDuration ? 1.0 : 0.0,
                    child: showDuration
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Text(
                                    'Duration',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 150),
                                    child: Text(
                                      '$duration sec',
                                      key: ValueKey(duration),
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                                ),
                                child: Slider(
                                  value: duration.toDouble(),
                                  min: 1,
                                  max: 12,
                                  divisions: 11,
                                  activeColor: AppTheme.primaryColor,
                                  inactiveColor: AppTheme.primaryColor.withValues(alpha:0.2),
                                  onChanged: (value) {
                                    setState(() => duration = value.round());
                                  },
                                  onChangeEnd: (value) {
                                    ref.read(settingsProvider.notifier).setCrossfadeDuration(value.round());
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('1s', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                    Text('Quick', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                    Text('Smooth', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                    Text('12s', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                  ],
                                ),
                              ),
                              // Smart mode info with animated appearance
                              AnimatedSize(
                                duration: animDuration,
                                curve: animCurve,
                                child: AnimatedOpacity(
                                  duration: animDuration,
                                  curve: animCurve,
                                  opacity: showSmartInfo ? 1.0 : 0.0,
                                  child: showSmartInfo
                                      ? Padding(
                                          padding: const EdgeInsets.only(top: 12),
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor.withValues(alpha:0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.info_outline_rounded,
                                                  color: AppTheme.primaryColor,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Smart mode adjusts timing based on track endings and skips crossfade for live albums',
                                                    style: TextStyle(
                                                      color: AppTheme.textSecondary,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showNormalizationDialog(BuildContext context, WidgetRef ref, AppSettings settings) {
    // Initialize outside StatefulBuilder so they're captured by closure
    NormalizationMode mode = settings.normalizationMode;
    double targetLoudness = settings.targetLoudness;
    bool preventClipping = settings.preventClipping;

    const animDuration = Duration(milliseconds: 200);
    const animCurve = Curves.easeOutCubic;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final showOptions = mode != NormalizationMode.off;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Volume Normalization',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Balance volume levels across songs',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 20),

                // Mode selection
                Text(
                  'Mode',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ...NormalizationMode.values.map((m) {
                  final isSelected = mode == m;
                  String title;
                  String subtitle;
                  IconData icon;

                  switch (m) {
                    case NormalizationMode.off:
                      title = 'Off';
                      subtitle = 'No volume adjustment';
                      icon = Icons.volume_off_rounded;
                    case NormalizationMode.track:
                      title = 'Track';
                      subtitle = 'Normalize each song individually';
                      icon = Icons.music_note_rounded;
                    case NormalizationMode.album:
                      title = 'Album';
                      subtitle = 'Preserve relative loudness within albums';
                      icon = Icons.album_rounded;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => mode = m);
                          ref.read(settingsProvider.notifier).setNormalizationMode(m);
                        },
                        child: AnimatedContainer(
                          duration: animDuration,
                          curve: animCurve,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor.withValues(alpha:0.15)
                                : AppTheme.darkSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                icon,
                                color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AnimatedDefaultTextStyle(
                                      duration: animDuration,
                                      curve: animCurve,
                                      style: TextStyle(
                                        color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        fontSize: 16,
                                      ),
                                      child: Text(title),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      style: TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedOpacity(
                                duration: animDuration,
                                curve: animCurve,
                                opacity: isSelected ? 1.0 : 0.0,
                                child: AnimatedScale(
                                  duration: animDuration,
                                  curve: animCurve,
                                  scale: isSelected ? 1.0 : 0.5,
                                  child: Icon(Icons.check_circle, color: AppTheme.primaryColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                // Options (only show if not off)
                AnimatedSize(
                  duration: animDuration,
                  curve: animCurve,
                  child: AnimatedOpacity(
                    duration: animDuration,
                    curve: animCurve,
                    opacity: showOptions ? 1.0 : 0.0,
                    child: showOptions
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Text(
                                    'Target Loudness',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 150),
                                    child: Text(
                                      '${targetLoudness.toStringAsFixed(0)} LUFS',
                                      key: ValueKey(targetLoudness.toStringAsFixed(0)),
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                                ),
                                child: Slider(
                                  value: targetLoudness,
                                  min: -24,
                                  max: -6,
                                  divisions: 18,
                                  activeColor: AppTheme.primaryColor,
                                  inactiveColor: AppTheme.primaryColor.withValues(alpha:0.2),
                                  onChanged: (value) {
                                    setState(() => targetLoudness = value);
                                  },
                                  onChangeEnd: (value) {
                                    ref.read(settingsProvider.notifier).setTargetLoudness(value);
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Quieter', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                    Text('-14 (Standard)', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                    Text('Louder', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => preventClipping = !preventClipping);
                                    ref.read(settingsProvider.notifier).setPreventClipping(preventClipping);
                                  },
                                  child: AnimatedContainer(
                                    duration: animDuration,
                                    curve: animCurve,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.darkSurface,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.shield_rounded,
                                          color: preventClipping ? AppTheme.primaryColor : AppTheme.textMuted,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Prevent Clipping',
                                                style: TextStyle(
                                                  color: AppTheme.textPrimary,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Limit gain to avoid distortion',
                                                style: TextStyle(
                                                  color: AppTheme.textMuted,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        AnimatedContainer(
                                          duration: animDuration,
                                          curve: animCurve,
                                          width: 44,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(12),
                                            color: preventClipping
                                                ? AppTheme.primaryColor
                                                : AppTheme.textMuted.withValues(alpha:0.3),
                                          ),
                                          child: AnimatedAlign(
                                            duration: animDuration,
                                            curve: animCurve,
                                            alignment: preventClipping
                                                ? Alignment.centerRight
                                                : Alignment.centerLeft,
                                            child: Container(
                                              width: 20,
                                              height: 20,
                                              margin: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha:0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: AppTheme.primaryColor,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        mode == NormalizationMode.track
                                            ? 'Each song is adjusted to the same perceived loudness'
                                            : 'Songs within the same album maintain their relative loudness',
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showThemeInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Theme'),
        content: const Text(
          'VibePlay uses a dark theme optimized for music listening. '
          'Light theme support coming in a future update!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAudioQualityInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Audio Quality'),
        content: const Text(
          'VibePlay always plays your music at the highest quality possible. '
          'Audio is decoded natively without any compression or resampling, '
          'ensuring you hear exactly what the artist intended.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showComingSoonInfo(BuildContext context, String title, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: Row(
          children: [
            Icon(Icons.schedule_rounded, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _confirmResetSettings(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Reset Settings?'),
        content: const Text(
          'This will restore all settings to their default values. '
          'Your playlists and favorites will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).resetToDefaults();
              audioHandler.setPlaybackSpeed(1.0);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings reset to defaults'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showReverbDialog(BuildContext context, WidgetRef ref, AppSettings settings) {
    ReverbPreset preset = settings.reverbPreset;

    const animDuration = Duration(milliseconds: 200);
    const animCurve = Curves.easeOutCubic;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reverb',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add spatial depth to your music',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 20),

                // Preset selection
                Text(
                  'Preset',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ...ReverbPreset.values.map((p) {
                  final isSelected = preset == p;
                  String subtitle;
                  IconData icon;

                  switch (p) {
                    case ReverbPreset.none:
                      subtitle = 'No reverb effect';
                      icon = Icons.volume_off_rounded;
                    case ReverbPreset.smallRoom:
                      subtitle = 'Intimate, close space';
                      icon = Icons.meeting_room_rounded;
                    case ReverbPreset.mediumRoom:
                      subtitle = 'Moderate room ambience';
                      icon = Icons.living_rounded;
                    case ReverbPreset.largeRoom:
                      subtitle = 'Spacious room feel';
                      icon = Icons.warehouse_rounded;
                    case ReverbPreset.mediumHall:
                      subtitle = 'Concert hall atmosphere';
                      icon = Icons.apartment_rounded;
                    case ReverbPreset.largeHall:
                      subtitle = 'Grand venue sound';
                      icon = Icons.location_city_rounded;
                    case ReverbPreset.plate:
                      subtitle = 'Classic studio reverb';
                      icon = Icons.layers_rounded;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => preset = p);
                          ref.read(settingsProvider.notifier).setReverbPreset(p);
                        },
                        child: AnimatedContainer(
                          duration: animDuration,
                          curve: animCurve,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor.withValues(alpha:0.15)
                                : AppTheme.darkSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                icon,
                                color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AnimatedDefaultTextStyle(
                                      duration: animDuration,
                                      curve: animCurve,
                                      style: TextStyle(
                                        color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        fontSize: 16,
                                      ),
                                      child: Text(p.name),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      style: TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedOpacity(
                                duration: animDuration,
                                curve: animCurve,
                                opacity: isSelected ? 1.0 : 0.0,
                                child: AnimatedScale(
                                  duration: animDuration,
                                  curve: animCurve,
                                  scale: isSelected ? 1.0 : 0.5,
                                  child: Icon(Icons.check_circle, color: AppTheme.primaryColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                // Info box
                AnimatedSize(
                  duration: animDuration,
                  curve: animCurve,
                  child: AnimatedOpacity(
                    duration: animDuration,
                    curve: animCurve,
                    opacity: preset != ReverbPreset.none ? 1.0 : 0.0,
                    child: preset != ReverbPreset.none
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha:0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: AppTheme.primaryColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Reverb adds spatial depth by simulating sound reflections in different environments',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPitchDialog(BuildContext context, WidgetRef ref, AppSettings settings) {
    double pitch = settings.pitchSemitones;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          String getPitchDescription() {
            if (pitch == 0) return 'Original pitch';
            if (pitch > 0) {
              if (pitch >= 12) return 'One octave higher';
              if (pitch >= 7) return 'A fifth higher';
              if (pitch >= 5) return 'A fourth higher';
              if (pitch >= 2) return 'Slightly higher';
              return 'Minimally higher';
            } else {
              if (pitch <= -12) return 'One octave lower';
              if (pitch <= -7) return 'A fifth lower';
              if (pitch <= -5) return 'A fourth lower';
              if (pitch <= -2) return 'Slightly lower';
              return 'Minimally lower';
            }
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pitch Adjustment',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Shift pitch up or down in semitones',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 12),
                // Pitch info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pitch is adjusted without changing tempo using advanced DSP processing.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Pitch value display
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: Column(
                      key: ValueKey(pitch.toStringAsFixed(1)),
                      children: [
                        Text(
                          pitch == 0
                              ? '0'
                              : (pitch > 0 ? '+${pitch.toStringAsFixed(1)}' : pitch.toStringAsFixed(1)),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: pitch == 0
                                ? AppTheme.textPrimary
                                : (pitch > 0 ? Colors.green : Colors.orange),
                          ),
                        ),
                        Text(
                          'semitones',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          getPitchDescription(),
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Slider
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                  ),
                  child: Slider(
                    value: pitch,
                    min: -12,
                    max: 12,
                    divisions: 48, // 0.5 semitone steps
                    activeColor: pitch == 0
                        ? AppTheme.primaryColor
                        : (pitch > 0 ? Colors.green : Colors.orange),
                    inactiveColor: AppTheme.primaryColor.withValues(alpha:0.2),
                    onChanged: (value) {
                      // Snap to nearest 0.5
                      final snapped = (value * 2).round() / 2;
                      setState(() => pitch = snapped);
                    },
                    onChangeEnd: (value) {
                      final snapped = (value * 2).round() / 2;
                      ref.read(settingsProvider.notifier).setPitchSemitones(snapped);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('-12', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      Text('Lower', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      Text('Normal', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      Text('Higher', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      Text('+12', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Quick presets
                Text(
                  'Quick Presets',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPitchPresetChip('Reset', 0, pitch, () {
                      setState(() => pitch = 0);
                      ref.read(settingsProvider.notifier).setPitchSemitones(0);
                    }),
                    _buildPitchPresetChip('-1', -1, pitch, () {
                      setState(() => pitch = -1);
                      ref.read(settingsProvider.notifier).setPitchSemitones(-1);
                    }),
                    _buildPitchPresetChip('+1', 1, pitch, () {
                      setState(() => pitch = 1);
                      ref.read(settingsProvider.notifier).setPitchSemitones(1);
                    }),
                    _buildPitchPresetChip('-2', -2, pitch, () {
                      setState(() => pitch = -2);
                      ref.read(settingsProvider.notifier).setPitchSemitones(-2);
                    }),
                    _buildPitchPresetChip('+2', 2, pitch, () {
                      setState(() => pitch = 2);
                      ref.read(settingsProvider.notifier).setPitchSemitones(2);
                    }),
                    _buildPitchPresetChip('Octave ↓', -12, pitch, () {
                      setState(() => pitch = -12);
                      ref.read(settingsProvider.notifier).setPitchSemitones(-12);
                    }),
                    _buildPitchPresetChip('Octave ↑', 12, pitch, () {
                      setState(() => pitch = 12);
                      ref.read(settingsProvider.notifier).setPitchSemitones(12);
                    }),
                  ],
                ),
                const SizedBox(height: 16),

                // Info box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppTheme.primaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pitch adjustment changes the musical key without affecting playback speed',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPitchPresetChip(
    String label,
    double value,
    double currentPitch,
    VoidCallback onTap,
  ) {
    final isSelected = currentPitch == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha:0.2)
                : AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
