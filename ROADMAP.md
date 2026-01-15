# VibePlay Roadmap

> **Last Updated:** January 16, 2026
> **Current Version:** 1.3.0 (Beta)
> **Status:** Production-hardened, working on UI polish

---

## Design Philosophy

### Offline-First Architecture
VibePlay is designed to work **100% offline** for all core functionality. Your music, your device, no internet required.

**Core Features (Always Offline):**
- Music playback, queue, shuffle, repeat
- Equalizer & all audio effects
- Visualizers (GPU shaders)
- Playlists & favorites
- Tag editing (local files)
- Lyrics (embedded & local .lrc files)
- Library browsing & search
- Sleep timer
- Home screen widgets
- All settings & preferences

**Optional Online Features (Require Internet, User-Initiated):**
- YouTube upload (explicit user action)
- Online lyrics fetch (future, opt-in)
- Last.fm scrobbling (future, opt-in)
- Cloud backup/sync (future, opt-in)
- Metadata fetch from online sources (future, opt-in)

**Privacy Principles:**
- No analytics or tracking
- No ads
- No account required for core features
- Your music data stays on your device

---

## Current Features (Implemented)

### Core Playback
- [x] Custom native audio engine (VibeAudioEngine) with MediaCodec decoding
- [x] just_audio fallback for compatibility
- [x] Gapless playback (ConcatenatingAudioSource + native)
- [x] Crossfade (1-12 seconds, configurable)
- [x] Playback speed control
- [x] Shuffle and repeat modes (off/one/all)
- [x] Queue management (play next, add to queue, remove, reorder)
- [x] Background playback with media notifications

### Audio Enhancement
- [x] **10-band hardware-accelerated equalizer** (DynamicsProcessing API, Android 9+)
- [x] 15+ EQ presets (Rock, Pop, Jazz, Classical, Hip-Hop, etc.)
- [x] Bass boost and virtualizer effects
- [x] Spatial audio toggle
- [x] Reverb presets (Small/Medium/Large Room, Hall, Plate)
- [x] Volume normalization service (estimation-based, native LUFS pending)

### Visualization
- [x] **Custom FFT audio analysis engine** (AudioPulse - 2048-point FFT)
- [x] 7-band frequency extraction (Sub-bass → Brilliance)
- [x] Real-time beat detection with BPM estimation
- [x] **5 GPU shader visualizers:**
  - Aurora (Northern Lights)
  - Celestial Halos (Neon Rings)
  - Resonance (Frequency Spectrum)
  - Ripples (Water Effect)
  - Harmonograph (Lissajous Curves)
- [x] Full-screen visualizer mode with auto-hide UI
- [x] Tap to cycle / long-press to pick visualizer

### Library & Organization
- [x] Music library scanning (OnAudioQuery)
- [x] Albums, Artists, Songs, Playlists views
- [x] Library sorting options
- [x] Duplicate song finder (by file size)
- [x] LRU artwork cache (50 items)
- [x] Song list caching with timestamp validation

### Tag Editor
- [x] Read/write ID3 tags (v1, v2.3, v2.4)
- [x] Edit: Title, Artist, Album, Genre, Year, Track#, Composer, BPM, Lyrics
- [x] Album artwork replacement
- [x] Batch find & replace
- [x] URL tag removal (WOAS, WOAR, etc.)
- [x] **Limitation:** MP3 files only

### Lyrics
- [x] Synced lyrics display (LRC format)
- [x] Embedded ID3 lyrics (USLT) support
- [x] External .lrc file detection
- [x] Real-time sync tracking

### Playlists
- [x] Create, edit, delete playlists
- [x] Favorites playlist (auto-created)
- [x] Add/remove songs from playlists
- [x] Hive-based persistence

### YouTube Integration *(Optional, Requires Internet)*
- [x] Google OAuth 2.0 sign-in
- [x] Waveform video generation (native, offline)
- [x] YouTube upload with progress tracking
- [x] Privacy status selection

### Widgets
- [x] Small widget (4x1) - Play/pause, skip controls
- [x] Medium widget (4x2) - Album art, song info, full controls

### Other
- [x] Sleep timer with presets (5min - 2hr)
- [x] Song info dialog
- [x] Share functionality
- [x] Settings persistence (Hive)
- [x] File deletion support

---

## Critical Issues (Must Fix Before Release)

### Security
- [x] **Move OAuth credentials to secure config** - Client ID moved to secure config
- [x] **Remove client_secret JSON from repo** - Added to .gitignore
- [x] **Configure release signing** - Release keystore configured

### Code Quality
- [x] **Add unit tests** - 99 tests implemented
- [x] **Add integration tests** - Playback, EQ, playlists covered
- [x] **Replace print() statements** - Structured Log service implemented
- [x] **Fix deprecated API** - `withOpacity` → `withValues(alpha:)` migrated

### Performance
- [ ] Review visualizer FFT on main thread
- [ ] Large library pagination (10,000+ songs)

---

## Phase 1: Production Hardening ✅
**Priority: CRITICAL** | Target: v1.2 | **Status: Complete**

### Testing Infrastructure
- [x] Set up Flutter test framework
- [x] Unit tests for core services:
  - [x] AudioHandler (playback state, queue operations)
  - [x] EqualizerService (band manipulation, presets)
  - [x] PlaylistRepository (CRUD operations)
  - [x] TagEditorService (read/write validation)
  - [x] ReplayGainService (gain calculations)
- [x] Widget tests for key screens
- [x] Integration tests for end-to-end playback

### Logging & Crash Reporting
- [x] Implement structured logging (Log service with categories)
- [ ] Local crash logs (saved to device, user can share if desired)
- [ ] Error boundary for graceful degradation
- [ ] *(Optional)* Firebase Crashlytics or Sentry - opt-in only

### Build & Release
- [x] Create release keystore
- [x] Configure ProGuard/R8 rules
- [ ] Set up CI/CD pipeline
- [ ] Play Store listing preparation

---

## Phase 2: Volume Normalization & Audio Polish ✅
**Priority: High** | Target: v1.2 | **Status: Complete**

### Native LUFS Analysis
- [x] Implement native loudness measurement (MediaCodec + ITU-R BS.1770-4)
- [x] Connect to existing ReplayGainService
- [x] Background batch analysis for library
- [x] Progress indicator during analysis

### Smart Crossfade
- [x] Detect track endings (silence detection)
- [x] Auto-adjust crossfade duration based on track
- [x] Skip crossfade for live albums / continuous mixes

### EQ Enhancements
- [x] Custom preset save/load
- [x] Per-song EQ memory (optional)
- [x] EQ curve visualization

---

## Phase 3: Smart Playlists & Statistics
**Priority: High** | Target: v1.3

### Play Statistics
- [x] Track play counts per song
- [x] Record listening history with timestamps
- [x] Total listening time tracking
- [x] Daily/weekly/monthly stats view

### Smart Playlists
- [x] Recently Played (last 50/100 songs)
- [x] Most Played (top tracks)
- [x] Recently Added (last 30 days)
- [x] Heavy Rotation (favorites by completion rate)
- [x] Rediscover (forgotten songs)
- [ ] Genre-based auto-playlists

### Rule-Based Playlists
- [ ] Filter by: artist, album, genre, year, play count, rating
- [ ] Combine rules with AND/OR logic
- [ ] Auto-update when library changes

---

## Phase 4: Android Auto & Connectivity
**Priority: Medium-High** | Target: v1.4

### Android Auto
- [ ] MediaBrowserService implementation
- [ ] Browse library from car display (artists, albums, playlists)
- [ ] Voice commands ("Play [artist/album/song]")
- [ ] Album art on car screen
- [ ] Queue management from car UI

### Chromecast Support *(Requires Local Network)*
- [ ] Cast audio to Chromecast devices
- [ ] Cast to Google Home / Nest speakers
- [ ] Remote queue management
- [ ] Handoff between phone and cast

### Last.fm Integration *(Optional, Requires Internet)*
- [ ] Scrobble tracks to Last.fm
- [ ] Now Playing updates
- [ ] View scrobble history
- [ ] Love/unlove tracks
- [ ] Offline queue (scrobble when back online)

---

## Phase 5: Enhanced Widgets & UI
**Priority: Medium** | Target: v1.5

### More Widgets
- [ ] Large widget (4x4) - Full controls + queue preview + progress
- [ ] Extra-small widget (2x1) - Mini play/pause

### Lock Screen & Notifications
- [ ] Enhanced lock screen controls
- [ ] Custom notification layout
- [ ] Quick actions in notification

### Theme System
- [ ] Light mode
- [ ] AMOLED black mode
- [ ] Custom accent color picker
- [ ] Per-album theme option
- [ ] **Dynamic Colors** - Extract dominant colors from album art and adapt UI
- [ ] Material You adaptive colors (system-wide dynamic theming)

### Audio Engine Enhancements
- [ ] **Pitch adjustment for VibeEngine** - Requires SoundTouch DSP library integration
- [ ] Time stretching (change tempo without pitch)

---

## Phase 6: Lyrics & Metadata Enhancements
**Priority: Medium** | Target: v1.6

### Online Lyrics *(Optional, Requires Internet)*
- [ ] Fetch lyrics from online sources (Musixmatch, Genius API)
- [ ] Auto-match by song title + artist
- [ ] **Cache fetched lyrics locally** (works offline after fetch)
- [ ] Manual search/correction
- [ ] Save fetched lyrics as .lrc files

### Lyrics Features
- [ ] Floating lyrics overlay (mini player)
- [ ] Lyrics editing & sync adjustment
- [ ] Export lyrics to .lrc file
- [ ] Karaoke mode (center-stage display)

### Tag Editor Improvements
- [ ] FLAC/OGG/M4A tag support (offline)
- [ ] Auto-fetch metadata from MusicBrainz/Discogs *(optional, online)*
- [ ] Batch artwork download *(optional, online)*
- [ ] Duplicate metadata cleanup (offline)
- [ ] **Cache fetched metadata locally**

---

## Phase 7: Advanced Features
**Priority: Low** | Target: v2.0+

### Folder Browsing
- [ ] Browse by folder structure
- [ ] Play entire folders
- [ ] Folder-based playlists
- [ ] Exclude folders from scan

### Audio Routing
- [ ] Output device selection
- [ ] USB DAC support
- [ ] Bluetooth codec preferences (aptX, LDAC, AAC)

### Backup & Sync
- [ ] Export playlists to M3U/PLS (offline, local file)
- [ ] Import playlists (offline, local file)
- [ ] Full library backup to local storage (offline)
- [ ] Cloud sync *(optional, requires internet)* - Google Drive / custom server

### Wear OS
- [ ] Playback controls on watch
- [ ] Browse playlists on watch
- [ ] Standalone offline playback
- [ ] Sync selected playlists

### AI Features *(Future - Prefer On-Device Models)*
- [ ] AI playlist generation from text prompts
- [ ] Mood-based suggestions
- [ ] "More like this" recommendations
- [ ] Time-of-day smart mixes
- [ ] *Goal: Use on-device ML models (TFLite) to keep features offline*

### Utility
- [ ] Ringtone cutter (trim + set as ringtone)
- [ ] Podcast support (RSS feeds)
- [ ] Sleep timer with fade-out
- [ ] Alarm clock integration

---

## Technical Debt Tracker

| Issue | Priority | Status |
|-------|----------|--------|
| Zero test coverage | Critical | Done (99 tests) |
| 328 print() statements | High | Done (Log service) |
| OAuth credentials in source | High | Done |
| Debug signing in release | High | Done |
| `withOpacity` deprecated | Medium | Done |
| Native LUFS not connected | Medium | Done |
| Song list caching | Low | Done |
| Artwork LRU cache | Low | Done |
| Memory leak fixes | Low | Done |

---

## Version History & Planning

### v1.0 - Initial Release ✅
- Basic playback, library, playlists
- Standard equalizer
- Sleep timer, shuffle, repeat

### v1.1 - Audio Enhancement ✅ (Current)
- Custom VibeAudioEngine
- 10-band hardware EQ
- Gapless playback + Crossfade
- 5 GPU shader visualizers
- Home screen widgets
- Tag editor
- YouTube upload
- Lyrics support

### v1.2 - Production Ready ✅
- [x] Test coverage (unit + integration)
- [x] Proper logging
- [x] Security fixes (credentials, signing)
- [x] Native LUFS analysis
- [x] Smart crossfade (silence/fade detection)

### v1.3 - Smart Library ✅
- [x] Play statistics
- [x] Smart playlists
- [x] Custom EQ presets
- [x] EQ persistence across app restarts

### v1.4 - Connectivity
- [ ] Android Auto
- [ ] Chromecast
- [ ] Last.fm scrobbling

### v1.5 - UI Polish
- [ ] More widgets
- [ ] Theme system (light mode, AMOLED black)
- [ ] Dynamic colors from album art
- [ ] Material You
- [ ] Pitch adjustment for VibeEngine (SoundTouch)

### v2.0 - Advanced
- [ ] AI features
- [ ] Wear OS
- [ ] Cloud sync
- [ ] Folder browsing

---

## Architecture Notes

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
│  VideoGenerator, Widgets                                     │
├─────────────────────────────────────────────────────────────┤
│                   Android APIs                               │
│  MediaCodec, AudioTrack, DynamicsProcessing, MediaStore     │
└─────────────────────────────────────────────────────────────┘
```

---

## Contributing

When adding new features:
1. Create feature branch from `main`
2. Add unit tests for new code
3. Update this roadmap
4. Submit PR with description

---

*This roadmap is a living document and will be updated as development progresses.*
