import 'dart:async';
import 'dart:ui' show Color;
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../shared/models/song.dart';
import 'equalizer_service.dart';
import 'audio_analysis_service.dart';
import 'replay_gain_service.dart';
import 'audio_effects_service.dart';
import 'visualizer_service.dart';
import 'vibe_audio_service.dart';
import 'log_service.dart';
import 'playback_state_service.dart';
import 'play_statistics_service.dart';

/// Audio handler that integrates with audio_service for:
/// - Background playback
/// - Lock screen controls
/// - Notification controls
/// - Headphone/Bluetooth media button controls (play/pause, next, prev)
class VibePlayAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  bool _audioEffectsInitialized = false;
  final ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(children: []);

  List<Song> _songs = [];
  int _currentIndex = 0;
  int _lastFadedIndex = -1;

  // Shuffle state for VibeEngine
  bool _shuffleEnabled = false;
  List<int> _shuffleOrder = [];  // Shuffled indices into _songs
  int _shufflePosition = 0;      // Current position in shuffle order

  // Local state streams (replacing just_audio streams)
  final BehaviorSubject<LoopMode> _loopModeSubject = BehaviorSubject<LoopMode>.seeded(LoopMode.off);
  final BehaviorSubject<bool> _shuffleModeSubject = BehaviorSubject<bool>.seeded(false);
  final BehaviorSubject<double> _speedSubject = BehaviorSubject<double>.seeded(1.0);
  final BehaviorSubject<double> _pitchSubject = BehaviorSubject<double>.seeded(1.0);

  // Crossfade settings
  bool _crossfadeEnabled = false;
  bool _smartCrossfadeEnabled = false;
  int _crossfadeDuration = 3; // seconds
  bool _isFadingOut = false;
  Timer? _fadeTimer;

  // Smart crossfade cached analysis
  SongAnalysis? _currentSongAnalysis;
  bool _analysisInitialized = false;

  // Volume normalization (ReplayGain)
  bool _replayGainInitialized = false;
  double _baseVolume = 1.0;
  double _normalizationMultiplier = 1.0;

  // Play statistics tracking
  bool _statisticsInitialized = false;
  Timer? _listenTimeTimer;
  DateTime? _lastPositionUpdate;

  // Stream subscriptions for cleanup
  final List<StreamSubscription> _subscriptions = [];

  // Initialization tracking - ensures restore completes before play
  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get _initFuture => _initCompleter.future;

  final BehaviorSubject<Song?> _currentSongSubject = BehaviorSubject<Song?>();
  Stream<Song?> get currentSongStream => _currentSongSubject.stream;
  Song? get currentSong => _currentSongSubject.value;

  // Queue and index streams for UI sync
  final BehaviorSubject<List<Song>> _queueSubject = BehaviorSubject<List<Song>>.seeded([]);
  final BehaviorSubject<int> _currentIndexSubject = BehaviorSubject<int>.seeded(0);
  Stream<List<Song>> get queueStream => _queueSubject.stream;
  Stream<int> get currentIndexStream => _currentIndexSubject.stream;
  List<Song> get currentQueue => _queueSubject.value;

  // VibeAudioEngine mode - uses our custom engine with direct PCM visualization
  // Set to true by default to test visualization - can be toggled
  bool _useVibeEngine = true;
  bool get useVibeEngine => _useVibeEngine;

  /// Toggle between just_audio and VibeAudioEngine
  /// VibeAudioEngine provides real-time visualization data
  Future<void> setUseVibeEngine(bool enabled) async {
    if (_useVibeEngine == enabled) return;

    _useVibeEngine = enabled;
    Log.audio.d('AudioHandler: Switched to ${enabled ? "VibeAudioEngine" : "just_audio"}');

    if (enabled) {
      // Initialize VibeAudioService
      await vibeAudioService.initialize();

      // If currently playing, switch playback to VibeEngine
      if (_player.playing && currentSong?.path != null) {
        final wasPlaying = _player.playing;
        final pos = _player.position;
        await _player.pause();

        final success = await vibeAudioService.prepare(currentSong!.path!);
        if (success) {
          _lastPreparedPath = currentSong!.path;

          // Update audio effects with VibeEngine's session ID
          final sessionId = vibeAudioService.audioSessionId;
          if (sessionId != null) {
            await _updateAudioEffectsSession(sessionId);
          }

          await vibeAudioService.seekTo(pos);
          if (wasPlaying) {
            await vibeAudioService.play();
          }
        }
      }
    } else {
      // Switch back to just_audio
      if (vibeAudioService.isPlaying && currentSong?.path != null) {
        final wasPlaying = vibeAudioService.isPlaying;
        final pos = vibeAudioService.position;
        await vibeAudioService.stop();

        // Update audio effects with just_audio's session ID
        final sessionId = _player.androidAudioSessionId;
        if (sessionId != null) {
          await _updateAudioEffectsSession(sessionId);
        }

        await _player.seek(pos);
        if (wasPlaying) {
          await _player.play();
        }
      }
    }
  }

  VibePlayAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    // Initialize playback state service first (for restoring state)
    await playbackStateService.init();

    // Restore playback state from previous session
    await _restorePlaybackState();

    // Initialize services
    if (!_analysisInitialized) {
      await audioAnalysisService.init();
      _analysisInitialized = true;
    }

    if (!_replayGainInitialized) {
      await replayGainService.init();
      _replayGainInitialized = true;
    }

    if (!_audioEffectsInitialized) {
      await audioEffectsService.init();
      _audioEffectsInitialized = true;
    }

    // Initialize play statistics service
    if (!_statisticsInitialized) {
      await playStatisticsService.init();
      _statisticsInitialized = true;
    }

    // Start listen time tracking timer
    _startListenTimeTracker();

    // Initialize VibeAudioService if enabled
    if (_useVibeEngine) {
      await vibeAudioService.initialize();
      Log.audio.d('AudioHandler: VibeAudioEngine initialized');

      // Listen to VibeAudioService state for playback state updates
      _subscriptions.add(
        vibeAudioService.stateStream.listen((state) {
          // Update audio_service playback state when VibeEngine state changes
          if (_useVibeEngine) {
            _updateVibePlaybackState();
          }
        }),
      );

      // Listen to VibeAudioService position for position updates
      _subscriptions.add(
        vibeAudioService.positionStream.listen((position) {
          if (_useVibeEngine && _crossfadeEnabled && vibeAudioService.duration.inSeconds > 0) {
            _handleCrossfade(position, vibeAudioService.duration);
          }
        }),
      );

      // Listen to VibeAudioService completion for auto-advance
      _subscriptions.add(
        vibeAudioService.completionStream.listen((_) {
          if (_useVibeEngine) {
            Log.audio.d('AudioHandler: Track completed, advancing to next');
            _onTrackCompleted();
          }
        }),
      );
    }

    // Broadcast playback state to audio_service
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // Listen to current index changes
    _subscriptions.add(
      _player.currentIndexStream.listen((index) async {
        if (index != null && index < _songs.length) {
          _currentIndex = index;
          final song = _songs[index];
          _currentSongSubject.add(song);

          // Update media item for notification/lock screen
          _updateMediaItem(song);

          // Track song started for statistics
          _trackSongStarted(song);

          // Save playback state (for restore on app restart)
          _savePlaybackState();

          // Switch VibeAudioEngine to new track (but not during setPlaylist to avoid double prepare)
          if (_useVibeEngine && song.path != null && !_settingPlaylist) {
            // Only prepare if this is a different track
            if (song.path != _lastPreparedPath) {
              final wasPlaying = vibeAudioService.isPlaying;
              Log.audio.d('AudioHandler: Track changed to ${song.title}, preparing VibeEngine');
              final success = await vibeAudioService.prepare(song.path!);
              if (success) {
                _lastPreparedPath = song.path;

                // Update audio effects with VibeEngine's session ID
                final sessionId = vibeAudioService.audioSessionId;
                if (sessionId != null) {
                  await _updateAudioEffectsSession(sessionId);
                }

                if (wasPlaying) {
                  await vibeAudioService.play();
                  _updateVibePlaybackState();
                }
              }
            }
          }

          if (_crossfadeEnabled && _isFadingOut) {
            _fadeIn();
          }

          if (_smartCrossfadeEnabled) {
            _currentSongAnalysis = await audioAnalysisService.getAnalysis(song);
          }

          await _applyNormalization(song);
        }
      }),
    );

    // Listen to position for crossfade
    _subscriptions.add(
      _player.positionStream.listen((position) {
        if (_crossfadeEnabled && _player.duration != null) {
          _handleCrossfade(position, _player.duration!);
        }
      }),
    );

    // Initialize equalizer, audio effects, and visualizer with just_audio's session
    // (will be updated with VibeEngine's session when using that engine)
    _subscriptions.add(
      _player.androidAudioSessionIdStream.listen((sessionId) async {
        if (sessionId != null && !_useVibeEngine) {
          // Only use just_audio's session if not using VibeEngine
          await _updateAudioEffectsSession(sessionId);
        }
      }),
    );

    // Mark initialization complete - play() waits for this
    if (!_initCompleter.isCompleted) {
      _initCompleter.complete();
      Log.audio.d('AudioHandler: Initialization complete');
    }
  }

  /// Update equalizer and audio effects with the given audio session ID
  Future<void> _updateAudioEffectsSession(int sessionId) async {
    Log.audio.d('AudioHandler: Updating audio effects with session ID: $sessionId');
    await equalizerService.setAudioSessionId(sessionId);
    await audioEffectsService.setAudioSessionId(sessionId);
    await visualizerService.setAudioSessionId(sessionId);
  }

  /// Transform just_audio events to audio_service PlaybackState
  PlaybackState _transformEvent(PlaybackEvent event) {
    // When VibeEngine is enabled, use its state instead
    if (_useVibeEngine) {
      return _buildVibePlaybackState();
    }

    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _speedSubject.value,
      queueIndex: _currentIndex,
    );
  }

  /// Build playback state from VibeAudioEngine
  PlaybackState _buildVibePlaybackState() {
    final vibeState = vibeAudioService.state;
    final processingState = switch (vibeState) {
      VibeAudioState.idle => AudioProcessingState.idle,
      VibeAudioState.preparing => AudioProcessingState.loading,
      VibeAudioState.ready => AudioProcessingState.ready,
      VibeAudioState.playing => AudioProcessingState.ready,
      VibeAudioState.paused => AudioProcessingState.ready,
      VibeAudioState.stopped => AudioProcessingState.idle,
      VibeAudioState.error => AudioProcessingState.error,
    };

    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (vibeAudioService.isPlaying) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: processingState,
      playing: vibeAudioService.isPlaying,
      updatePosition: vibeAudioService.position,
      bufferedPosition: vibeAudioService.position, // VibeEngine doesn't have buffering
      speed: _speedSubject.value,
      queueIndex: _currentIndex,
    );
  }

  /// Update playback state for audio_service when using VibeEngine
  void _updateVibePlaybackState() {
    playbackState.add(_buildVibePlaybackState());
  }

  /// Update the media item shown in notifications and lock screen
  void _updateMediaItem(Song song) {
    // Build content URI for album artwork if albumId is available
    Uri? artUri;
    if (song.albumId != null) {
      artUri = Uri.parse('content://media/external/audio/albumart/${song.albumId}');
    }

    final item = MediaItem(
      id: song.id.toString(),
      title: song.title,
      artist: song.artistDisplay,
      album: song.album ?? 'Unknown Album',
      duration: Duration(milliseconds: song.duration),
      artUri: artUri,
    );
    mediaItem.add(item);
  }

  // ============ audio_service required overrides ============

  @override
  Future<void> play() async {
    if (_operationInProgress) {
      Log.audio.d('AudioHandler: play() skipped - operation in progress');
      return;
    }
    _operationInProgress = true;

    try {
      // Wait for initialization to complete (ensures state is restored)
      await _initFuture;

      // Ensure only one engine is active
      await _ensureSingleEngineActive();

      if (_useVibeEngine) {
        // Check if we need to prepare the track first (e.g., after app restart)
        var song = currentSong;

        // Fallback: if currentSong is null but we have saved state, try to restore
        if (song == null && playbackStateService.hasSavedState) {
          Log.audio.d('AudioHandler: currentSong is null, attempting fallback restore');
          final savedSong = playbackStateService.savedCurrentSong;
          if (savedSong != null) {
            _currentSongSubject.add(savedSong);
            _updateMediaItem(savedSong);
            song = savedSong;

            // Also restore queue if available
            final savedQueue = playbackStateService.savedQueue;
            if (savedQueue.isNotEmpty) {
              _songs = savedQueue;
              _currentIndex = playbackStateService.savedCurrentIndex.clamp(0, savedQueue.length - 1);
              _queueSubject.add(savedQueue);
              _currentIndexSubject.add(_currentIndex);
            } else {
              _songs = [savedSong];
              _currentIndex = 0;
            }

            // Set pending position restore
            final savedPosition = playbackStateService.savedPosition;
            if (savedPosition > Duration.zero) {
              _pendingPositionRestore = true;
              _savedPositionToRestore = savedPosition;
            }

            Log.audio.d('AudioHandler: Fallback restore successful - ${savedSong.title}');
          }
        }

        if (song == null) {
          Log.audio.d('AudioHandler: No song to play - currentSong is null');
          return;
        }

        if (!vibeAudioService.isReady && song.path != null) {
          Log.audio.d('AudioHandler: Track not prepared, preparing ${song.title}');
          final success = await vibeAudioService.prepare(song.path!);
          if (!success) {
            Log.audio.d('AudioHandler: Failed to prepare track');
            return;
          }
          _lastPreparedPath = song.path;

          // Update audio effects with VibeEngine's session ID
          final sessionId = vibeAudioService.audioSessionId;
          if (sessionId != null) {
            await _updateAudioEffectsSession(sessionId);
          }
        }

        // Restore position if pending (after app restart)
        if (_pendingPositionRestore && _savedPositionToRestore > Duration.zero) {
          Log.audio.d('AudioHandler: Restoring position to ${_savedPositionToRestore.inSeconds}s');
          await vibeAudioService.seekTo(_savedPositionToRestore);
          _pendingPositionRestore = false;
          _savedPositionToRestore = Duration.zero;
        }

        await vibeAudioService.play();
        _updateVibePlaybackState();
        Log.audio.d('AudioHandler: VibeEngine play() called');

        // Save state after play starts (in case user kills app while playing)
        _savePlaybackState();

        // Prepare next track for gapless playback (delayed slightly)
        Future.delayed(const Duration(milliseconds: 500), () {
          _prepareNextTrackForGapless();
        });
      } else {
        // Check if just_audio needs to be set up
        if (_player.audioSource == null && _songs.isNotEmpty) {
          Log.audio.d('AudioHandler: just_audio not ready, setting playlist');
          await setPlaylist(_songs, initialIndex: _currentIndex);
        }
        await _player.play();
      }
    } finally {
      _operationInProgress = false;
    }
  }

  @override
  Future<void> pause() async {
    // Pause both engines to ensure nothing plays
    if (_useVibeEngine) {
      await vibeAudioService.pause();
      _updateVibePlaybackState();
    }
    // Always pause just_audio to be safe
    if (_player.playing) {
      await _player.pause();
    }

    // Save playback state for restore on app restart
    _savePlaybackState();
  }

  /// Save current playback state for restoration after app restart
  void _savePlaybackState() {
    if (currentSong != null && _songs.isNotEmpty) {
      playbackStateService.saveState(
        currentSong: currentSong,
        queue: _songs,
        currentIndex: _currentIndex,
        position: position,
      );
    }
  }

  /// Restore playback state from previous session
  Future<void> _restorePlaybackState() async {
    Log.audio.d('AudioHandler: Checking for saved playback state...');
    Log.audio.d('AudioHandler: hasSavedState=${playbackStateService.hasSavedState}');
    Log.audio.d('AudioHandler: savedCurrentSongPath=${playbackStateService.savedCurrentSongPath}');

    if (!playbackStateService.hasSavedState) {
      Log.audio.d('AudioHandler: No saved playback state to restore');
      return;
    }

    try {
      final savedSong = playbackStateService.savedCurrentSong;
      final savedQueue = playbackStateService.savedQueue;
      final savedIndex = playbackStateService.savedCurrentIndex;

      Log.audio.d('AudioHandler: savedSong=${savedSong?.title}, savedQueue.length=${savedQueue.length}, savedIndex=$savedIndex');

      if (savedSong != null) {
        Log.audio.d('AudioHandler: Restoring playback state - ${savedSong.title}');

        // Restore queue and current song
        if (savedQueue.isNotEmpty) {
          _songs = savedQueue;
          _currentIndex = savedIndex.clamp(0, savedQueue.length - 1);
          _queueSubject.add(savedQueue);
          _currentIndexSubject.add(_currentIndex);
        } else {
          // No queue saved, just set current song
          _songs = [savedSong];
          _currentIndex = 0;
          _queueSubject.add(_songs);
          _currentIndexSubject.add(0);
        }

        // Update current song subject (this makes mini player work!)
        _currentSongSubject.add(savedSong);
        _updateMediaItem(savedSong);

        // Mark that we need to restore position on next play
        final savedPosition = playbackStateService.savedPosition;
        if (savedPosition > Duration.zero) {
          _pendingPositionRestore = true;
          _savedPositionToRestore = savedPosition;
          Log.audio.d('AudioHandler: Will restore position to ${savedPosition.inSeconds}s on play');
        }

        Log.audio.d('AudioHandler: Restored queue with ${_songs.length} songs at index $_currentIndex');
      }
    } catch (e) {
      Log.audio.e('AudioHandler: Failed to restore playback state', e);
    }
  }

  @override
  Future<void> stop() async {
    // Save state before stopping (user might want to resume later)
    _savePlaybackState();

    // Stop both engines to ensure complete stop
    await vibeAudioService.stop();
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    if (_useVibeEngine) {
      await vibeAudioService.seekTo(position);
      _updateVibePlaybackState();
    } else {
      await _player.seek(position);
    }
  }

  /// Called when a track completes naturally (VibeAudioEngine)
  Future<void> _onTrackCompleted() async {
    // Track completed song for statistics
    final completedSong = currentSong;
    if (completedSong != null) {
      _trackSongCompleted(completedSong, completedSong.duration);
    }

    _resetCrossfadeState();

    final loopMode = _loopMode;

    if (loopMode == LoopMode.one) {
      // Repeat One: replay the same track
      if (_useVibeEngine && currentSong?.path != null) {
        await vibeAudioService.seekTo(Duration.zero);
        await vibeAudioService.play();
        _updateVibePlaybackState();
      }
      return;
    }

    // Get next track index (respects shuffle mode)
    final nextIndex = _getNextShuffleIndex();

    if (nextIndex != null) {
      _currentIndex = nextIndex;
      _currentIndexSubject.add(_currentIndex);  // Update UI
      final nextSong = _songs[_currentIndex];
      _currentSongSubject.add(nextSong);
      _updateMediaItem(nextSong);

      if (_useVibeEngine && nextSong.path != null) {
        // Try gapless transition first
        bool gaplessSuccess = false;
        if (_gaplessEnabled && _preparedNextPath == nextSong.path) {
          Log.audio.d('AudioHandler: Attempting gapless transition');
          gaplessSuccess = await vibeAudioService.transitionToNextTrack();
          if (gaplessSuccess) {
            _lastPreparedPath = nextSong.path;
            _preparedNextPath = null;
            Log.audio.d('AudioHandler: Gapless transition succeeded');
          }
        }

        // Fall back to regular prepare if gapless failed or wasn't available
        if (!gaplessSuccess) {
          final success = await vibeAudioService.prepare(nextSong.path!);
          if (success) {
            _lastPreparedPath = nextSong.path;
            await vibeAudioService.play();
          }
        }

        // Update audio effects with VibeEngine's session ID
        final sessionId = vibeAudioService.audioSessionId;
        if (sessionId != null) {
          await _updateAudioEffectsSession(sessionId);
        }

        _updateVibePlaybackState();
        await _applyNormalization(nextSong);

        // Prepare next track for gapless playback
        _prepareNextTrackForGapless();
      }

      // Keep just_audio in sync for queue management
      await _player.seek(Duration.zero, index: _currentIndex);
    } else {
      // End of playlist with no repeat: stop playback
      Log.audio.d('AudioHandler: End of playlist, stopping');
      _preparedNextPath = null;
      _updateVibePlaybackState();
    }
  }

  /// Enable or disable gapless playback
  Future<void> setGaplessPlaybackEnabled(bool enabled) async {
    _gaplessEnabled = enabled;
    await vibeAudioService.setGaplessEnabled(enabled);
    if (!enabled) {
      _preparedNextPath = null;
      await vibeAudioService.clearNextTrack();
    }
    Log.audio.d('AudioHandler: Gapless playback ${enabled ? 'enabled' : 'disabled'}');
  }

  bool get gaplessEnabled => _gaplessEnabled;

  /// Prepare the next track for gapless playback (called after starting a new track)
  Future<void> _prepareNextTrackForGapless() async {
    if (!_gaplessEnabled || !_useVibeEngine) return;

    // Don't prepare if repeat one is enabled
    if (_loopMode == LoopMode.one) return;

    // Get the next track that would play
    final nextIndex = _peekNextShuffleIndex();
    if (nextIndex == null || nextIndex >= _songs.length) {
      Log.audio.d('AudioHandler: No next track to prepare for gapless');
      return;
    }

    final nextSong = _songs[nextIndex];
    if (nextSong.path == null) return;

    // Don't re-prepare if already prepared
    if (_preparedNextPath == nextSong.path) return;

    Log.audio.d('AudioHandler: Preparing next track for gapless: ${nextSong.title}');
    final success = await vibeAudioService.prepareNextTrack(nextSong.path!);
    if (success) {
      _preparedNextPath = nextSong.path;
      Log.audio.d('AudioHandler: Next track prepared for gapless');
    } else {
      _preparedNextPath = null;
    }
  }

  /// Peek at what the next shuffle index would be without changing state
  int? _peekNextShuffleIndex() {
    if (!_shuffleEnabled || _shuffleOrder.isEmpty) {
      // Sequential: next index or wrap
      if (_currentIndex < _songs.length - 1) {
        return _currentIndex + 1;
      } else if (_loopMode == LoopMode.all) {
        return 0;
      }
      return null;
    }

    // Shuffle mode
    if (_shufflePosition < _shuffleOrder.length - 1) {
      return _shuffleOrder[_shufflePosition + 1];
    } else if (_loopMode == LoopMode.all && _shuffleOrder.isNotEmpty) {
      return _shuffleOrder[0]; // Would restart shuffle
    }
    return null;
  }

  @override
  Future<void> skipToNext() async {
    if (_operationInProgress) {
      Log.audio.d('AudioHandler: skipToNext() skipped - operation in progress');
      return;
    }
    _operationInProgress = true;

    // Track skip for statistics
    final skippedSong = currentSong;
    final listenedMs = (_useVibeEngine ? vibeAudioService.position : _player.position).inMilliseconds;
    if (skippedSong != null) {
      _trackSongSkipped(skippedSong, listenedMs);
    }

    try {
      _resetCrossfadeState();
      // Clear gapless preparation since we're manually skipping
      _preparedNextPath = null;
      await vibeAudioService.clearNextTrack();

      if (_useVibeEngine) {
        // Handle skip with VibeEngine - respects shuffle
        final nextIndex = _getNextShuffleIndex();
        if (nextIndex != null) {
          _currentIndex = nextIndex;
          await _skipToIndex(_currentIndex);
          // Prepare next track after skip
          _prepareNextTrackForGapless();
        }
      } else {
        // Use just_audio (handles its own shuffle)
        if (_currentIndex < _songs.length - 1) {
          await _player.seekToNext();
        } else if (_loopMode == LoopMode.all) {
          await _player.seek(Duration.zero, index: 0);
        }
      }
    } finally {
      _operationInProgress = false;
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_operationInProgress) {
      Log.audio.d('AudioHandler: skipToPrevious() skipped - operation in progress');
      return;
    }
    _operationInProgress = true;

    try {
      _resetCrossfadeState();

      // If more than 3 seconds in, restart current track
      final currentPosition = _useVibeEngine ? vibeAudioService.position : _player.position;
      if (currentPosition.inSeconds > 3) {
        if (_useVibeEngine) {
          await vibeAudioService.seekTo(Duration.zero);
        } else {
          await _player.seek(Duration.zero);
        }
        // Early return handled by finally block
      } else {
        // Track skip for statistics (only when actually going to previous track)
        final skippedSong = currentSong;
        final listenedMs = currentPosition.inMilliseconds;
        if (skippedSong != null) {
          _trackSongSkipped(skippedSong, listenedMs);
        }

        // Clear gapless preparation since we're manually skipping
        _preparedNextPath = null;
        await vibeAudioService.clearNextTrack();

        // Go to previous track
        if (_useVibeEngine) {
          // Handle previous with VibeEngine - respects shuffle history
          final prevIndex = _getPreviousShuffleIndex();
          if (prevIndex != null) {
            _currentIndex = prevIndex;
            await _skipToIndex(_currentIndex);
            // Prepare next track after skip
            _prepareNextTrackForGapless();
          }
        } else {
          // Use just_audio (handles its own shuffle)
          if (_currentIndex > 0) {
            await _player.seekToPrevious();
          }
        }
      }
    } finally {
      _operationInProgress = false;
    }
  }

  /// Helper to skip to a specific index with VibeEngine
  Future<void> _skipToIndex(int index) async {
    if (index < 0 || index >= _songs.length) return;

    final song = _songs[index];
    _currentIndexSubject.add(index);
    _currentSongSubject.add(song);
    _updateMediaItem(song);

    if (_useVibeEngine && song.path != null) {
      final wasPlaying = vibeAudioService.isPlaying;
      final success = await vibeAudioService.prepare(song.path!);
      if (success) {
        _lastPreparedPath = song.path;

        // Update audio effects with VibeEngine's session ID
        final sessionId = vibeAudioService.audioSessionId;
        if (sessionId != null) {
          await _updateAudioEffectsSession(sessionId);
        }

        if (wasPlaying) {
          await vibeAudioService.play();
        }
        _updateVibePlaybackState();
        await _applyNormalization(song);
      }
    }

    // Keep just_audio in sync
    await _player.seek(Duration.zero, index: index);
  }

  @override
  Future<void> setSpeed(double speed) => setPlaybackSpeed(speed);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await setLoopMode(LoopMode.off);
      case AudioServiceRepeatMode.one:
        await setLoopMode(LoopMode.one);
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await setLoopMode(LoopMode.all);
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    await setShuffleModeEnabled(shuffleMode != AudioServiceShuffleMode.none);
  }

  // ============ Crossfade functionality ============

  void setCrossfadeEnabled(bool enabled) {
    _crossfadeEnabled = enabled;
    // Also enable native crossfade in VibeEngine
    if (_useVibeEngine) {
      vibeAudioService.setCrossfadeEnabled(enabled);
    }
    if (!enabled) {
      _cancelFade();
      _isFadingOut = false;
      _updateEffectiveVolume();
      _currentSongAnalysis = null;
    }
  }

  void setSmartCrossfadeEnabled(bool enabled) {
    _smartCrossfadeEnabled = enabled;
    if (!enabled) {
      _currentSongAnalysis = null;
    }
  }

  void setCrossfadeDuration(int seconds) {
    _crossfadeDuration = seconds.clamp(1, 12);
    // Also set native crossfade duration
    if (_useVibeEngine) {
      vibeAudioService.setCrossfadeDuration(seconds * 1000);
    }
  }

  Future<void> _applyNormalization(Song song) async {
    if (replayGainService.mode == NormalizationMode.off) {
      _normalizationMultiplier = 1.0;
    } else {
      final gainDb = await replayGainService.getGainForSong(song);
      _normalizationMultiplier = replayGainService.gainToMultiplier(gainDb);
      _normalizationMultiplier = _normalizationMultiplier.clamp(0.1, 2.0);
    }
    _updateEffectiveVolume();
  }

  void _updateEffectiveVolume() {
    if (!_isFadingOut) {
      final effectiveVolume = (_baseVolume * _normalizationMultiplier).clamp(0.0, 1.0);
      if (_useVibeEngine) {
        vibeAudioService.setVolume(effectiveVolume);
      } else {
        _player.setVolume(effectiveVolume);
      }
    }
  }

  void _handleCrossfade(Duration position, Duration duration) {
    if (!_crossfadeEnabled || _isFadingOut || duration.inSeconds < _crossfadeDuration * 2) {
      return;
    }

    if (_smartCrossfadeEnabled && _currentSongAnalysis != null) {
      if (_currentSongAnalysis!.isGaplessTrack) {
        return;
      }
    }

    int crossfadeMs = _crossfadeDuration * 1000;

    if (_smartCrossfadeEnabled && _currentSongAnalysis != null) {
      if (_currentSongAnalysis!.silenceStart != null) {
        final silenceMs = duration.inMilliseconds - _currentSongAnalysis!.silenceStart!.inMilliseconds;
        if (silenceMs > 0 && silenceMs < 15000) {
          crossfadeMs = silenceMs;
        }
      }

      if (_currentSongAnalysis!.bpm != null) {
        final optimalMs = audioAnalysisService.getOptimalCrossfadeDuration(
          _currentSongAnalysis!.bpm,
          crossfadeMs,
        );
        if (optimalMs != null) {
          crossfadeMs = optimalMs;
        }
      }
    }

    final remainingMs = duration.inMilliseconds - position.inMilliseconds;

    if (remainingMs <= crossfadeMs && remainingMs > 0 && _currentIndex != _lastFadedIndex) {
      _lastFadedIndex = _currentIndex;

      // Use native crossfade when VibeEngine is enabled and next track is prepared
      if (_useVibeEngine && _preparedNextPath != null) {
        Log.audio.d('AudioHandler: Starting native crossfade');
        vibeAudioService.startCrossfade();
      } else {
        _fadeOut(durationMs: crossfadeMs);
      }
    }
  }

  void _fadeOut({int? durationMs}) {
    if (_isFadingOut) return;
    _isFadingOut = true;
    _cancelFade();

    final fadeDurationMs = durationMs ?? (_crossfadeDuration * 1000);
    const steps = 20;
    final stepDuration = Duration(milliseconds: fadeDurationMs ~/ steps);
    final targetVolume = _baseVolume * _normalizationMultiplier;
    double volume = targetVolume;
    final volumeStep = targetVolume / steps;

    _fadeTimer = Timer.periodic(stepDuration, (timer) {
      volume -= volumeStep;
      if (volume <= 0) {
        volume = 0;
        timer.cancel();
      }
      final clampedVolume = volume.clamp(0.0, 1.0);
      if (_useVibeEngine) {
        vibeAudioService.setVolume(clampedVolume);
      } else {
        _player.setVolume(clampedVolume);
      }
    });
  }

  void _fadeIn() {
    _cancelFade();
    _isFadingOut = false;

    const steps = 20;
    final stepDuration = Duration(milliseconds: (_crossfadeDuration * 1000) ~/ steps);
    final targetVolume = _baseVolume * _normalizationMultiplier;
    double volume = 0.0;
    final volumeStep = targetVolume / steps;

    if (_useVibeEngine) {
      vibeAudioService.setVolume(0);
    } else {
      _player.setVolume(0);
    }

    _fadeTimer = Timer.periodic(stepDuration, (timer) {
      volume += volumeStep;
      if (volume >= targetVolume) {
        volume = targetVolume;
        timer.cancel();
      }
      final clampedVolume = volume.clamp(0.0, 1.0);
      if (_useVibeEngine) {
        vibeAudioService.setVolume(clampedVolume);
      } else {
        _player.setVolume(clampedVolume);
      }
    });
  }

  void _cancelFade() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
  }

  void _resetCrossfadeState() {
    _cancelFade();
    _isFadingOut = false;
    _lastFadedIndex = -1;
    _updateEffectiveVolume();
  }

  // ============ Playlist and Queue management ============

  int? get audioSessionId => _player.androidAudioSessionId;

  // Track if we're currently setting playlist to prevent race conditions
  bool _settingPlaylist = false;
  String? _lastPreparedPath;

  // Prevent concurrent playback operations
  bool _operationInProgress = false;

  // Gapless playback state
  bool _gaplessEnabled = true;
  String? _preparedNextPath;

  // State restoration tracking
  bool _pendingPositionRestore = false;
  Duration _savedPositionToRestore = Duration.zero;

  /// Ensure the inactive audio engine is stopped to prevent dual playback
  Future<void> _ensureSingleEngineActive() async {
    if (_useVibeEngine) {
      // Stop just_audio if it's playing
      if (_player.playing) {
        Log.audio.d('AudioHandler: Stopping just_audio to prevent dual playback');
        await _player.pause();
      }
    } else {
      // Stop VibeEngine if it's playing
      if (vibeAudioService.isPlaying) {
        Log.audio.d('AudioHandler: Stopping VibeEngine to prevent dual playback');
        await vibeAudioService.pause();
      }
    }
  }

  Future<void> setPlaylist(List<Song> songs, {int initialIndex = 0}) async {
    final validSongs = songs.where((song) => song.path != null && song.path!.isNotEmpty).toList();

    if (validSongs.isEmpty) {
      Log.audio.d('AudioHandler: No valid songs to play');
      return;
    }

    var adjustedIndex = initialIndex;
    if (adjustedIndex >= validSongs.length) {
      adjustedIndex = 0;
    }

    _songs = validSongs;
    _currentIndex = adjustedIndex;
    _settingPlaylist = true;

    try {
      // Also set up just_audio for fallback and notification integration
      await _playlist.clear();
      await _playlist.addAll(
        validSongs.map((song) => AudioSource.file(song.path!)).toList(),
      );

      // Note: Don't set auto-play on just_audio when using VibeEngine
      await _player.setAudioSource(_playlist, initialIndex: adjustedIndex);

      // Update queue for audio_service
      queue.add(validSongs.map((song) => MediaItem(
        id: song.id.toString(),
        title: song.title,
        artist: song.artistDisplay,
        album: song.album ?? 'Unknown Album',
        duration: Duration(milliseconds: song.duration),
      )).toList());

      // Update queue and index streams for UI sync
      _queueSubject.add(validSongs);
      _currentIndexSubject.add(adjustedIndex);

      // Regenerate shuffle order if shuffle is enabled
      if (_shuffleEnabled) {
        _generateShuffleOrder();
      }

      if (validSongs.isNotEmpty && adjustedIndex < validSongs.length) {
        final currentSong = validSongs[adjustedIndex];
        _currentSongSubject.add(currentSong);
        _updateMediaItem(currentSong);

        // Prepare VibeAudioEngine if enabled (and not already prepared for this path)
        if (_useVibeEngine && currentSong.path != null && currentSong.path != _lastPreparedPath) {
          Log.audio.d('AudioHandler: Preparing VibeAudioEngine for ${currentSong.title}');
          final success = await vibeAudioService.prepare(currentSong.path!);
          if (success) {
            _lastPreparedPath = currentSong.path;
            Log.audio.d('AudioHandler: VibeAudioEngine prepared successfully');

            // Update audio effects with VibeEngine's session ID
            final sessionId = vibeAudioService.audioSessionId;
            if (sessionId != null) {
              await _updateAudioEffectsSession(sessionId);
            }
          } else {
            Log.audio.d('AudioHandler: VibeAudioEngine prepare FAILED');
          }
        }
      }
    } catch (e) {
      Log.audio.d('AudioHandler: Error setting playlist: $e');
      _songs = [];
      _currentIndex = 0;
    } finally {
      _settingPlaylist = false;
    }
  }

  Future<void> playSong(Song song, List<Song> queue) async {
    final index = queue.indexWhere((s) => s.id == song.id);
    if (index != -1) {
      await setPlaylist(queue, initialIndex: index);
      await play();
    }
  }

  Future<void> setShuffleModeEnabled(bool enabled) async {
    _shuffleEnabled = enabled;
    _shuffleModeSubject.add(enabled);
    // Keep just_audio in sync for fallback
    if (!_useVibeEngine) {
      await _player.setShuffleModeEnabled(enabled);
    }

    if (enabled && _songs.isNotEmpty) {
      _generateShuffleOrder();
    } else {
      _shuffleOrder = [];
      _shufflePosition = 0;
    }
    Log.audio.d('AudioHandler: Shuffle mode ${enabled ? "enabled" : "disabled"}');
  }

  /// Generate a shuffled order starting from current song
  void _generateShuffleOrder() {
    if (_songs.isEmpty) {
      _shuffleOrder = [];
      _shufflePosition = 0;
      return;
    }

    // Create list of all indices except current
    final indices = List<int>.generate(_songs.length, (i) => i);
    indices.remove(_currentIndex);
    indices.shuffle();

    // Start with current song, then shuffled rest
    _shuffleOrder = [_currentIndex, ...indices];
    _shufflePosition = 0;

    Log.audio.d('AudioHandler: Generated shuffle order with ${_shuffleOrder.length} songs');
  }

  /// Get next song index respecting shuffle mode
  int? _getNextShuffleIndex() {
    if (!_shuffleEnabled || _shuffleOrder.isEmpty) {
      // Sequential: next index or wrap
      if (_currentIndex < _songs.length - 1) {
        return _currentIndex + 1;
      } else if (_loopMode == LoopMode.all) {
        return 0;
      }
      return null; // End of playlist
    }

    // Shuffle mode
    if (_shufflePosition < _shuffleOrder.length - 1) {
      _shufflePosition++;
      return _shuffleOrder[_shufflePosition];
    } else if (_loopMode == LoopMode.all) {
      // Regenerate shuffle for next cycle
      _generateShuffleOrder();
      return _shuffleOrder.isNotEmpty ? _shuffleOrder[0] : null;
    }
    return null; // End of shuffle
  }

  /// Get previous song index respecting shuffle mode
  int? _getPreviousShuffleIndex() {
    if (!_shuffleEnabled || _shuffleOrder.isEmpty) {
      // Sequential: previous index
      if (_currentIndex > 0) {
        return _currentIndex - 1;
      }
      return null;
    }

    // Shuffle mode: go back in shuffle history
    if (_shufflePosition > 0) {
      _shufflePosition--;
      return _shuffleOrder[_shufflePosition];
    }
    return null;
  }

  Future<void> playNext(Song song) async {
    if (song.path == null) return;

    final insertIndex = _currentIndex + 1;
    _songs.insert(insertIndex, song);

    try {
      await _playlist.insert(insertIndex, AudioSource.file(song.path!));
    } catch (e) {
      Log.audio.d('AudioHandler: Error adding to play next: $e');
    }
  }

  Future<void> addToQueue(Song song) async {
    if (song.path == null) return;

    _songs.add(song);

    try {
      await _playlist.add(AudioSource.file(song.path!));
    } catch (e) {
      Log.audio.d('AudioHandler: Error adding to queue: $e');
    }
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _songs.length) return;
    if (index == _currentIndex) return;

    _songs.removeAt(index);

    try {
      await _playlist.removeAt(index);
      if (index < _currentIndex) {
        _currentIndex--;
      }
    } catch (e) {
      Log.audio.d('AudioHandler: Error removing from queue: $e');
    }
  }

  // Loop mode - stored locally
  LoopMode _loopMode = LoopMode.off;

  Future<void> setLoopMode(LoopMode mode) async {
    _loopMode = mode;
    _loopModeSubject.add(mode);
    // Keep just_audio in sync for fallback
    if (!_useVibeEngine) {
      await _player.setLoopMode(mode);
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _speedSubject.add(speed);
    if (_useVibeEngine) {
      await vibeAudioService.setSpeed(speed);
    } else {
      await _player.setSpeed(speed);
    }
  }

  Future<void> setPitch(double semitones) async {
    final pitch = 1.0 + (semitones / 12.0);
    _pitchSubject.add(pitch);
    if (!_useVibeEngine) {
      await _player.setPitch(pitch.clamp(0.5, 2.0));
    }
    // Note: Native pitch control would require SoundTouch or similar DSP library
  }

  double get currentPitchSemitones {
    final pitch = _pitchSubject.value;
    return (pitch - 1.0) * 12.0;
  }

  Future<void> setVolume(double volume) async {
    _baseVolume = volume.clamp(0.0, 1.0);
    _updateEffectiveVolume();
    // Also set native volume when VibeEngine is active
    if (_useVibeEngine) {
      await vibeAudioService.setVolume(_baseVolume * _normalizationMultiplier);
    }
  }

  // Streams for UI
  // These streams automatically switch based on whether VibeEngine is enabled
  Stream<Duration> get positionStream => _useVibeEngine
      ? vibeAudioService.positionStream
      : _player.positionStream;
  Stream<Duration?> get durationStream => _useVibeEngine
      ? vibeAudioService.durationStream.map((d) => d)
      : _player.durationStream;
  Stream<bool> get playingStream => _useVibeEngine
      ? vibeAudioService.stateStream.map((s) => s == VibeAudioState.playing)
      : _player.playingStream;
  Stream<LoopMode> get loopModeStream => _loopModeSubject.stream;
  Stream<bool> get shuffleModeStream => _shuffleModeSubject.stream;
  Stream<double> get speedStream => _speedSubject.stream;
  Stream<double> get pitchStream => _pitchSubject.stream;

  Duration get position => _useVibeEngine
      ? vibeAudioService.position
      : _player.position;
  Duration get duration => _useVibeEngine
      ? vibeAudioService.duration
      : (_player.duration ?? Duration.zero);
  bool get playing => _useVibeEngine
      ? vibeAudioService.isPlaying
      : _player.playing;
  LoopMode get loopMode => _loopMode;
  bool get shuffleMode => _shuffleEnabled;
  List<Song> get songQueue => _songs;
  int get currentIndex => _currentIndex;

  bool get crossfadeEnabled => _crossfadeEnabled;
  bool get smartCrossfadeEnabled => _smartCrossfadeEnabled;
  int get crossfadeDuration => _crossfadeDuration;

  Future<void> dispose() async {
    _cancelFade();
    _listenTimeTimer?.cancel();
    playStatisticsService.onPlaybackStopped();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _player.dispose();
    await _currentSongSubject.close();
    await _queueSubject.close();
    await _currentIndexSubject.close();
    await _loopModeSubject.close();
    await _shuffleModeSubject.close();
    await _speedSubject.close();
    await _pitchSubject.close();
  }

  // ============ Play Statistics Tracking ============

  /// Start timer to track listen time every 10 seconds
  void _startListenTimeTracker() {
    _listenTimeTimer?.cancel();
    _listenTimeTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (playing && currentSong != null) {
        playStatisticsService.updateListenTime(10000); // 10 seconds in ms
      }
    });
  }

  /// Track when a song starts playing
  void _trackSongStarted(Song song) {
    playStatisticsService.onSongStarted(song);
  }

  /// Track when a song completes
  void _trackSongCompleted(Song song, int listenedMs) {
    playStatisticsService.onSongCompleted(song);
    playStatisticsService.addHistoryEntry(song, listenedMs, true);
  }

  /// Track when a song is skipped
  void _trackSongSkipped(Song song, int listenedMs) {
    playStatisticsService.onSongSkipped(song);
    final completed = song.duration > 0 && listenedMs > (song.duration * 0.8);
    playStatisticsService.addHistoryEntry(song, listenedMs, completed);
  }
}

// Global audio handler instance
VibePlayAudioHandler? _audioHandler;

VibePlayAudioHandler get audioHandler {
  if (_audioHandler == null) {
    throw StateError('AudioHandler not initialized. Call initAudioService() first.');
  }
  return _audioHandler!;
}

/// Initialize audio service for background playback and media controls
Future<void> initAudioService() async {
  _audioHandler = await AudioService.init(
    builder: () => VibePlayAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.vibeplay.vibeplay.audio',
      androidNotificationChannelName: 'VibePlay Audio',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidShowNotificationBadge: true,
      notificationColor: Color(0xFF6366F1),
      androidNotificationIcon: 'drawable/ic_notification',
    ),
  );
}
