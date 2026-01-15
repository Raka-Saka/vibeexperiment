# VibePlay

A feature-rich, offline-first music player for Android built with Flutter and native Kotlin components.

## Features

### Core Playback
- **Custom Native Audio Engine** (VibeAudioEngine) with MediaCodec decoding
- **Gapless playback** with pre-buffered next track transitions
- **Crossfade** (1-12 seconds, configurable)
- **Smart crossfade** with automatic silence/fade detection
- Playback speed control
- Shuffle and repeat modes (off/one/all)
- Queue management (play next, add to queue, reorder)
- Background playback with media notifications

### Audio Enhancement
- **10-band hardware-accelerated equalizer** (DynamicsProcessing API, Android 9+)
- 15+ EQ presets (Rock, Pop, Jazz, Classical, Hip-Hop, etc.)
- Bass boost and virtualizer effects
- Spatial audio toggle
- Reverb presets (Small/Medium/Large Room, Hall, Plate)
- **Volume normalization** with native LUFS analysis (ITU-R BS.1770-4)

### Visualization
- **Custom FFT audio analysis engine** (AudioPulse - 2048-point FFT)
- 7-band frequency extraction (Sub-bass to Brilliance)
- Real-time beat detection with BPM estimation
- **5 GPU shader visualizers:**
  - Aurora (Northern Lights)
  - Celestial Halos (Neon Rings)
  - Resonance (Frequency Spectrum)
  - Ripples (Water Effect)
  - Harmonograph (Lissajous Curves)
- Full-screen visualizer mode with auto-hide UI

### Library & Organization
- Music library scanning
- Albums, Artists, Songs, Playlists views
- Library sorting options
- Duplicate song finder
- LRU artwork cache
- Song list caching with timestamp validation

### Tag Editor
- Read/write ID3 tags (v1, v2.3, v2.4)
- Edit: Title, Artist, Album, Genre, Year, Track#, Composer, BPM, Lyrics
- Album artwork replacement
- Batch find & replace
- URL tag removal

### Lyrics
- Synced lyrics display (LRC format)
- Embedded ID3 lyrics (USLT) support
- External .lrc file detection
- Real-time sync tracking

### Playlists
- Create, edit, delete playlists
- Favorites playlist
- Add/remove songs from playlists
- Persistent storage with Hive

### Widgets
- Small widget (4x1) - Play/pause, skip controls
- Medium widget (4x2) - Album art, song info, full controls

### Other
- Sleep timer with presets (5min - 2hr)
- Dynamic theme colors from album artwork
- YouTube upload with waveform video generation
- Share functionality

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Flutter UI Layer                        │
│  (Screens, Widgets, Riverpod State Management)              │
├─────────────────────────────────────────────────────────────┤
│                    Service Layer (Dart)                      │
│  AudioHandler, EqualizerService, PlaylistRepository, etc.   │
├─────────────────────────────────────────────────────────────┤
│                  Platform Channels                           │
│  MethodChannel / EventChannel                                │
├─────────────────────────────────────────────────────────────┤
│                Native Layer (Kotlin)                         │
│  VibeAudioEngine, AudioPulse, DynamicsProcessingEQ,         │
│  LoudnessAnalyzer, VideoGenerator, Widgets                  │
├─────────────────────────────────────────────────────────────┤
│                   Android APIs                               │
│  MediaCodec, AudioTrack, DynamicsProcessing, MediaStore     │
└─────────────────────────────────────────────────────────────┘
```

## Requirements

- Android 9.0 (API 28) or higher
- Flutter 3.x
- Kotlin 1.9+

## Building

```bash
# Get dependencies
flutter pub get

# Run in debug mode
flutter run

# Build release APK
flutter build apk --release

# Build App Bundle for Play Store
flutter build appbundle --release
```

## Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── screens/                  # UI screens
│   ├── home_screen.dart
│   ├── player_screen.dart
│   ├── library_screen.dart
│   └── ...
├── services/                 # Business logic
│   ├── audio_handler.dart    # Main playback controller
│   ├── equalizer_service.dart
│   ├── replay_gain_service.dart
│   ├── vibe_audio_service.dart
│   └── ...
├── shared/
│   ├── models/               # Data models
│   └── widgets/              # Reusable widgets
└── visualizers/              # GPU shader visualizers

android/app/src/main/kotlin/com/vibeplay/vibeplay/
├── MainActivity.kt           # Flutter engine setup
├── audio/
│   ├── VibeAudioEngine.kt    # Custom audio engine
│   ├── AudioPulse.kt         # FFT analysis
│   └── LoudnessAnalyzer.kt   # LUFS measurement
├── widget/                   # Home screen widgets
└── ...
```

## Design Philosophy

### Offline-First
VibePlay is designed to work **100% offline** for all core functionality. Your music, your device, no internet required.

### Privacy
- No analytics or tracking
- No ads
- No account required for core features
- Your music data stays on your device

## License

Copyright (c) 2026 Raka-Saka. All rights reserved.

This software is proprietary. No part of this software may be reproduced, distributed, or transmitted in any form or by any means without the prior written permission of the copyright holder.

## Acknowledgments

Built with:
- [Flutter](https://flutter.dev/)
- [just_audio](https://pub.dev/packages/just_audio)
- [audio_service](https://pub.dev/packages/audio_service)
- [Hive](https://pub.dev/packages/hive)
- [Riverpod](https://riverpod.dev/)
