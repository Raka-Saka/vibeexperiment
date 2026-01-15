class EqualizerPreset {
  final String name;
  final List<double> bands; // 10 bands: 32Hz, 64Hz, 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz, 8kHz, 16kHz
  final double bassBoost;
  final double virtualizer;

  const EqualizerPreset({
    required this.name,
    required this.bands,
    this.bassBoost = 0.0,
    this.virtualizer = 0.0,
  });

  EqualizerPreset copyWith({
    String? name,
    List<double>? bands,
    double? bassBoost,
    double? virtualizer,
  }) {
    return EqualizerPreset(
      name: name ?? this.name,
      bands: bands ?? List.from(this.bands),
      bassBoost: bassBoost ?? this.bassBoost,
      virtualizer: virtualizer ?? this.virtualizer,
    );
  }
}

class EqualizerPresets {
  static const int bandCount = 10;

  static const flat = EqualizerPreset(
    name: 'Flat',
    bands: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
  );

  static const rock = EqualizerPreset(
    name: 'Rock',
    bands: [5.0, 4.0, 3.0, 1.0, -1.0, -1.0, 1.0, 3.0, 4.0, 5.0],
    bassBoost: 0.3,
  );

  static const pop = EqualizerPreset(
    name: 'Pop',
    bands: [-1.0, 0.0, 2.0, 3.0, 4.0, 4.0, 3.0, 2.0, 1.0, -1.0],
  );

  static const jazz = EqualizerPreset(
    name: 'Jazz',
    bands: [4.0, 3.0, 1.0, 2.0, -1.0, -1.0, 0.0, 1.0, 3.0, 4.0],
    virtualizer: 0.4,
  );

  static const classical = EqualizerPreset(
    name: 'Classical',
    bands: [5.0, 4.0, 3.0, 2.0, -1.0, -1.0, 0.0, 2.0, 3.0, 4.0],
    virtualizer: 0.3,
  );

  static const electronic = EqualizerPreset(
    name: 'Electronic',
    bands: [5.0, 4.0, 3.0, 0.0, -2.0, -1.0, 0.0, 2.0, 4.0, 5.0],
    bassBoost: 0.5,
  );

  static const hiphop = EqualizerPreset(
    name: 'Hip Hop',
    bands: [5.0, 5.0, 4.0, 3.0, 1.0, 0.0, 1.0, 0.0, 2.0, 3.0],
    bassBoost: 0.6,
  );

  static const rnb = EqualizerPreset(
    name: 'R&B',
    bands: [3.0, 4.0, 5.0, 3.0, 2.0, 2.0, 3.0, 2.0, 3.0, 3.0],
    bassBoost: 0.4,
  );

  static const acoustic = EqualizerPreset(
    name: 'Acoustic',
    bands: [4.0, 3.0, 2.0, 1.0, 1.0, 1.0, 2.0, 2.0, 3.0, 3.0],
    virtualizer: 0.2,
  );

  static const vocalBoost = EqualizerPreset(
    name: 'Vocal Boost',
    bands: [-3.0, -2.0, -1.0, 1.0, 3.0, 4.0, 4.0, 3.0, 2.0, 0.0],
  );

  static const bassBooster = EqualizerPreset(
    name: 'Bass Boost',
    bands: [6.0, 5.0, 4.0, 3.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    bassBoost: 0.8,
  );

  static const trebleBoost = EqualizerPreset(
    name: 'Treble Boost',
    bands: [0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 2.0, 4.0, 5.0, 6.0],
  );

  static const loudness = EqualizerPreset(
    name: 'Loudness',
    bands: [6.0, 5.0, 3.0, 0.0, -1.0, -1.0, 0.0, 3.0, 5.0, 6.0],
    bassBoost: 0.4,
  );

  static const small = EqualizerPreset(
    name: 'Small Speakers',
    bands: [6.0, 5.0, 4.0, 3.0, 2.0, 0.0, -1.0, -2.0, -2.0, -3.0],
    bassBoost: 0.5,
  );

  static const live = EqualizerPreset(
    name: 'Live',
    bands: [-2.0, -1.0, 0.0, 2.0, 3.0, 4.0, 4.0, 3.0, 3.0, 4.0],
    virtualizer: 0.6,
  );

  static const podcast = EqualizerPreset(
    name: 'Podcast',
    bands: [-2.0, -1.0, 0.0, 2.0, 4.0, 5.0, 4.0, 2.0, 0.0, -1.0],
  );

  static const all = [
    flat,
    rock,
    pop,
    jazz,
    classical,
    electronic,
    hiphop,
    rnb,
    acoustic,
    vocalBoost,
    bassBooster,
    trebleBoost,
    loudness,
    small,
    live,
    podcast,
  ];

  static const bandFrequencies = [
    '32',
    '64',
    '125',
    '250',
    '500',
    '1k',
    '2k',
    '4k',
    '8k',
    '16k',
  ];

  // Full frequency labels with Hz/kHz
  static const bandLabels = [
    '32Hz',
    '64Hz',
    '125Hz',
    '250Hz',
    '500Hz',
    '1kHz',
    '2kHz',
    '4kHz',
    '8kHz',
    '16kHz',
  ];
}
