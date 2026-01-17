import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../services/audio_handler.dart';
import '../../../services/replay_gain_service.dart';
import '../../../services/audio_effects_service.dart';

// Re-export for convenience
export '../../../services/replay_gain_service.dart' show NormalizationMode;
export '../../../services/audio_effects_service.dart' show ReverbPreset, CustomReverbSettings;

enum SortOrder { title, artist, album, dateAdded, duration }
enum AudioQuality { low, medium, high }
enum CrossfadeMode { off, fixed, smart }
enum VisualizerStyleSetting {
  // Shader visualizers (GPU-accelerated)
  resonance,      // Cymatics-based, Chladni patterns
  ripples,        // Wave interference, water ripples
  lissajous,      // Harmonograph curves
  neonRings,      // Celestial Halos
  aurora,         // Northern lights / Aurora Borealis
  spirograph,     // Spirograph epicycles
  voronoi,        // Voronoi flow fields
  phyllotaxis,    // Sunflower spirals
  attractors,     // Strange attractors
  moire,          // Moiré patterns
  pendulum,       // Pendulum waves
  fractalFlames,  // Fractal flames
  mandelbrot,     // Mandelbrot/Julia sets
  // Pendulum variations
  pendulumCircular,   // Radial starburst pendulums
  pendulumCradle,     // Newton's cradle
  pendulumMetronome,  // Inverted metronomes
  pendulumDouble,     // Chaotic double pendulum
  pendulumLissajous,  // 2D sand pendulum / Lissajous
  pendulumSpring,     // Spring/bouncy pendulums
  pendulumFirefly,    // Glowing particle pendulums
  pendulumWave,       // Wave machine
  pendulumMirror,     // Mirrored reflection pendulums
}

class AppSettings {
  final double playbackSpeed;
  final SortOrder defaultSort;
  final bool sortAscending;
  final AudioQuality audioQuality;
  final bool dynamicColorsEnabled;
  final bool gaplessPlayback;
  final CrossfadeMode crossfadeMode;
  final int crossfadeDuration; // in seconds
  final NormalizationMode normalizationMode;
  final double targetLoudness; // LUFS (-24 to -6)
  final bool preventClipping;

  // Audio effects
  final bool reverbEnabled;
  final ReverbPreset reverbPreset;
  final double pitchSemitones; // -12 to +12 semitones

  // Visualizer
  final VisualizerStyleSetting visualizerStyle;
  final bool visualizerEnabled;

  // Import options
  final bool stripCommentsOnImport;

  const AppSettings({
    this.playbackSpeed = 1.0,
    this.defaultSort = SortOrder.title,
    this.sortAscending = true,
    this.audioQuality = AudioQuality.high,
    this.dynamicColorsEnabled = true,
    this.gaplessPlayback = true,
    this.crossfadeMode = CrossfadeMode.off,
    this.crossfadeDuration = 3,
    this.normalizationMode = NormalizationMode.off,
    this.targetLoudness = -14.0,
    this.preventClipping = true,
    this.reverbEnabled = false,
    this.reverbPreset = ReverbPreset.none,
    this.pitchSemitones = 0.0,
    this.visualizerStyle = VisualizerStyleSetting.resonance,
    this.visualizerEnabled = true,
    this.stripCommentsOnImport = false,
  });

  // Convenience getters for backwards compatibility
  bool get crossfadeEnabled => crossfadeMode != CrossfadeMode.off;
  bool get smartCrossfadeEnabled => crossfadeMode == CrossfadeMode.smart;

  AppSettings copyWith({
    double? playbackSpeed,
    SortOrder? defaultSort,
    bool? sortAscending,
    AudioQuality? audioQuality,
    bool? dynamicColorsEnabled,
    bool? gaplessPlayback,
    CrossfadeMode? crossfadeMode,
    int? crossfadeDuration,
    NormalizationMode? normalizationMode,
    double? targetLoudness,
    bool? preventClipping,
    bool? reverbEnabled,
    ReverbPreset? reverbPreset,
    double? pitchSemitones,
    VisualizerStyleSetting? visualizerStyle,
    bool? visualizerEnabled,
    bool? stripCommentsOnImport,
  }) {
    return AppSettings(
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      defaultSort: defaultSort ?? this.defaultSort,
      sortAscending: sortAscending ?? this.sortAscending,
      audioQuality: audioQuality ?? this.audioQuality,
      dynamicColorsEnabled: dynamicColorsEnabled ?? this.dynamicColorsEnabled,
      gaplessPlayback: gaplessPlayback ?? this.gaplessPlayback,
      crossfadeMode: crossfadeMode ?? this.crossfadeMode,
      crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
      normalizationMode: normalizationMode ?? this.normalizationMode,
      targetLoudness: targetLoudness ?? this.targetLoudness,
      preventClipping: preventClipping ?? this.preventClipping,
      reverbEnabled: reverbEnabled ?? this.reverbEnabled,
      reverbPreset: reverbPreset ?? this.reverbPreset,
      pitchSemitones: pitchSemitones ?? this.pitchSemitones,
      visualizerStyle: visualizerStyle ?? this.visualizerStyle,
      visualizerEnabled: visualizerEnabled ?? this.visualizerEnabled,
      stripCommentsOnImport: stripCommentsOnImport ?? this.stripCommentsOnImport,
    );
  }

  Map<String, dynamic> toJson() => {
    'playbackSpeed': playbackSpeed,
    'defaultSort': defaultSort.index,
    'sortAscending': sortAscending,
    'audioQuality': audioQuality.index,
    'dynamicColorsEnabled': dynamicColorsEnabled,
    'gaplessPlayback': gaplessPlayback,
    'crossfadeMode': crossfadeMode.index,
    'crossfadeDuration': crossfadeDuration,
    'normalizationMode': normalizationMode.index,
    'targetLoudness': targetLoudness,
    'preventClipping': preventClipping,
    'reverbEnabled': reverbEnabled,
    'reverbPreset': reverbPreset.id,
    'pitchSemitones': pitchSemitones,
    'visualizerStyle': visualizerStyle.index,
    'visualizerEnabled': visualizerEnabled,
    'stripCommentsOnImport': stripCommentsOnImport,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    // Handle migration from old crossfadeEnabled boolean
    CrossfadeMode crossfadeMode = CrossfadeMode.off;
    if (json.containsKey('crossfadeMode')) {
      crossfadeMode = CrossfadeMode.values[json['crossfadeMode'] as int? ?? 0];
    } else if (json['crossfadeEnabled'] == true) {
      // Migrate old setting
      crossfadeMode = CrossfadeMode.fixed;
    }

    // Parse normalization mode
    NormalizationMode normMode = NormalizationMode.off;
    if (json.containsKey('normalizationMode')) {
      final index = json['normalizationMode'] as int? ?? 0;
      if (index >= 0 && index < NormalizationMode.values.length) {
        normMode = NormalizationMode.values[index];
      }
    }

    // Parse reverb preset
    ReverbPreset reverbPreset = ReverbPreset.none;
    if (json.containsKey('reverbPreset')) {
      reverbPreset = ReverbPreset.fromId(json['reverbPreset'] as int? ?? -1);
    }

    // Parse visualizer style
    VisualizerStyleSetting visualizerStyle = VisualizerStyleSetting.resonance;
    if (json.containsKey('visualizerStyle')) {
      final index = json['visualizerStyle'] as int? ?? 2;
      if (index >= 0 && index < VisualizerStyleSetting.values.length) {
        visualizerStyle = VisualizerStyleSetting.values[index];
      }
    }

    return AppSettings(
      playbackSpeed: (json['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      defaultSort: SortOrder.values[json['defaultSort'] as int? ?? 0],
      sortAscending: json['sortAscending'] as bool? ?? true,
      audioQuality: AudioQuality.values[json['audioQuality'] as int? ?? 2],
      dynamicColorsEnabled: json['dynamicColorsEnabled'] as bool? ?? true,
      gaplessPlayback: json['gaplessPlayback'] as bool? ?? true,
      crossfadeMode: crossfadeMode,
      crossfadeDuration: json['crossfadeDuration'] as int? ?? 3,
      normalizationMode: normMode,
      targetLoudness: (json['targetLoudness'] as num?)?.toDouble() ?? -14.0,
      preventClipping: json['preventClipping'] as bool? ?? true,
      reverbEnabled: json['reverbEnabled'] as bool? ?? false,
      reverbPreset: reverbPreset,
      pitchSemitones: (json['pitchSemitones'] as num?)?.toDouble() ?? 0.0,
      visualizerStyle: visualizerStyle,
      visualizerEnabled: json['visualizerEnabled'] as bool? ?? true,
      stripCommentsOnImport: json['stripCommentsOnImport'] as bool? ?? false,
    );
  }

  String get playbackSpeedLabel => '${playbackSpeed}x';

  String get sortOrderLabel {
    switch (defaultSort) {
      case SortOrder.title:
        return 'By title';
      case SortOrder.artist:
        return 'By artist';
      case SortOrder.album:
        return 'By album';
      case SortOrder.dateAdded:
        return 'By date added';
      case SortOrder.duration:
        return 'By duration';
    }
  }

  String get audioQualityLabel {
    switch (audioQuality) {
      case AudioQuality.low:
        return 'Low (saves battery)';
      case AudioQuality.medium:
        return 'Medium';
      case AudioQuality.high:
        return 'High quality';
    }
  }

  String get normalizationModeLabel {
    switch (normalizationMode) {
      case NormalizationMode.off:
        return 'Off';
      case NormalizationMode.track:
        return 'Track (${targetLoudness.toStringAsFixed(0)} LUFS)';
      case NormalizationMode.album:
        return 'Album (${targetLoudness.toStringAsFixed(0)} LUFS)';
    }
  }

  String get reverbLabel {
    if (!reverbEnabled) return 'Off';
    return reverbPreset.name;
  }

  String get pitchLabel {
    if (pitchSemitones == 0) return 'Normal';
    final sign = pitchSemitones > 0 ? '+' : '';
    return '$sign${pitchSemitones.toStringAsFixed(1)} semitones';
  }

  String get visualizerStyleLabel {
    switch (visualizerStyle) {
      case VisualizerStyleSetting.resonance:
        return 'Resonance';
      case VisualizerStyleSetting.ripples:
        return 'Ripples';
      case VisualizerStyleSetting.lissajous:
        return 'Harmonograph';
      case VisualizerStyleSetting.neonRings:
        return 'Celestial Halos';
      case VisualizerStyleSetting.aurora:
        return 'Aurora';
      case VisualizerStyleSetting.spirograph:
        return 'Spirograph';
      case VisualizerStyleSetting.voronoi:
        return 'Voronoi';
      case VisualizerStyleSetting.phyllotaxis:
        return 'Sunflower';
      case VisualizerStyleSetting.attractors:
        return 'Attractors';
      case VisualizerStyleSetting.moire:
        return 'Moiré';
      case VisualizerStyleSetting.pendulum:
        return 'Pendulum';
      case VisualizerStyleSetting.fractalFlames:
        return 'Flames';
      case VisualizerStyleSetting.mandelbrot:
        return 'Fractal';
      // Pendulum variations
      case VisualizerStyleSetting.pendulumCircular:
        return 'Circular Pendulum';
      case VisualizerStyleSetting.pendulumCradle:
        return 'Newton\'s Cradle';
      case VisualizerStyleSetting.pendulumMetronome:
        return 'Metronome';
      case VisualizerStyleSetting.pendulumDouble:
        return 'Double Pendulum';
      case VisualizerStyleSetting.pendulumLissajous:
        return 'Sand Pendulum';
      case VisualizerStyleSetting.pendulumSpring:
        return 'Spring Pendulum';
      case VisualizerStyleSetting.pendulumFirefly:
        return 'Firefly';
      case VisualizerStyleSetting.pendulumWave:
        return 'Wave Machine';
      case VisualizerStyleSetting.pendulumMirror:
        return 'Mirror Pendulum';
    }
  }

  // All visualizers are now shader-based
  bool get isShaderVisualizer => true;
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  static const String _boxName = 'settings';
  Box? _box;

  SettingsNotifier() : super(const AppSettings()) {
    _init();
  }

  Future<void> _init() async {
    _box = await Hive.openBox(_boxName);
    final saved = _box?.get('appSettings');
    if (saved != null) {
      state = AppSettings.fromJson(Map<String, dynamic>.from(saved));
    }

    // Apply audio settings to handler
    audioHandler.setCrossfadeEnabled(state.crossfadeEnabled);
    audioHandler.setSmartCrossfadeEnabled(state.smartCrossfadeEnabled);
    audioHandler.setCrossfadeDuration(state.crossfadeDuration);
    await audioHandler.setPlaybackSpeed(state.playbackSpeed);
    await audioHandler.setGaplessPlaybackEnabled(state.gaplessPlayback);

    // Apply normalization settings (sync)
    _applyNormalizationSettings();

    // Apply audio effects settings
    await _applyAudioEffectsSettings();

    // Apply visualizer/AudioPulse setting (for battery saving)
    await audioHandler.setAudioPulseEnabled(state.visualizerEnabled);
  }

  Future<void> _applyAudioEffectsSettings() async {
    if (state.reverbEnabled) {
      await audioEffectsService.setReverbEnabled(true);
      await audioEffectsService.setReverbPreset(state.reverbPreset);
    }
    if (state.pitchSemitones != 0) {
      await audioHandler.setPitch(state.pitchSemitones);
    }
  }

  void _applyNormalizationSettings() {
    replayGainService.setMode(state.normalizationMode);
    replayGainService.setTargetLoudness(state.targetLoudness);
    replayGainService.setPreventClipping(state.preventClipping);
  }

  Future<void> _save() async {
    await _box?.put('appSettings', state.toJson());
  }

  Future<void> setPlaybackSpeed(double speed) async {
    state = state.copyWith(playbackSpeed: speed);
    await _save();
  }

  Future<void> setDefaultSort(SortOrder order) async {
    state = state.copyWith(defaultSort: order);
    await _save();
  }

  Future<void> toggleSortAscending() async {
    state = state.copyWith(sortAscending: !state.sortAscending);
    await _save();
  }

  Future<void> setAudioQuality(AudioQuality quality) async {
    state = state.copyWith(audioQuality: quality);
    await _save();
  }

  Future<void> toggleDynamicColors() async {
    state = state.copyWith(dynamicColorsEnabled: !state.dynamicColorsEnabled);
    await _save();
  }

  Future<void> toggleGaplessPlayback() async {
    state = state.copyWith(gaplessPlayback: !state.gaplessPlayback);
    await audioHandler.setGaplessPlaybackEnabled(state.gaplessPlayback);
    await _save();
  }

  Future<void> setCrossfadeMode(CrossfadeMode mode) async {
    state = state.copyWith(crossfadeMode: mode);
    audioHandler.setCrossfadeEnabled(mode != CrossfadeMode.off);
    audioHandler.setSmartCrossfadeEnabled(mode == CrossfadeMode.smart);
    await _save();
  }

  Future<void> setCrossfadeDuration(int seconds) async {
    state = state.copyWith(crossfadeDuration: seconds);
    audioHandler.setCrossfadeDuration(seconds);
    await _save();
  }

  // Convenience method to cycle through crossfade modes
  Future<void> cycleCrossfadeMode() async {
    final nextIndex = (state.crossfadeMode.index + 1) % CrossfadeMode.values.length;
    await setCrossfadeMode(CrossfadeMode.values[nextIndex]);
  }

  Future<void> setNormalizationMode(NormalizationMode mode) async {
    state = state.copyWith(normalizationMode: mode);
    replayGainService.setMode(mode);
    await _save();
  }

  Future<void> setTargetLoudness(double lufs) async {
    final clamped = lufs.clamp(-24.0, -6.0);
    state = state.copyWith(targetLoudness: clamped);
    replayGainService.setTargetLoudness(clamped);
    await _save();
  }

  Future<void> setPreventClipping(bool prevent) async {
    state = state.copyWith(preventClipping: prevent);
    replayGainService.setPreventClipping(prevent);
    await _save();
  }

  Future<void> resetToDefaults() async {
    state = const AppSettings();
    await audioHandler.setPlaybackSpeed(1.0);
    audioHandler.setCrossfadeEnabled(false);
    audioHandler.setSmartCrossfadeEnabled(false);
    _applyNormalizationSettings();
    await audioEffectsService.resetToDefaults();
    await _save();
  }

  // Audio effects setters
  Future<void> setReverbEnabled(bool enabled) async {
    state = state.copyWith(reverbEnabled: enabled);
    await audioEffectsService.setReverbEnabled(enabled);
    await _save();
  }

  Future<void> setReverbPreset(ReverbPreset preset) async {
    state = state.copyWith(reverbPreset: preset, reverbEnabled: preset != ReverbPreset.none);
    if (preset != ReverbPreset.none) {
      await audioEffectsService.setReverbEnabled(true);
      await audioEffectsService.setReverbPreset(preset);
    } else {
      await audioEffectsService.setReverbEnabled(false);
    }
    await _save();
  }

  Future<void> setPitchSemitones(double semitones) async {
    final clamped = semitones.clamp(-12.0, 12.0);
    state = state.copyWith(pitchSemitones: clamped);
    await audioHandler.setPitch(clamped);
    await _save();
  }

  // Visualizer settings
  Future<void> setVisualizerStyle(VisualizerStyleSetting style) async {
    state = state.copyWith(visualizerStyle: style);
    await _save();
  }

  Future<void> setVisualizerEnabled(bool enabled) async {
    state = state.copyWith(visualizerEnabled: enabled);
    // Also enable/disable the native AudioPulse FFT analysis to save battery
    // When visualizer is off, there's no need for real-time audio analysis
    await audioHandler.setAudioPulseEnabled(enabled);
    await _save();
  }

  Future<void> cycleVisualizerStyle() async {
    final nextIndex = (state.visualizerStyle.index + 1) % VisualizerStyleSetting.values.length;
    await setVisualizerStyle(VisualizerStyleSetting.values[nextIndex]);
  }

  // Import settings
  Future<void> setStripCommentsOnImport(bool enabled) async {
    state = state.copyWith(stripCommentsOnImport: enabled);
    await _save();
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(),
);

// Playback speed options
const playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
