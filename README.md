# VibePlay

A feature-rich, offline-first music player for Android built with Flutter and native Kotlin components.

**Version:** 1.3.1 (Beta)
**Status:** Production-hardened, 13 GPU shader visualizers, full smart playlist support

## Features

### Core Playback
- **Custom Native Audio Engine** (VibeAudioEngine) with MediaCodec decoding
- **Gapless playback** with pre-buffered next track transitions
- **Crossfade** (1-12 seconds, configurable)
- **Smart crossfade** with automatic silence/fade detection
- **Pitch shifting** (Sonic algorithm - WSOLA) without tempo change
- Playback speed control
- Shuffle and repeat modes (off/one/all)
- Queue management (play next, add to queue, reorder)
- Background playback with media notifications

### Audio Enhancement
- **10-band hardware-accelerated equalizer** (DynamicsProcessing API, Android 9+)
- 15+ EQ presets (Rock, Pop, Jazz, Classical, Hip-Hop, etc.)
- **Custom EQ presets** - save and load your own
- **Per-song EQ memory** (optional)
- Bass boost and virtualizer effects
- Spatial audio toggle
- Reverb presets (Small/Medium/Large Room, Hall, Plate)
- **Volume normalization** with native LUFS analysis (ITU-R BS.1770-4)

### Visualization
- **Custom FFT audio analysis engine** (AudioPulse - 2048-point FFT)
- 7-band frequency extraction (Sub-bass to Brilliance)
- Real-time beat detection with BPM estimation
- **13 GPU shader visualizers:**
  - Aurora (Northern Lights)
  - Celestial Halos (Neon Rings)
  - Resonance (Cymatics/Chladni patterns)
  - Ripples (Wave Interference)
  - Harmonograph (Lissajous Curves)
  - Spirograph (Fourier epicycles)
  - Voronoi (Flow field cells)
  - Sunflower (Phyllotaxis spirals)
  - Attractors (Strange attractors - Lorenz/Clifford)
  - Moire (Interference patterns)
  - Pendulum (Pendulum wave simulation)
  - Flames (Fractal flames / IFS)
  - Fractal (Mandelbrot/Julia morphing)
- Full-screen visualizer mode with auto-hide UI
- Tap to cycle / long-press to pick visualizer
- Battery-optimized (pauses when app in background)

### Library & Organization
- Music library scanning (OnAudioQuery)
- **4-tab library view:** Songs, Albums, Artists, Genres
- Library sorting options
- Search across songs, artists, albums
- Duplicate song finder (by file size)
- LRU artwork cache (50 items)
- Song list caching with timestamp validation

### Smart Playlists & Statistics
- **Play Statistics:**
  - Track play counts per song
  - Listening history with timestamps
  - Total listening time tracking
  - Daily/weekly stats visualization
- **Smart Playlists:**
  - Recently Played (last 50/100 songs)
  - Most Played (top tracks)
  - Recently Added (last 30 days)
  - Heavy Rotation (favorites by completion rate)
  - Rediscover (forgotten songs)
- **Rule-Based Playlists:**
  - Filter by: artist, album, genre, year, play count, duration, title
  - Operators: equals, not equals, contains, greater than, less than, between
  - Combine rules with AND/OR logic
  - Auto-update when library changes

### Tag Editor
- Read/write ID3 tags (v1, v2.3, v2.4)
- Edit: Title, Artist, Album, Genre, Year, Track#, Composer, BPM, Lyrics
- Album artwork replacement
- Batch find & replace
- URL tag removal (WOAS, WOAR, etc.)
- *Note: MP3 files only*

### Lyrics
- Synced lyrics display (LRC format)
- Embedded ID3 lyrics (USLT) support
- External .lrc file detection
- Real-time sync tracking

### Playlists
- Create, edit, delete playlists
- Favorites playlist (auto-created)
- Add/remove songs from playlists
- Persistent storage with Hive

### Widgets
- Small widget (4x1) - Play/pause, skip controls
- Medium widget (4x2) - Album art, song info, full controls

### Other
- Sleep timer with presets (5min - 2hr)
- Song info dialog
- YouTube upload with waveform video generation
- Share functionality
- File deletion support

## Architecture

```
+-------------------------------------------------------------+
|                      Flutter UI Layer                        |
|  (Screens, Widgets, Riverpod State Management)              |
+-------------------------------------------------------------+
|                    Service Layer (Dart)                      |
|  AudioHandler, EqualizerService, PlaylistRepository,        |
|  PlayStatisticsService, SmartPlaylistService, etc.          |
+-------------------------------------------------------------+
|                  Platform Channels                           |
|  MethodChannel / EventChannel                                |
+-------------------------------------------------------------+
|                Native Layer (Kotlin)                         |
|  VibeAudioEngine, AudioPulse, DynamicsProcessingEQ,         |
|  LoudnessAnalyzer, SonicPitchShifter, VideoGenerator        |
+-------------------------------------------------------------+
|                   Android APIs                               |
|  MediaCodec, AudioTrack, DynamicsProcessing, MediaStore     |
+-------------------------------------------------------------+
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
# Run all tests (99 tests)
flutter test

# Run with coverage
flutter test --coverage
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── core/
│   └── theme/                # App theming
├── features/
│   ├── library/              # Library browsing (songs, albums, artists, genres)
│   ├── player/               # Now playing screen, mini player
│   ├── playlists/            # Playlist management, rule-based playlists
│   ├── settings/             # App settings
│   └── statistics/           # Play stats, smart playlists
├── services/                 # Business logic
│   ├── audio_handler.dart    # Main playback controller
│   ├── equalizer_service.dart
│   ├── play_statistics_service.dart
│   ├── smart_playlist_service.dart
│   ├── rule_playlist_service.dart
│   └── ...
├── shared/
│   ├── models/               # Data models (Song, Playlist, PlaylistRule, etc.)
│   └── widgets/              # Reusable widgets
└── visualizers/              # GPU shader visualizers (GLSL)

android/app/src/main/kotlin/com/vibeplay/vibeplay/
├── MainActivity.kt           # Flutter engine setup
├── audio/
│   ├── VibeAudioEngine.kt    # Custom audio engine
│   ├── AudioPulse.kt         # FFT analysis
│   ├── LoudnessAnalyzer.kt   # LUFS measurement
│   └── SonicPitchShifter.kt  # Pitch shifting (Sonic)
├── widget/                   # Home screen widgets
└── ...
```

## Design Philosophy

### Offline-First
VibePlay is designed to work **100% offline** for all core functionality. Your music, your device, no internet required.

**Core Features (Always Offline):**
- Music playback, queue, shuffle, repeat
- Equalizer & all audio effects
- Visualizers (GPU shaders)
- Playlists, favorites, smart playlists
- Tag editing (local files)
- Lyrics (embedded & local .lrc files)
- Library browsing & search
- Sleep timer, widgets, all settings

**Optional Online Features (User-Initiated):**
- YouTube upload (explicit user action)

### Privacy
- No analytics or tracking
- No ads
- No account required
- Your music data stays on your device

## Roadmap

See [ROADMAP.md](ROADMAP.md) for detailed development plans.

**Completed:**
- Phase 1: Production Hardening (testing, logging, security)
- Phase 2: Volume Normalization & Audio Polish
- Phase 3: Smart Playlists & Statistics

**Upcoming:**
- Phase 4: Android Auto & Connectivity
- Phase 5: Enhanced Widgets & UI
- Phase 6: Lyrics & Metadata Enhancements

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
- [flutter_shaders](https://pub.dev/packages/flutter_shaders)
