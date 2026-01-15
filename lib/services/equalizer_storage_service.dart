import 'package:hive/hive.dart';
import '../features/equalizer/data/equalizer_presets.dart';
import 'log_service.dart';

/// Custom EQ preset that can be saved/loaded
class CustomPreset {
  final String id;
  final String name;
  final List<double> bands;
  final double bassBoost;
  final double virtualizer;
  final DateTime createdAt;

  CustomPreset({
    required this.id,
    required this.name,
    required this.bands,
    this.bassBoost = 0.0,
    this.virtualizer = 0.0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'bands': bands,
    'bassBoost': bassBoost,
    'virtualizer': virtualizer,
    'createdAt': createdAt.toIso8601String(),
  };

  factory CustomPreset.fromJson(Map<String, dynamic> json) => CustomPreset(
    id: json['id'] as String,
    name: json['name'] as String,
    bands: (json['bands'] as List).map((e) => (e as num).toDouble()).toList(),
    bassBoost: (json['bassBoost'] as num?)?.toDouble() ?? 0.0,
    virtualizer: (json['virtualizer'] as num?)?.toDouble() ?? 0.0,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now(),
  );

  EqualizerPreset toEqualizerPreset() => EqualizerPreset(
    name: name,
    bands: bands,
    bassBoost: bassBoost,
    virtualizer: virtualizer,
  );
}

/// Per-song EQ settings
class SongEQSettings {
  final String songPath;
  final List<double> bands;
  final double bassBoost;
  final double virtualizer;
  final DateTime savedAt;

  SongEQSettings({
    required this.songPath,
    required this.bands,
    this.bassBoost = 0.0,
    this.virtualizer = 0.0,
    DateTime? savedAt,
  }) : savedAt = savedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'songPath': songPath,
    'bands': bands,
    'bassBoost': bassBoost,
    'virtualizer': virtualizer,
    'savedAt': savedAt.toIso8601String(),
  };

  factory SongEQSettings.fromJson(Map<String, dynamic> json) => SongEQSettings(
    songPath: json['songPath'] as String,
    bands: (json['bands'] as List).map((e) => (e as num).toDouble()).toList(),
    bassBoost: (json['bassBoost'] as num?)?.toDouble() ?? 0.0,
    virtualizer: (json['virtualizer'] as num?)?.toDouble() ?? 0.0,
    savedAt: json['savedAt'] != null
        ? DateTime.parse(json['savedAt'] as String)
        : DateTime.now(),
  );
}

/// Global EQ state that persists across app restarts
class GlobalEQState {
  final bool isEnabled;
  final List<double> bands;
  final double bassBoost;
  final double virtualizer;
  final String? presetName;

  GlobalEQState({
    this.isEnabled = false,
    List<double>? bands,
    this.bassBoost = 0.0,
    this.virtualizer = 0.0,
    this.presetName,
  }) : bands = bands ?? List.filled(10, 0.0);

  Map<String, dynamic> toJson() => {
    'isEnabled': isEnabled,
    'bands': bands,
    'bassBoost': bassBoost,
    'virtualizer': virtualizer,
    'presetName': presetName,
  };

  factory GlobalEQState.fromJson(Map<String, dynamic> json) => GlobalEQState(
    isEnabled: json['isEnabled'] as bool? ?? false,
    bands: (json['bands'] as List?)?.map((e) => (e as num).toDouble()).toList(),
    bassBoost: (json['bassBoost'] as num?)?.toDouble() ?? 0.0,
    virtualizer: (json['virtualizer'] as num?)?.toDouble() ?? 0.0,
    presetName: json['presetName'] as String?,
  );
}

/// Service for storing and retrieving custom EQ presets and per-song settings
class EqualizerStorageService {
  static const String _boxName = 'equalizer_storage';

  Box? _box;
  final Map<String, CustomPreset> _customPresets = {};
  final Map<String, SongEQSettings> _songSettings = {};
  bool _perSongEnabled = false;
  GlobalEQState _globalState = GlobalEQState();

  bool get perSongEnabled => _perSongEnabled;
  GlobalEQState get globalState => _globalState;
  List<CustomPreset> get customPresets => _customPresets.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);

    // Load custom presets
    final presetsData = _box?.get('customPresets') as Map<dynamic, dynamic>?;
    if (presetsData != null) {
      for (final entry in presetsData.entries) {
        try {
          _customPresets[entry.key as String] = CustomPreset.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        } catch (e) {
          Log.eq.d('EQStorage: Error loading preset: $e');
        }
      }
    }

    // Load song settings
    final songData = _box?.get('songSettings') as Map<dynamic, dynamic>?;
    if (songData != null) {
      for (final entry in songData.entries) {
        try {
          _songSettings[entry.key as String] = SongEQSettings.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        } catch (e) {
          Log.eq.d('EQStorage: Error loading song settings: $e');
        }
      }
    }

    // Load per-song enabled setting
    _perSongEnabled = _box?.get('perSongEnabled') as bool? ?? false;

    // Load global EQ state
    final globalData = _box?.get('globalEQState') as Map<dynamic, dynamic>?;
    if (globalData != null) {
      try {
        _globalState = GlobalEQState.fromJson(Map<String, dynamic>.from(globalData));
      } catch (e) {
        Log.eq.d('EQStorage: Error loading global state: $e');
      }
    }

    Log.eq.d('EQStorage: Loaded ${_customPresets.length} custom presets, ${_songSettings.length} song settings, EQ enabled: ${_globalState.isEnabled}');
  }

  Future<void> _savePresets() async {
    final data = <String, Map<String, dynamic>>{};
    for (final entry in _customPresets.entries) {
      data[entry.key] = entry.value.toJson();
    }
    await _box?.put('customPresets', data);
  }

  Future<void> _saveSongSettings() async {
    final data = <String, Map<String, dynamic>>{};
    for (final entry in _songSettings.entries) {
      data[entry.key] = entry.value.toJson();
    }
    await _box?.put('songSettings', data);
  }

  // Global EQ state methods

  Future<void> saveGlobalState({
    required bool isEnabled,
    required List<double> bands,
    required double bassBoost,
    required double virtualizer,
    String? presetName,
  }) async {
    _globalState = GlobalEQState(
      isEnabled: isEnabled,
      bands: List.from(bands),
      bassBoost: bassBoost,
      virtualizer: virtualizer,
      presetName: presetName,
    );
    await _box?.put('globalEQState', _globalState.toJson());
  }

  // Custom preset methods

  Future<CustomPreset> saveCustomPreset({
    required String name,
    required List<double> bands,
    double bassBoost = 0.0,
    double virtualizer = 0.0,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final preset = CustomPreset(
      id: id,
      name: name,
      bands: List.from(bands),
      bassBoost: bassBoost,
      virtualizer: virtualizer,
    );

    _customPresets[id] = preset;
    await _savePresets();

    return preset;
  }

  Future<void> updateCustomPreset(CustomPreset preset) async {
    _customPresets[preset.id] = preset;
    await _savePresets();
  }

  Future<void> deleteCustomPreset(String id) async {
    _customPresets.remove(id);
    await _savePresets();
  }

  Future<void> renameCustomPreset(String id, String newName) async {
    final preset = _customPresets[id];
    if (preset != null) {
      _customPresets[id] = CustomPreset(
        id: preset.id,
        name: newName,
        bands: preset.bands,
        bassBoost: preset.bassBoost,
        virtualizer: preset.virtualizer,
        createdAt: preset.createdAt,
      );
      await _savePresets();
    }
  }

  CustomPreset? getCustomPreset(String id) => _customPresets[id];

  // Per-song EQ methods

  Future<void> setPerSongEnabled(bool enabled) async {
    _perSongEnabled = enabled;
    await _box?.put('perSongEnabled', enabled);
  }

  Future<void> saveSongEQ({
    required String songPath,
    required List<double> bands,
    double bassBoost = 0.0,
    double virtualizer = 0.0,
  }) async {
    final settings = SongEQSettings(
      songPath: songPath,
      bands: List.from(bands),
      bassBoost: bassBoost,
      virtualizer: virtualizer,
    );

    _songSettings[songPath] = settings;
    await _saveSongSettings();
  }

  SongEQSettings? getSongEQ(String? songPath) {
    if (songPath == null) return null;
    return _songSettings[songPath];
  }

  Future<void> deleteSongEQ(String songPath) async {
    _songSettings.remove(songPath);
    await _saveSongSettings();
  }

  bool hasSongEQ(String? songPath) {
    if (songPath == null) return false;
    return _songSettings.containsKey(songPath);
  }

  /// Get all songs that have custom EQ settings
  List<String> getSongsWithCustomEQ() => _songSettings.keys.toList();

  /// Clear all per-song settings
  Future<void> clearAllSongEQ() async {
    _songSettings.clear();
    await _saveSongSettings();
  }

  /// Clear all custom presets
  Future<void> clearAllCustomPresets() async {
    _customPresets.clear();
    await _savePresets();
  }
}

// Global instance
final equalizerStorageService = EqualizerStorageService();
