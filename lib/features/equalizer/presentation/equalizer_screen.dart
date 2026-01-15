import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/equalizer_service.dart';
import '../../../services/equalizer_storage_service.dart';
import '../../../services/audio_handler.dart';
import '../data/equalizer_presets.dart';

// Equalizer state - Software 10-band EQ
class EqualizerState {
  final bool isEnabled;
  final EqualizerPreset currentPreset;
  final List<double> customBands; // 10 bands
  final double bassBoost;
  final double virtualizer;
  final bool spatialAudioEnabled;
  final List<CustomPreset> customPresets;
  final bool perSongEnabled;
  final String? currentSongPath;
  final bool hasPerSongSettings;

  const EqualizerState({
    this.isEnabled = false,
    this.currentPreset = EqualizerPresets.flat,
    this.customBands = const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    this.bassBoost = 0.0,
    this.virtualizer = 0.0,
    this.spatialAudioEnabled = false,
    this.customPresets = const [],
    this.perSongEnabled = false,
    this.currentSongPath,
    this.hasPerSongSettings = false,
  });

  EqualizerState copyWith({
    bool? isEnabled,
    EqualizerPreset? currentPreset,
    List<double>? customBands,
    double? bassBoost,
    double? virtualizer,
    bool? spatialAudioEnabled,
    List<CustomPreset>? customPresets,
    bool? perSongEnabled,
    String? currentSongPath,
    bool? hasPerSongSettings,
  }) {
    return EqualizerState(
      isEnabled: isEnabled ?? this.isEnabled,
      currentPreset: currentPreset ?? this.currentPreset,
      customBands: customBands ?? List.from(this.customBands),
      bassBoost: bassBoost ?? this.bassBoost,
      virtualizer: virtualizer ?? this.virtualizer,
      spatialAudioEnabled: spatialAudioEnabled ?? this.spatialAudioEnabled,
      customPresets: customPresets ?? this.customPresets,
      perSongEnabled: perSongEnabled ?? this.perSongEnabled,
      currentSongPath: currentSongPath ?? this.currentSongPath,
      hasPerSongSettings: hasPerSongSettings ?? this.hasPerSongSettings,
    );
  }
}

// Equalizer notifier - Software 10-band EQ
class EqualizerNotifier extends StateNotifier<EqualizerState> {
  EqualizerNotifier() : super(const EqualizerState()) {
    _init();
  }

  Future<void> _init() async {
    await equalizerStorageService.init();
    state = state.copyWith(
      customPresets: equalizerStorageService.customPresets,
      perSongEnabled: equalizerStorageService.perSongEnabled,
    );

    // Listen to song changes for per-song EQ
    audioHandler.currentSongStream.listen((song) {
      if (song != null && state.perSongEnabled) {
        _loadSongEQ(song.path);
      }
    });
  }

  Future<void> _loadSongEQ(String? songPath) async {
    if (songPath == null) return;

    final songSettings = equalizerStorageService.getSongEQ(songPath);
    if (songSettings != null) {
      state = state.copyWith(
        currentSongPath: songPath,
        hasPerSongSettings: true,
        customBands: songSettings.bands,
        bassBoost: songSettings.bassBoost,
        virtualizer: songSettings.virtualizer,
      );
      await _applyAllSettings();
    } else {
      state = state.copyWith(
        currentSongPath: songPath,
        hasPerSongSettings: false,
      );
    }
  }

  Future<void> toggleEnabled() async {
    final newEnabled = !state.isEnabled;
    state = state.copyWith(isEnabled: newEnabled);
    await equalizerService.setEnabled(newEnabled);

    if (newEnabled) {
      // Apply current settings when enabling
      await _applyAllSettings();
    }
  }

  Future<void> setPreset(EqualizerPreset preset) async {
    state = state.copyWith(
      currentPreset: preset,
      customBands: List.from(preset.bands),
      bassBoost: preset.bassBoost,
      virtualizer: preset.virtualizer,
    );
    await _applyAllSettings();
  }

  Future<void> setBand(int index, double value) async {
    final newBands = List<double>.from(state.customBands);
    newBands[index] = value.clamp(-10.0, 10.0);
    state = state.copyWith(customBands: newBands);

    if (state.isEnabled) {
      await equalizerService.setBandLevel(index, value);
    }
  }

  Future<void> setBassBoost(double value) async {
    state = state.copyWith(bassBoost: value.clamp(0.0, 1.0));

    if (state.isEnabled) {
      await equalizerService.setBassBoost(value);
    }
  }

  Future<void> setVirtualizer(double value) async {
    state = state.copyWith(virtualizer: value.clamp(0.0, 1.0));

    if (state.isEnabled) {
      await equalizerService.setVirtualizer(value);
    }
  }

  Future<void> toggleSpatialAudio() async {
    final newEnabled = !state.spatialAudioEnabled;
    state = state.copyWith(spatialAudioEnabled: newEnabled);

    // Spatial audio uses virtualizer at high strength
    if (newEnabled && state.isEnabled) {
      await equalizerService.setVirtualizer(0.8);
    } else if (state.isEnabled) {
      await equalizerService.setVirtualizer(state.virtualizer);
    }
  }

  Future<void> _applyAllSettings() async {
    if (!state.isEnabled) return;

    // Apply all band levels at once (more efficient)
    await equalizerService.setAllBands(state.customBands);

    // Apply bass boost
    await equalizerService.setBassBoost(state.bassBoost);

    // Apply virtualizer (or spatial audio setting)
    if (state.spatialAudioEnabled) {
      await equalizerService.setVirtualizer(0.8);
    } else {
      await equalizerService.setVirtualizer(state.virtualizer);
    }
  }

  // Custom preset methods

  Future<void> saveCurrentAsPreset(String name) async {
    await equalizerStorageService.saveCustomPreset(
      name: name,
      bands: state.customBands,
      bassBoost: state.bassBoost,
      virtualizer: state.virtualizer,
    );
    state = state.copyWith(
      customPresets: equalizerStorageService.customPresets,
    );
  }

  Future<void> loadCustomPreset(CustomPreset preset) async {
    state = state.copyWith(
      customBands: List.from(preset.bands),
      bassBoost: preset.bassBoost,
      virtualizer: preset.virtualizer,
    );
    await _applyAllSettings();
  }

  Future<void> deleteCustomPreset(String id) async {
    await equalizerStorageService.deleteCustomPreset(id);
    state = state.copyWith(
      customPresets: equalizerStorageService.customPresets,
    );
  }

  Future<void> renameCustomPreset(String id, String newName) async {
    await equalizerStorageService.renameCustomPreset(id, newName);
    state = state.copyWith(
      customPresets: equalizerStorageService.customPresets,
    );
  }

  // Per-song EQ methods

  Future<void> togglePerSongEQ() async {
    final newEnabled = !state.perSongEnabled;
    await equalizerStorageService.setPerSongEnabled(newEnabled);
    state = state.copyWith(perSongEnabled: newEnabled);

    // Load current song's EQ if enabling
    if (newEnabled) {
      final currentSong = audioHandler.currentSong;
      if (currentSong != null) {
        await _loadSongEQ(currentSong.path);
      }
    }
  }

  Future<void> saveCurrentSongEQ() async {
    final songPath = audioHandler.currentSong?.path;
    if (songPath == null) return;

    await equalizerStorageService.saveSongEQ(
      songPath: songPath,
      bands: state.customBands,
      bassBoost: state.bassBoost,
      virtualizer: state.virtualizer,
    );
    state = state.copyWith(hasPerSongSettings: true);
  }

  Future<void> clearCurrentSongEQ() async {
    final songPath = audioHandler.currentSong?.path;
    if (songPath == null) return;

    await equalizerStorageService.deleteSongEQ(songPath);
    state = state.copyWith(hasPerSongSettings: false);
  }

  Future<void> reset() async {
    state = state.copyWith(
      isEnabled: false,
      currentPreset: EqualizerPresets.flat,
      customBands: const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      bassBoost: 0.0,
      virtualizer: 0.0,
      spatialAudioEnabled: false,
    );
    await equalizerService.setEnabled(false);
  }
}

final equalizerProvider = StateNotifierProvider<EqualizerNotifier, EqualizerState>(
  (ref) => EqualizerNotifier(),
);

class EqualizerScreen extends ConsumerWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eqState = ref.watch(equalizerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equalizer'),
        actions: [
          Switch(
            value: eqState.isEnabled,
            onChanged: (_) => ref.read(equalizerProvider.notifier).toggleEnabled(),
            activeColor: AppTheme.primaryColor,
          ),
        ],
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Presets
              _buildPresetsSection(context, ref, eqState),

              const SizedBox(height: 32),

              // EQ Bands
              _buildEQBands(context, ref, eqState),

              const SizedBox(height: 32),

              // Bass Boost & Virtualizer
              _buildEffects(context, ref, eqState),

              const SizedBox(height: 32),

              // Spatial Audio
              _buildSpatialAudio(context, ref, eqState),

              const SizedBox(height: 32),

              // Per-Song EQ
              _buildPerSongEQ(context, ref, eqState),

              const SizedBox(height: 32),

              // Reset button
              Center(
                child: TextButton.icon(
                  onPressed: () => ref.read(equalizerProvider.notifier).reset(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reset to Default'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetsSection(BuildContext context, WidgetRef ref, EqualizerState eqState) {
    final allPresets = [...EqualizerPresets.all];
    final customPresets = eqState.customPresets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Presets',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            IconButton(
              onPressed: () => _showSavePresetDialog(context, ref, eqState),
              icon: Icon(Icons.add_rounded, color: AppTheme.primaryColor),
              tooltip: 'Save as preset',
            ),
          ],
        ).animate().fadeIn(),
        const SizedBox(height: 16),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: allPresets.length + customPresets.length,
            itemBuilder: (context, index) {
              final isCustom = index >= allPresets.length;
              final String presetName;
              final bool isSelected;

              if (isCustom) {
                final customPreset = customPresets[index - allPresets.length];
                presetName = customPreset.name;
                isSelected = false; // Custom presets don't have a "selected" state like built-ins

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(equalizerProvider.notifier).loadCustomPreset(customPreset);
                    },
                    onLongPress: () => _showCustomPresetOptions(context, ref, customPreset),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: AppTheme.darkCard,
                        border: Border.all(
                          color: AppTheme.secondaryColor.withValues(alpha:0.5),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: AppTheme.secondaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              presetName,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate(delay: (30 * index).ms).fadeIn().slideX(begin: 0.2),
                );
              }

              final preset = allPresets[index];
              isSelected = eqState.currentPreset.name == preset.name;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(equalizerProvider.notifier).setPreset(preset);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                AppTheme.primaryColor,
                                AppTheme.secondaryColor,
                              ],
                            )
                          : null,
                      color: isSelected ? null : AppTheme.darkCard,
                    ),
                    child: Center(
                      child: Text(
                        preset.name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.textSecondary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ).animate(delay: (30 * index).ms).fadeIn().slideX(begin: 0.2),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showSavePresetDialog(BuildContext context, WidgetRef ref, EqualizerState eqState) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Save Preset'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Preset name',
            hintStyle: TextStyle(color: AppTheme.textMuted),
            filled: true,
            fillColor: AppTheme.darkSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(equalizerProvider.notifier).saveCurrentAsPreset(name);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Preset "$name" saved'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showCustomPresetOptions(BuildContext context, WidgetRef ref, CustomPreset preset) {
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
          children: [
            Text(
              preset.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.play_arrow_rounded, color: AppTheme.primaryColor),
              title: const Text('Apply'),
              onTap: () {
                ref.read(equalizerProvider.notifier).loadCustomPreset(preset);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppTheme.textSecondary),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _showRenamePresetDialog(context, ref, preset);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                ref.read(equalizerProvider.notifier).deleteCustomPreset(preset.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Preset "${preset.name}" deleted'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenamePresetDialog(BuildContext context, WidgetRef ref, CustomPreset preset) {
    final controller = TextEditingController(text: preset.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Rename Preset'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'New name',
            hintStyle: TextStyle(color: AppTheme.textMuted),
            filled: true,
            fillColor: AppTheme.darkSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                ref.read(equalizerProvider.notifier).renameCustomPreset(preset.id, newName);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  Widget _buildEQBands(BuildContext context, WidgetRef ref, EqualizerState eqState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Equalizer',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha:0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '10-band',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ).animate().fadeIn(),
        const SizedBox(height: 16),
        // EQ Curve Visualization
        _buildEQCurve(context, eqState),
        const SizedBox(height: 16),
        Container(
          height: 260,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(EqualizerPresets.bandCount, (index) {
              return Expanded(
                child: _buildBandSlider(
                  context,
                  ref,
                  index,
                  EqualizerPresets.bandFrequencies[index],
                  eqState.customBands[index],
                  eqState.isEnabled,
                ),
              );
            }),
          ),
        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
      ],
    );
  }

  Widget _buildEQCurve(BuildContext context, EqualizerState eqState) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: EQCurvePainter(
            bands: eqState.customBands,
            isEnabled: eqState.isEnabled,
            primaryColor: AppTheme.primaryColor,
            secondaryColor: AppTheme.secondaryColor,
          ),
          size: Size.infinite,
        ),
      ),
    ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.1);
  }

  Widget _buildBandSlider(
    BuildContext context,
    WidgetRef ref,
    int index,
    String label,
    double value,
    bool isEnabled,
  ) {
    return Column(
      children: [
        Text(
          '${value > 0 ? '+' : ''}${value.toInt()}',
          style: TextStyle(
            color: isEnabled ? AppTheme.textPrimary : AppTheme.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: isEnabled
                    ? AppTheme.primaryColor
                    : AppTheme.textMuted.withValues(alpha:0.3),
                inactiveTrackColor: AppTheme.darkSurface,
                thumbColor: isEnabled ? AppTheme.primaryColor : AppTheme.textMuted,
                overlayColor: AppTheme.primaryColor.withValues(alpha:0.2),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: value,
                min: -10.0,
                max: 10.0,
                onChanged: isEnabled
                    ? (newValue) {
                        HapticFeedback.selectionClick();
                        ref.read(equalizerProvider.notifier).setBand(index, newValue);
                      }
                    : null,
              ),
            ),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: isEnabled ? AppTheme.textSecondary : AppTheme.textMuted,
            fontSize: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildEffects(BuildContext context, WidgetRef ref, EqualizerState eqState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Effects',
          style: Theme.of(context).textTheme.titleLarge,
        ).animate().fadeIn(),
        const SizedBox(height: 16),
        // Bass Boost
        _buildEffectSlider(
          context,
          'Bass Boost',
          Icons.speaker_rounded,
          eqState.bassBoost,
          eqState.isEnabled,
          (value) => ref.read(equalizerProvider.notifier).setBassBoost(value),
        ),
        const SizedBox(height: 16),
        // Virtualizer
        _buildEffectSlider(
          context,
          'Virtualizer',
          Icons.surround_sound_rounded,
          eqState.virtualizer,
          eqState.isEnabled,
          (value) => ref.read(equalizerProvider.notifier).setVirtualizer(value),
        ),
      ],
    );
  }

  Widget _buildEffectSlider(
    BuildContext context,
    String label,
    IconData icon,
    double value,
    bool isEnabled,
    ValueChanged<double> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isEnabled && value > 0
                ? AppTheme.primaryColor
                : AppTheme.textMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isEnabled ? AppTheme.textPrimary : AppTheme.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${(value * 100).toInt()}%',
                      style: TextStyle(
                        color: isEnabled ? AppTheme.textSecondary : AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: isEnabled
                        ? AppTheme.primaryColor
                        : AppTheme.textMuted.withValues(alpha:0.3),
                    inactiveTrackColor: AppTheme.darkSurface,
                    thumbColor: isEnabled ? AppTheme.primaryColor : AppTheme.textMuted,
                    overlayColor: AppTheme.primaryColor.withValues(alpha:0.2),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: value,
                    onChanged: isEnabled ? onChanged : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1);
  }

  Widget _buildSpatialAudio(BuildContext context, WidgetRef ref, EqualizerState eqState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Spatial Audio',
          style: Theme.of(context).textTheme.titleLarge,
        ).animate().fadeIn(),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: eqState.spatialAudioEnabled
                ? LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withValues(alpha:0.2),
                      AppTheme.secondaryColor.withValues(alpha:0.2),
                    ],
                  )
                : null,
            color: eqState.spatialAudioEnabled ? null : AppTheme.darkCard,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: eqState.spatialAudioEnabled
                      ? AppTheme.primaryColor.withValues(alpha:0.2)
                      : AppTheme.darkSurface,
                ),
                child: Icon(
                  Icons.spatial_audio_rounded,
                  color: eqState.spatialAudioEnabled
                      ? AppTheme.primaryColor
                      : AppTheme.textMuted,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spatial Audio',
                      style: TextStyle(
                        color: eqState.spatialAudioEnabled
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Immersive 3D sound experience',
                      style: TextStyle(
                        color: eqState.spatialAudioEnabled
                            ? AppTheme.textSecondary
                            : AppTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: eqState.spatialAudioEnabled,
                onChanged: (_) {
                  HapticFeedback.mediumImpact();
                  ref.read(equalizerProvider.notifier).toggleSpatialAudio();
                },
                activeColor: AppTheme.primaryColor,
              ),
            ],
          ),
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
        if (eqState.spatialAudioEnabled) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'For best results, use headphones or earbuds with spatial audio support.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 400.ms),
        ],
      ],
    );
  }

  Widget _buildPerSongEQ(BuildContext context, WidgetRef ref, EqualizerState eqState) {
    final currentSong = audioHandler.currentSong;
    final songTitle = currentSong?.title ?? 'No song playing';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Per-Song EQ',
          style: Theme.of(context).textTheme.titleLarge,
        ).animate().fadeIn(),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: eqState.perSongEnabled
                ? LinearGradient(
                    colors: [
                      AppTheme.secondaryColor.withValues(alpha:0.2),
                      AppTheme.primaryColor.withValues(alpha:0.2),
                    ],
                  )
                : null,
            color: eqState.perSongEnabled ? null : AppTheme.darkCard,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: eqState.perSongEnabled
                          ? AppTheme.secondaryColor.withValues(alpha:0.2)
                          : AppTheme.darkSurface,
                    ),
                    child: Icon(
                      Icons.music_note_rounded,
                      color: eqState.perSongEnabled
                          ? AppTheme.secondaryColor
                          : AppTheme.textMuted,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Remember EQ per Song',
                          style: TextStyle(
                            color: eqState.perSongEnabled
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Auto-load saved EQ for each song',
                          style: TextStyle(
                            color: eqState.perSongEnabled
                                ? AppTheme.textSecondary
                                : AppTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: eqState.perSongEnabled,
                    onChanged: (_) {
                      HapticFeedback.mediumImpact();
                      ref.read(equalizerProvider.notifier).togglePerSongEQ();
                    },
                    activeColor: AppTheme.secondaryColor,
                  ),
                ],
              ),
              if (eqState.perSongEnabled && currentSong != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Song',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              songTitle,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (eqState.hasPerSongSettings)
                        TextButton.icon(
                          onPressed: () {
                            ref.read(equalizerProvider.notifier).clearCurrentSongEQ();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Song EQ cleared'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          label: const Text('Clear'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.textMuted,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: () {
                            ref.read(equalizerProvider.notifier).saveCurrentSongEQ();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('EQ saved for "$songTitle"'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: const Text('Save'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                if (eqState.hasPerSongSettings) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.secondaryColor,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Custom EQ loaded for this song',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1),
      ],
    );
  }
}

/// Custom painter for drawing the EQ frequency response curve
class EQCurvePainter extends CustomPainter {
  final List<double> bands;
  final bool isEnabled;
  final Color primaryColor;
  final Color secondaryColor;

  EQCurvePainter({
    required this.bands,
    required this.isEnabled,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bands.isEmpty) return;

    final padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    final graphWidth = size.width - padding.horizontal;
    final graphHeight = size.height - padding.vertical;
    final graphLeft = padding.left;
    final graphTop = padding.top;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = AppTheme.textMuted.withValues(alpha: 0.15)
      ..strokeWidth = 1;

    // Horizontal grid lines (dB levels: +10, +5, 0, -5, -10)
    for (int i = 0; i <= 4; i++) {
      final y = graphTop + (graphHeight * i / 4);
      canvas.drawLine(
        Offset(graphLeft, y),
        Offset(graphLeft + graphWidth, y),
        gridPaint,
      );
    }

    // Draw center line (0 dB) slightly brighter
    final centerY = graphTop + graphHeight / 2;
    final centerPaint = Paint()
      ..color = AppTheme.textMuted.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(graphLeft, centerY),
      Offset(graphLeft + graphWidth, centerY),
      centerPaint,
    );

    // Calculate points for the curve
    final points = <Offset>[];
    final bandWidth = graphWidth / (bands.length - 1);

    for (int i = 0; i < bands.length; i++) {
      final x = graphLeft + (i * bandWidth);
      // Map -10 to +10 dB to the graph height (inverted: +10 at top, -10 at bottom)
      final normalizedValue = (10 - bands[i]) / 20; // 0 at +10dB, 1 at -10dB
      final y = graphTop + (normalizedValue * graphHeight);
      points.add(Offset(x, y.clamp(graphTop, graphTop + graphHeight)));
    }

    // Create smooth curve path using Catmull-Rom spline
    final curvePath = Path();
    if (points.isNotEmpty) {
      curvePath.moveTo(points.first.dx, points.first.dy);

      for (int i = 0; i < points.length - 1; i++) {
        final p0 = i > 0 ? points[i - 1] : points[i];
        final p1 = points[i];
        final p2 = points[i + 1];
        final p3 = i < points.length - 2 ? points[i + 2] : p2;

        // Catmull-Rom to Bezier conversion
        final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
        final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
        final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
        final cp2y = p2.dy - (p3.dy - p1.dy) / 6;

        curvePath.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
      }
    }

    // Draw filled area under the curve
    final fillPath = Path.from(curvePath);
    fillPath.lineTo(graphLeft + graphWidth, centerY);
    fillPath.lineTo(graphLeft, centerY);
    fillPath.close();

    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isEnabled
          ? [
              primaryColor.withValues(alpha: 0.3),
              secondaryColor.withValues(alpha: 0.1),
            ]
          : [
              AppTheme.textMuted.withValues(alpha: 0.15),
              AppTheme.textMuted.withValues(alpha: 0.05),
            ],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(
        Rect.fromLTWH(0, graphTop, size.width, graphHeight),
      );

    canvas.drawPath(fillPath, fillPaint);

    // Draw the curve line
    final curvePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (isEnabled) {
      curvePaint.shader = LinearGradient(
        colors: [primaryColor, secondaryColor],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    } else {
      curvePaint.color = AppTheme.textMuted.withValues(alpha: 0.5);
    }

    canvas.drawPath(curvePath, curvePaint);

    // Draw points at each band
    final pointPaint = Paint()
      ..color = isEnabled ? primaryColor : AppTheme.textMuted
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 3, pointPaint);
    }

    // Draw dB labels
    final textStyle = TextStyle(
      color: AppTheme.textMuted.withValues(alpha: 0.6),
      fontSize: 8,
    );
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // +10 dB label
    textPainter.text = TextSpan(text: '+10', style: textStyle);
    textPainter.layout();
    textPainter.paint(canvas, Offset(2, graphTop - 2));

    // 0 dB label
    textPainter.text = TextSpan(text: '0', style: textStyle);
    textPainter.layout();
    textPainter.paint(canvas, Offset(4, centerY - 4));

    // -10 dB label
    textPainter.text = TextSpan(text: '-10', style: textStyle);
    textPainter.layout();
    textPainter.paint(canvas, Offset(2, graphTop + graphHeight - 10));
  }

  @override
  bool shouldRepaint(EQCurvePainter oldDelegate) {
    return oldDelegate.bands != bands || oldDelegate.isEnabled != isEnabled;
  }
}
