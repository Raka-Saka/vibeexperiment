import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'log_service.dart';

/// Reverb preset types matching Android PresetReverb
enum ReverbPreset {
  none(-1, 'None'),
  smallRoom(0, 'Small Room'),
  mediumRoom(1, 'Medium Room'),
  largeRoom(2, 'Large Room'),
  mediumHall(3, 'Medium Hall'),
  largeHall(4, 'Large Hall'),
  plate(5, 'Plate');

  final int id;
  final String name;

  const ReverbPreset(this.id, this.name);

  static ReverbPreset fromId(int id) {
    return ReverbPreset.values.firstWhere(
      (p) => p.id == id,
      orElse: () => ReverbPreset.none,
    );
  }
}

/// Custom reverb settings for environmental reverb
class CustomReverbSettings {
  final int roomLevel; // -9000 to 0 millibels
  final int reverbLevel; // -9000 to 2000 millibels
  final int decayTime; // 100 to 20000 ms
  final int reverbDelay; // 0 to 100 ms

  const CustomReverbSettings({
    this.roomLevel = -1000,
    this.reverbLevel = -1000,
    this.decayTime = 1000,
    this.reverbDelay = 40,
  });

  // Normalized getters (0.0 to 1.0)
  double get roomLevelNormalized => (roomLevel + 9000) / 9000;
  double get reverbLevelNormalized => (reverbLevel + 9000) / 11000;
  double get decayTimeNormalized => (decayTime - 100) / 19900;
  double get reverbDelayNormalized => reverbDelay / 100;

  CustomReverbSettings copyWith({
    int? roomLevel,
    int? reverbLevel,
    int? decayTime,
    int? reverbDelay,
  }) {
    return CustomReverbSettings(
      roomLevel: roomLevel ?? this.roomLevel,
      reverbLevel: reverbLevel ?? this.reverbLevel,
      decayTime: decayTime ?? this.decayTime,
      reverbDelay: reverbDelay ?? this.reverbDelay,
    );
  }

  Map<String, dynamic> toJson() => {
    'roomLevel': roomLevel,
    'reverbLevel': reverbLevel,
    'decayTime': decayTime,
    'reverbDelay': reverbDelay,
  };

  factory CustomReverbSettings.fromJson(Map<String, dynamic> json) {
    return CustomReverbSettings(
      roomLevel: json['roomLevel'] as int? ?? -1000,
      reverbLevel: json['reverbLevel'] as int? ?? -1000,
      decayTime: json['decayTime'] as int? ?? 1000,
      reverbDelay: json['reverbDelay'] as int? ?? 40,
    );
  }

  /// Create from normalized values (0.0 to 1.0)
  factory CustomReverbSettings.fromNormalized({
    double roomLevel = 0.89, // Default: ~-1000
    double reverbLevel = 0.73, // Default: ~-1000
    double decayTime = 0.05, // Default: ~1000ms
    double reverbDelay = 0.4, // Default: ~40ms
  }) {
    return CustomReverbSettings(
      roomLevel: ((roomLevel * 9000) - 9000).round().clamp(-9000, 0),
      reverbLevel: ((reverbLevel * 11000) - 9000).round().clamp(-9000, 2000),
      decayTime: ((decayTime * 19900) + 100).round().clamp(100, 20000),
      reverbDelay: (reverbDelay * 100).round().clamp(0, 100),
    );
  }
}

/// Service for managing audio effects (reverb, pitch, tempo)
/// Pitch and tempo are handled via just_audio directly.
/// Reverb uses native Android PresetReverb/EnvironmentalReverb.
class AudioEffectsService {
  static const _channel = MethodChannel('com.vibeplay/audio_effects');
  static const String _boxName = 'audio_effects_settings';

  Box? _box;
  bool _initialized = false;

  // Current state
  bool _reverbEnabled = false;
  ReverbPreset _currentPreset = ReverbPreset.none;
  CustomReverbSettings _customSettings = const CustomReverbSettings();

  // Pitch and tempo (stored here, applied via audio_handler)
  double _pitch = 1.0; // 0.5 to 2.0 (1.0 = normal)
  double _tempo = 1.0; // 0.5 to 2.0 (1.0 = normal)

  // Getters
  bool get reverbEnabled => _reverbEnabled;
  ReverbPreset get currentPreset => _currentPreset;
  CustomReverbSettings get customSettings => _customSettings;
  double get pitch => _pitch;
  double get tempo => _tempo;

  Future<void> init() async {
    if (_initialized) return;

    try {
      _box = await Hive.openBox(_boxName);

      // Load saved settings
      _reverbEnabled = _box?.get('reverbEnabled') as bool? ?? false;
      _currentPreset = ReverbPreset.fromId(_box?.get('reverbPreset') as int? ?? -1);

      final customJson = _box?.get('customReverb') as Map?;
      if (customJson != null) {
        _customSettings = CustomReverbSettings.fromJson(
          Map<String, dynamic>.from(customJson),
        );
      }

      _pitch = (_box?.get('pitch') as num?)?.toDouble() ?? 1.0;
      _tempo = (_box?.get('tempo') as num?)?.toDouble() ?? 1.0;

      _initialized = true;
      Log.audio.d('AudioEffects: Initialized - reverb=${_reverbEnabled}, preset=${_currentPreset.name}, pitch=$_pitch, tempo=$_tempo');
    } catch (e) {
      Log.audio.d('AudioEffects: Failed to initialize: $e');
    }
  }

  Future<void> _save() async {
    await _box?.put('reverbEnabled', _reverbEnabled);
    await _box?.put('reverbPreset', _currentPreset.id);
    await _box?.put('customReverb', _customSettings.toJson());
    await _box?.put('pitch', _pitch);
    await _box?.put('tempo', _tempo);
  }

  Future<void> setAudioSessionId(int sessionId) async {
    try {
      await _channel.invokeMethod('setAudioSessionId', {'sessionId': sessionId});

      // Apply current settings
      if (_reverbEnabled) {
        await _applyReverbSettings();
      }
    } catch (e) {
      Log.audio.d('AudioEffects: Failed to set audio session ID: $e');
    }
  }

  // Reverb methods
  Future<bool> setReverbEnabled(bool enabled) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'setReverbEnabled',
        {'enabled': enabled},
      );
      _reverbEnabled = enabled;
      await _save();
      Log.audio.d('AudioEffects: Reverb enabled: $enabled');
      return result ?? false;
    } catch (e) {
      Log.audio.d('AudioEffects: Failed to set reverb enabled: $e');
      return false;
    }
  }

  Future<bool> setReverbPreset(ReverbPreset preset) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'setReverbPreset',
        {'preset': preset.id},
      );
      _currentPreset = preset;
      await _save();
      Log.audio.d('AudioEffects: Set reverb preset: ${preset.name}');
      return result ?? false;
    } catch (e) {
      Log.audio.d('AudioEffects: Failed to set reverb preset: $e');
      return false;
    }
  }

  Future<bool> setCustomReverb(CustomReverbSettings settings) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'setCustomReverb',
        {
          'roomLevel': settings.roomLevel,
          'reverbLevel': settings.reverbLevel,
          'decayTime': settings.decayTime,
          'reverbDelay': settings.reverbDelay,
        },
      );
      _customSettings = settings;
      _currentPreset = ReverbPreset.none; // Custom mode
      await _save();
      Log.audio.d('AudioEffects: Set custom reverb');
      return result ?? false;
    } catch (e) {
      Log.audio.d('AudioEffects: Failed to set custom reverb: $e');
      return false;
    }
  }

  Future<void> _applyReverbSettings() async {
    await setReverbEnabled(_reverbEnabled);
    if (_currentPreset != ReverbPreset.none) {
      await setReverbPreset(_currentPreset);
    } else {
      await setCustomReverb(_customSettings);
    }
  }

  // Pitch methods (stored here, applied via audio_handler)
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    await _save();
    Log.audio.d('AudioEffects: Set pitch: $_pitch');
  }

  // Tempo methods (stored here, applied via audio_handler)
  Future<void> setTempo(double tempo) async {
    _tempo = tempo.clamp(0.5, 2.0);
    await _save();
    Log.audio.d('AudioEffects: Set tempo: $_tempo');
  }

  /// Reset all effects to defaults
  Future<void> resetToDefaults() async {
    _reverbEnabled = false;
    _currentPreset = ReverbPreset.none;
    _customSettings = const CustomReverbSettings();
    _pitch = 1.0;
    _tempo = 1.0;

    await setReverbEnabled(false);
    await _save();
    Log.audio.d('AudioEffects: Reset to defaults');
  }

  Future<Map<String, dynamic>?> getReverbProperties() async {
    try {
      final result = await _channel.invokeMethod<Map>('getReverbProperties');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e) {
      Log.audio.d('AudioEffects: Failed to get reverb properties: $e');
      return null;
    }
  }

  Future<void> release() async {
    try {
      await _channel.invokeMethod('release');
    } catch (e) {
      Log.audio.d('AudioEffects: Failed to release: $e');
    }
  }
}

// Global instance
final audioEffectsService = AudioEffectsService();
