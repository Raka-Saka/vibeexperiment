import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;
import 'package:rxdart/rxdart.dart';
import 'log_service.dart';
import '../shared/models/song.dart';

/// Audio playback state
enum VibeAudioState {
  idle,
  preparing,
  ready,
  playing,
  paused,
  stopped,
  error,
}

/// Real-time audio pulse data for visualization
class AudioPulseData {
  // 7-band frequency analysis (0.0 - 1.0)
  final double subBass;    // 20-60 Hz - rumble, feel
  final double bass;       // 60-250 Hz - kick drums, bass guitar
  final double lowMid;     // 250-500 Hz - warmth
  final double mid;        // 500-2000 Hz - vocals, instruments
  final double highMid;    // 2000-4000 Hz - presence
  final double treble;     // 4000-6000 Hz - clarity
  final double brilliance; // 6000-20000 Hz - air, sparkle

  // Simplified 3-band (for easy use)
  final double bassTotal;
  final double midTotal;
  final double trebleTotal;

  // Energy and dynamics
  final double energy;     // Overall energy (0.0 - 1.0)
  final double peak;       // Peak level with decay

  // Beat detection
  final double beat;       // Beat intensity (1.0 on beat, decays)
  final bool onBeat;       // True on beat hit
  final double bpm;        // Estimated BPM

  // Spectral analysis
  final double flux;       // Rate of spectral change
  final double centroid;   // Spectral brightness

  // Detailed data
  final List<double> spectrum;  // 32-band spectrum
  final List<double> waveform;  // Waveform samples

  final DateTime timestamp;

  AudioPulseData({
    this.subBass = 0,
    this.bass = 0,
    this.lowMid = 0,
    this.mid = 0,
    this.highMid = 0,
    this.treble = 0,
    this.brilliance = 0,
    this.bassTotal = 0,
    this.midTotal = 0,
    this.trebleTotal = 0,
    this.energy = 0,
    this.peak = 0,
    this.beat = 0,
    this.onBeat = false,
    this.bpm = 0,
    this.flux = 0,
    this.centroid = 0,
    this.spectrum = const [],
    this.waveform = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory AudioPulseData.fromMap(Map<dynamic, dynamic> map) {
    return AudioPulseData(
      subBass: (map['subBass'] as num?)?.toDouble() ?? 0,
      bass: (map['bass'] as num?)?.toDouble() ?? 0,
      lowMid: (map['lowMid'] as num?)?.toDouble() ?? 0,
      mid: (map['mid'] as num?)?.toDouble() ?? 0,
      highMid: (map['highMid'] as num?)?.toDouble() ?? 0,
      treble: (map['treble'] as num?)?.toDouble() ?? 0,
      brilliance: (map['brilliance'] as num?)?.toDouble() ?? 0,
      bassTotal: (map['bassTotal'] as num?)?.toDouble() ?? 0,
      midTotal: (map['midTotal'] as num?)?.toDouble() ?? 0,
      trebleTotal: (map['trebleTotal'] as num?)?.toDouble() ?? 0,
      energy: (map['energy'] as num?)?.toDouble() ?? 0,
      peak: (map['peak'] as num?)?.toDouble() ?? 0,
      beat: (map['beat'] as num?)?.toDouble() ?? 0,
      onBeat: map['onBeat'] as bool? ?? false,
      bpm: (map['bpm'] as num?)?.toDouble() ?? 0,
      flux: (map['flux'] as num?)?.toDouble() ?? 0,
      centroid: (map['centroid'] as num?)?.toDouble() ?? 0,
      spectrum: (map['spectrum'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList() ?? [],
      waveform: (map['waveform'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList() ?? [],
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : DateTime.now(),
    );
  }

  /// Get a value that pulses with the beat (useful for animations)
  double get beatPulse => beat;

  /// Get overall "vibe" - combination of energy and beat
  double get vibe => (energy * 0.6 + beat * 0.4).clamp(0.0, 1.0);
}

/// Device audio capabilities
class AudioCapabilities {
  final int nativeSampleRate;
  final int nativeBufferSize;
  final bool hasLowLatency;
  final bool hasProAudio;
  final List<String> supportedFormats;
  final int androidApiLevel;
  final String deviceModel;
  final String manufacturer;

  const AudioCapabilities({
    this.nativeSampleRate = 44100,
    this.nativeBufferSize = 256,
    this.hasLowLatency = false,
    this.hasProAudio = false,
    this.supportedFormats = const ['mp3', 'aac', 'flac', 'wav', 'ogg'],
    this.androidApiLevel = 21,
    this.deviceModel = '',
    this.manufacturer = '',
  });

  factory AudioCapabilities.fromMap(Map<dynamic, dynamic> map) {
    return AudioCapabilities(
      nativeSampleRate: map['nativeSampleRate'] as int? ?? 44100,
      nativeBufferSize: map['nativeBufferSize'] as int? ?? 256,
      hasLowLatency: map['hasLowLatency'] as bool? ?? false,
      hasProAudio: map['hasProAudio'] as bool? ?? false,
      supportedFormats: (map['supportedFormats'] as List<dynamic>?)
          ?.cast<String>() ?? ['mp3', 'aac', 'flac', 'wav', 'ogg'],
      androidApiLevel: map['androidApiLevel'] as int? ?? 21,
      deviceModel: map['deviceModel'] as String? ?? '',
      manufacturer: map['manufacturer'] as String? ?? '',
    );
  }

  bool get supportsHiRes => nativeSampleRate >= 96000 || hasProAudio;
}

/// VibeAudioService - Flutter interface to VibeAudioEngine
///
/// This is VibePlay's custom audio engine with built-in visualization.
/// It provides direct access to PCM audio data for real-time FFT analysis.
class VibeAudioService {
  static const _methodChannel = MethodChannel('com.vibeplay/vibe_audio');
  static const _eventChannel = EventChannel('com.vibeplay/vibe_audio_events');
  static const _pulseChannel = EventChannel('com.vibeplay/vibe_audio_pulse');

  // State
  final _stateController = BehaviorSubject<VibeAudioState>.seeded(VibeAudioState.idle);
  final _positionController = BehaviorSubject<Duration>.seeded(Duration.zero);
  final _durationController = BehaviorSubject<Duration>.seeded(Duration.zero);
  final _pulseController = BehaviorSubject<AudioPulseData>.seeded(AudioPulseData());
  final _completionController = PublishSubject<void>();

  Stream<VibeAudioState> get stateStream => _stateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<void> get completionStream => _completionController.stream;
  Stream<AudioPulseData> get pulseStream => _pulseController.stream;

  VibeAudioState get state => _stateController.value;
  Duration get position => _positionController.value;
  Duration get duration => _durationController.value;
  AudioPulseData get pulse => _pulseController.value;

  bool get isPlaying => state == VibeAudioState.playing;
  bool get isPaused => state == VibeAudioState.paused;
  bool get isReady => state == VibeAudioState.ready || isPlaying || isPaused;

  /// Check if native engine is actually prepared (queries native, not cached state)
  /// Use this before play() to ensure state sync
  Future<bool> isNativePrepared() async {
    try {
      final result = await _methodChannel.invokeMethod('isPrepared');
      return result == true;
    } catch (e) {
      Log.audio.d('VibeAudio: isPrepared check failed: $e');
      return false;
    }
  }

  /// Get native state for sync (use after EventChannel reconnection)
  Future<Map<String, dynamic>?> getNativeState() async {
    try {
      final result = await _methodChannel.invokeMethod('getNativeState');
      if (result != null) {
        return Map<String, dynamic>.from(result as Map);
      }
      return null;
    } catch (e) {
      Log.audio.d('VibeAudio: getNativeState failed: $e');
      return null;
    }
  }

  /// Sync Dart state with native state (call after EventChannel reconnection)
  Future<void> syncWithNativeState() async {
    final nativeState = await getNativeState();
    if (nativeState != null) {
      final isPrepared = nativeState['isPrepared'] as bool? ?? false;
      final isPlayingNative = nativeState['isPlaying'] as bool? ?? false;
      final position = nativeState['position'] as int? ?? 0;
      final duration = nativeState['duration'] as int? ?? 0;

      // Update Dart state to match native
      if (isPlayingNative) {
        _stateController.add(VibeAudioState.playing);
      } else if (isPrepared) {
        _stateController.add(VibeAudioState.paused);
      } else {
        _stateController.add(VibeAudioState.idle);
      }

      _positionController.add(Duration(milliseconds: position));
      _durationController.add(Duration(milliseconds: duration));

      Log.audio.d('VibeAudio: Synced with native - prepared=$isPrepared, playing=$isPlayingNative');
    }
  }

  int? _audioSessionId;
  int? get audioSessionId => _audioSessionId;

  AudioCapabilities? _capabilities;
  AudioCapabilities? get capabilities => _capabilities;

  StreamSubscription? _eventSubscription;
  StreamSubscription? _pulseSubscription;

  bool _isInitialized = false;

  int _pulseDebugCounter = 0;

  /// Initialize the audio service
  /// Can be called multiple times - will reconnect EventChannels if needed
  Future<void> initialize() async {
    Log.audio.d('VibeAudioService: initialize() called, _isInitialized=$_isInitialized');

    // Always reconnect EventChannels - they may be lost on app restart
    await _setupEventChannels();

    // Only get device capabilities once
    if (!_isInitialized) {
      await _loadDeviceCapabilities();
      _isInitialized = true;
    }

    // Sync Dart state with native state after EventChannel setup
    // This ensures our cached state matches what native engine thinks
    await syncWithNativeState();

    Log.audio.d('VibeAudioService initialized successfully');
  }

  /// Force full reinitialization (use after app restart)
  Future<void> reinitialize() async {
    Log.audio.d('VibeAudioService: Force reinitializing...');
    _isInitialized = false;
    await _cleanupEventChannels();
    await initialize();
  }

  /// Setup or reconnect EventChannel subscriptions
  Future<void> _setupEventChannels() async {
    // Cancel any existing subscriptions first
    await _cleanupEventChannels();

    Log.audio.d('VibeAudioService: Setting up EventChannels...');

    // Listen to state events
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _handleEvent,
      onError: (error) {
        Log.audio.d('VibeAudio event error: $error');
        // Try to reconnect on error
        _scheduleReconnect();
      },
      onDone: () {
        Log.audio.d('VibeAudio event stream closed');
        _scheduleReconnect();
      },
    );
    Log.audio.d('VibeAudioService: State event channel subscribed');

    // Listen to pulse events (high frequency)
    _pulseSubscription = _pulseChannel.receiveBroadcastStream().listen(
      _handlePulse,
      onError: (error) {
        Log.audio.d('VibeAudio pulse error: $error');
      },
      onDone: () {
        Log.audio.d('VibeAudio pulse stream closed - will reconnect');
        _scheduleReconnect();
      },
    );
    Log.audio.d('VibeAudioService: Pulse event channel subscribed');
  }

  /// Cleanup existing EventChannel subscriptions
  Future<void> _cleanupEventChannels() async {
    // Wrap in try-catch because canceling a stream that was never properly
    // subscribed (e.g., after Activity recreation) throws PlatformException
    try {
      await _eventSubscription?.cancel();
    } catch (e) {
      Log.audio.d('VibeAudio: Event subscription cancel: $e');
    }
    _eventSubscription = null;

    try {
      await _pulseSubscription?.cancel();
    } catch (e) {
      Log.audio.d('VibeAudio: Pulse subscription cancel: $e');
    }
    _pulseSubscription = null;
  }

  bool _reconnectScheduled = false;

  /// Schedule a reconnection attempt
  void _scheduleReconnect() {
    if (_reconnectScheduled) return;
    _reconnectScheduled = true;

    // Delay to avoid rapid reconnection attempts
    Future.delayed(const Duration(milliseconds: 500), () async {
      _reconnectScheduled = false;
      Log.audio.d('VibeAudioService: Attempting to reconnect EventChannels...');
      await _setupEventChannels();
    });
  }

  /// Load device audio capabilities
  Future<void> _loadDeviceCapabilities() async {
    try {
      final result = await _methodChannel.invokeMethod('getDeviceCapabilities');
      if (result != null) {
        _capabilities = AudioCapabilities.fromMap(result as Map);
        Log.audio.d('VibeAudio: Device capabilities loaded');
        Log.audio.d('  Sample rate: ${_capabilities!.nativeSampleRate}Hz');
        Log.audio.d('  Low latency: ${_capabilities!.hasLowLatency}');
        Log.audio.d('  Pro audio: ${_capabilities!.hasProAudio}');
      }
    } catch (e) {
      Log.audio.d('VibeAudio: Failed to get capabilities: $e');
    }
  }

  /// Prepare an audio file for playback
  Future<bool> prepare(String path) async {
    try {
      final result = await _methodChannel.invokeMethod('prepare', {'path': path});
      if (result != null && result['success'] == true) {
        _durationController.add(Duration(milliseconds: result['duration'] as int));
        _audioSessionId = result['audioSessionId'] as int?;
        _stateController.add(VibeAudioState.ready);
        Log.audio.d('VibeAudio: Prepared - duration=${result['duration']}ms, session=$_audioSessionId');
        return true;
      }
      return false;
    } catch (e) {
      Log.audio.d('VibeAudio: Prepare failed: $e');
      _stateController.add(VibeAudioState.error);
      return false;
    }
  }

  /// Start playback
  Future<void> play() async {
    try {
      await _methodChannel.invokeMethod('play');
      _stateController.add(VibeAudioState.playing);
    } catch (e) {
      Log.audio.d('VibeAudio: Play failed: $e');
    }
  }

  /// Pause playback
  Future<void> pause() async {
    try {
      await _methodChannel.invokeMethod('pause');
      _stateController.add(VibeAudioState.paused);
    } catch (e) {
      Log.audio.d('VibeAudio: Pause failed: $e');
    }
  }

  /// Resume playback
  Future<void> resume() async {
    try {
      await _methodChannel.invokeMethod('resume');
      _stateController.add(VibeAudioState.playing);
    } catch (e) {
      Log.audio.d('VibeAudio: Resume failed: $e');
    }
  }

  /// Stop playback
  Future<void> stop() async {
    try {
      await _methodChannel.invokeMethod('stop');
      _stateController.add(VibeAudioState.stopped);
      _positionController.add(Duration.zero);
    } catch (e) {
      Log.audio.d('VibeAudio: Stop failed: $e');
    }
  }

  /// Seek to position
  Future<void> seekTo(Duration position) async {
    try {
      await _methodChannel.invokeMethod('seekTo', {'position': position.inMilliseconds});
      _positionController.add(position);
    } catch (e) {
      Log.audio.d('VibeAudio: Seek failed: $e');
    }
  }

  /// Release resources
  Future<void> release() async {
    try {
      await _methodChannel.invokeMethod('release');
      _stateController.add(VibeAudioState.idle);
      _positionController.add(Duration.zero);
      _durationController.add(Duration.zero);
      _audioSessionId = null;
    } catch (e) {
      Log.audio.d('VibeAudio: Release failed: $e');
    }
  }

  //region Gapless Playback

  /// Enable or disable gapless playback
  Future<void> setGaplessEnabled(bool enabled) async {
    try {
      await _methodChannel.invokeMethod('setGaplessEnabled', {'enabled': enabled});
      Log.audio.d('VibeAudio: Gapless playback ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      Log.audio.d('VibeAudio: setGaplessEnabled failed: $e');
    }
  }

  /// Prepare the next track for gapless transition
  /// Call this while the current track is playing
  Future<bool> prepareNextTrack(String path) async {
    try {
      final result = await _methodChannel.invokeMethod('prepareNextTrack', {'path': path});
      final success = result == true;
      Log.audio.d('VibeAudio: prepareNextTrack ${success ? 'succeeded' : 'failed'}');
      return success;
    } catch (e) {
      Log.audio.d('VibeAudio: prepareNextTrack failed: $e');
      return false;
    }
  }

  /// Check if next track is ready for gapless transition
  Future<bool> isNextTrackReady() async {
    try {
      final result = await _methodChannel.invokeMethod('isNextTrackReady');
      return result == true;
    } catch (e) {
      Log.audio.d('VibeAudio: isNextTrackReady failed: $e');
      return false;
    }
  }

  /// Transition to the prepared next track (for gapless playback)
  /// Returns true if transition succeeded
  Future<bool> transitionToNextTrack() async {
    try {
      final result = await _methodChannel.invokeMethod('transitionToNextTrack');
      if (result != null && result['success'] == true) {
        _durationController.add(Duration(milliseconds: result['duration'] as int));
        _audioSessionId = result['audioSessionId'] as int?;
        _positionController.add(Duration.zero);
        Log.audio.d('VibeAudio: Gapless transition succeeded - duration=${result['duration']}ms');
        return true;
      }
      Log.audio.d('VibeAudio: Gapless transition failed');
      return false;
    } catch (e) {
      Log.audio.d('VibeAudio: transitionToNextTrack failed: $e');
      return false;
    }
  }

  /// Clear the prepared next track
  Future<void> clearNextTrack() async {
    try {
      await _methodChannel.invokeMethod('clearNextTrack');
      Log.audio.d('VibeAudio: Next track cleared');
    } catch (e) {
      Log.audio.d('VibeAudio: clearNextTrack failed: $e');
    }
  }

  //endregion

  //region Playback Controls

  /// Set playback speed (0.5 to 2.0)
  Future<void> setSpeed(double speed) async {
    try {
      await _methodChannel.invokeMethod('setSpeed', {'speed': speed});
      Log.audio.d('VibeAudio: Speed set to $speed');
    } catch (e) {
      Log.audio.d('VibeAudio: setSpeed failed: $e');
    }
  }

  /// Get current playback speed
  Future<double> getSpeed() async {
    try {
      final result = await _methodChannel.invokeMethod('getSpeed');
      return (result as num?)?.toDouble() ?? 1.0;
    } catch (e) {
      Log.audio.d('VibeAudio: getSpeed failed: $e');
      return 1.0;
    }
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    try {
      await _methodChannel.invokeMethod('setVolume', {'volume': volume});
      Log.audio.d('VibeAudio: Volume set to $volume');
    } catch (e) {
      Log.audio.d('VibeAudio: setVolume failed: $e');
    }
  }

  /// Get current volume
  Future<double> getVolume() async {
    try {
      final result = await _methodChannel.invokeMethod('getVolume');
      return (result as num?)?.toDouble() ?? 1.0;
    } catch (e) {
      Log.audio.d('VibeAudio: getVolume failed: $e');
      return 1.0;
    }
  }

  /// Set pitch in semitones (-12 to +12)
  /// 0 = normal pitch
  /// +12 = one octave higher
  /// -12 = one octave lower
  /// Unlike speed, pitch does NOT affect playback tempo.
  Future<void> setPitch(double semitones) async {
    try {
      await _methodChannel.invokeMethod('setPitch', {'semitones': semitones});
      Log.audio.d('VibeAudio: Pitch set to $semitones semitones');
    } catch (e) {
      Log.audio.d('VibeAudio: setPitch failed: $e');
    }
  }

  /// Get current pitch in semitones
  Future<double> getPitch() async {
    try {
      final result = await _methodChannel.invokeMethod('getPitch');
      return (result as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      Log.audio.d('VibeAudio: getPitch failed: $e');
      return 0.0;
    }
  }

  /// Check if pitch shifting is enabled
  Future<bool> isPitchEnabled() async {
    try {
      final result = await _methodChannel.invokeMethod('isPitchEnabled');
      return result == true;
    } catch (e) {
      Log.audio.d('VibeAudio: isPitchEnabled failed: $e');
      return false;
    }
  }

  //endregion

  //region Crossfade

  /// Enable or disable native crossfade
  Future<void> setCrossfadeEnabled(bool enabled) async {
    try {
      await _methodChannel.invokeMethod('setCrossfadeEnabled', {'enabled': enabled});
      Log.audio.d('VibeAudio: Crossfade ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      Log.audio.d('VibeAudio: setCrossfadeEnabled failed: $e');
    }
  }

  /// Check if crossfade is enabled
  Future<bool> isCrossfadeEnabled() async {
    try {
      final result = await _methodChannel.invokeMethod('isCrossfadeEnabled');
      return result == true;
    } catch (e) {
      Log.audio.d('VibeAudio: isCrossfadeEnabled failed: $e');
      return false;
    }
  }

  /// Set crossfade duration in milliseconds
  Future<void> setCrossfadeDuration(int durationMs) async {
    try {
      await _methodChannel.invokeMethod('setCrossfadeDuration', {'durationMs': durationMs});
      Log.audio.d('VibeAudio: Crossfade duration set to ${durationMs}ms');
    } catch (e) {
      Log.audio.d('VibeAudio: setCrossfadeDuration failed: $e');
    }
  }

  /// Get crossfade duration in milliseconds
  Future<int> getCrossfadeDuration() async {
    try {
      final result = await _methodChannel.invokeMethod('getCrossfadeDuration');
      return (result as int?) ?? 3000;
    } catch (e) {
      Log.audio.d('VibeAudio: getCrossfadeDuration failed: $e');
      return 3000;
    }
  }

  /// Start crossfade to the prepared next track
  /// Returns true if crossfade started successfully
  Future<bool> startCrossfade() async {
    try {
      final result = await _methodChannel.invokeMethod('startCrossfade');
      final success = result == true;
      Log.audio.d('VibeAudio: startCrossfade ${success ? 'succeeded' : 'failed'}');
      return success;
    } catch (e) {
      Log.audio.d('VibeAudio: startCrossfade failed: $e');
      return false;
    }
  }

  //endregion

  //region Native DSP Effects

  /// Enable or disable native DSP processing (EQ + Reverb)
  Future<void> setDSPEnabled(bool enabled) async {
    try {
      await _methodChannel.invokeMethod('setDSPEnabled', {'enabled': enabled});
    } catch (e) {
      Log.audio.d('VibeAudio: setDSPEnabled failed: $e');
    }
  }

  /// Check if DSP is enabled
  Future<bool> isDSPEnabled() async {
    try {
      final result = await _methodChannel.invokeMethod('isDSPEnabled');
      return result == true;
    } catch (e) {
      Log.audio.d('VibeAudio: isDSPEnabled failed: $e');
      return false;
    }
  }

  //endregion

  //region AudioPulse (FFT Analysis) Control

  /// Enable or disable AudioPulse FFT analysis.
  /// Disabling saves significant battery when visualizer is not visible.
  Future<void> setAudioPulseEnabled(bool enabled) async {
    try {
      await _methodChannel.invokeMethod('setAudioPulseEnabled', {'enabled': enabled});
      Log.audio.d('VibeAudio: AudioPulse ${enabled ? "enabled" : "disabled"}');
    } catch (e) {
      Log.audio.d('VibeAudio: setAudioPulseEnabled failed: $e');
    }
  }

  /// Check if AudioPulse FFT analysis is enabled
  Future<bool> isAudioPulseEnabled() async {
    try {
      final result = await _methodChannel.invokeMethod('isAudioPulseEnabled');
      return result == true;
    } catch (e) {
      Log.audio.d('VibeAudio: isAudioPulseEnabled failed: $e');
      return false;
    }
  }

  //endregion

  //region Native EQ

  /// Enable or disable native EQ
  Future<void> setNativeEQEnabled(bool enabled) async {
    try {
      await _methodChannel.invokeMethod('setNativeEQEnabled', {'enabled': enabled});
    } catch (e) {
      Log.audio.d('VibeAudio: setNativeEQEnabled failed: $e');
    }
  }

  /// Check if native EQ is enabled
  Future<bool> isNativeEQEnabled() async {
    try {
      final result = await _methodChannel.invokeMethod('isNativeEQEnabled');
      return result == true;
    } catch (e) {
      Log.audio.d('VibeAudio: isNativeEQEnabled failed: $e');
      return false;
    }
  }

  /// Set EQ band gain in dB (-12 to +12)
  /// Bands: 0=60Hz, 1=230Hz, 2=910Hz, 3=3.6kHz, 4=14kHz
  Future<void> setNativeEQBandGain(int band, double gainDb) async {
    try {
      await _methodChannel.invokeMethod('setNativeEQBandGain', {
        'band': band,
        'gain': gainDb,
      });
    } catch (e) {
      Log.audio.d('VibeAudio: setNativeEQBandGain failed: $e');
    }
  }

  /// Get EQ band gain
  Future<double> getNativeEQBandGain(int band) async {
    try {
      final result = await _methodChannel.invokeMethod('getNativeEQBandGain', {'band': band});
      return (result as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      Log.audio.d('VibeAudio: getNativeEQBandGain failed: $e');
      return 0.0;
    }
  }

  /// Get EQ band center frequency
  Future<double> getNativeEQBandFrequency(int band) async {
    try {
      final result = await _methodChannel.invokeMethod('getNativeEQBandFrequency', {'band': band});
      return (result as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      Log.audio.d('VibeAudio: getNativeEQBandFrequency failed: $e');
      return 0.0;
    }
  }

  /// Get number of EQ bands
  Future<int> getNativeEQBandCount() async {
    try {
      final result = await _methodChannel.invokeMethod('getNativeEQBandCount');
      return (result as int?) ?? 5;
    } catch (e) {
      Log.audio.d('VibeAudio: getNativeEQBandCount failed: $e');
      return 5;
    }
  }

  /// Enable or disable native reverb
  Future<void> setNativeReverbEnabled(bool enabled) async {
    try {
      await _methodChannel.invokeMethod('setNativeReverbEnabled', {'enabled': enabled});
    } catch (e) {
      Log.audio.d('VibeAudio: setNativeReverbEnabled failed: $e');
    }
  }

  /// Check if native reverb is enabled
  Future<bool> isNativeReverbEnabled() async {
    try {
      final result = await _methodChannel.invokeMethod('isNativeReverbEnabled');
      return result == true;
    } catch (e) {
      Log.audio.d('VibeAudio: isNativeReverbEnabled failed: $e');
      return false;
    }
  }

  /// Set reverb wet/dry mix (0-1)
  Future<void> setNativeReverbMix(double mix) async {
    try {
      await _methodChannel.invokeMethod('setNativeReverbMix', {'mix': mix});
    } catch (e) {
      Log.audio.d('VibeAudio: setNativeReverbMix failed: $e');
    }
  }

  /// Get reverb mix
  Future<double> getNativeReverbMix() async {
    try {
      final result = await _methodChannel.invokeMethod('getNativeReverbMix');
      return (result as num?)?.toDouble() ?? 0.3;
    } catch (e) {
      Log.audio.d('VibeAudio: getNativeReverbMix failed: $e');
      return 0.3;
    }
  }

  /// Set reverb decay/room size (0-1)
  Future<void> setNativeReverbDecay(double decay) async {
    try {
      await _methodChannel.invokeMethod('setNativeReverbDecay', {'decay': decay});
    } catch (e) {
      Log.audio.d('VibeAudio: setNativeReverbDecay failed: $e');
    }
  }

  /// Get reverb decay
  Future<double> getNativeReverbDecay() async {
    try {
      final result = await _methodChannel.invokeMethod('getNativeReverbDecay');
      return (result as num?)?.toDouble() ?? 0.5;
    } catch (e) {
      Log.audio.d('VibeAudio: getNativeReverbDecay failed: $e');
      return 0.5;
    }
  }

  /// Reset DSP state (call on track change)
  Future<void> resetDSP() async {
    try {
      await _methodChannel.invokeMethod('resetDSP');
    } catch (e) {
      Log.audio.d('VibeAudio: resetDSP failed: $e');
    }
  }

  //endregion

  //region Queue Management

  // Queue state
  List<Song> _queue = [];
  List<int> _shuffleIndices = [];
  int _currentIndex = -1;
  bool _shuffleMode = false;
  LoopMode _loopMode = LoopMode.off;

  // Queue streams
  final _currentSongController = BehaviorSubject<Song?>.seeded(null);
  final _currentIndexController = BehaviorSubject<int>.seeded(-1);
  final _queueController = BehaviorSubject<List<Song>>.seeded([]);
  final _shuffleModeController = BehaviorSubject<bool>.seeded(false);
  final _loopModeController = BehaviorSubject<LoopMode>.seeded(LoopMode.off);

  Stream<Song?> get currentSongStream => _currentSongController.stream;
  Stream<int> get currentIndexStream => _currentIndexController.stream;
  Stream<List<Song>> get queueStream => _queueController.stream;
  Stream<bool> get shuffleModeStream => _shuffleModeController.stream;
  Stream<LoopMode> get loopModeStream => _loopModeController.stream;

  Song? get currentSong => _currentSongController.value;
  int get currentIndex => _currentIndex;
  List<Song> get queue => List.unmodifiable(_queue);
  bool get shuffleMode => _shuffleMode;
  LoopMode get loopMode => _loopMode;

  /// Set the playback queue
  Future<void> setQueue(List<Song> songs, {int initialIndex = 0, bool autoPlay = true}) async {
    if (songs.isEmpty) {
      Log.audio.d('VibeAudio: setQueue called with empty list');
      return;
    }

    _queue = List.from(songs);
    _queueController.add(List.unmodifiable(_queue));

    // Generate shuffle indices if shuffle is enabled
    if (_shuffleMode) {
      _generateShuffleIndices(initialIndex);
    }

    Log.audio.d('VibeAudio: Queue set with ${songs.length} songs, starting at index $initialIndex, autoPlay=$autoPlay');

    if (autoPlay) {
      // Play the initial song
      await playAtIndex(initialIndex);
    } else {
      // Just prepare the track without playing
      await prepareAtIndex(initialIndex);
    }
  }

  /// Prepare a track at index without starting playback
  Future<bool> prepareAtIndex(int index) async {
    if (index < 0 || index >= _queue.length) {
      Log.audio.d('VibeAudio: prepareAtIndex - invalid index $index (queue size: ${_queue.length})');
      return false;
    }

    final song = _queue[index];
    if (song.path == null) {
      Log.audio.d('VibeAudio: prepareAtIndex - song has no path');
      return false;
    }

    _currentIndex = index;
    _currentIndexController.add(index);
    _currentSongController.add(song);

    Log.audio.d('VibeAudio: Preparing "${song.title}" at index $index');

    // Prepare but don't play
    return await prepare(song.path!);
  }

  /// Play song at specific index
  Future<void> playAtIndex(int index) async {
    if (index < 0 || index >= _queue.length) {
      Log.audio.d('VibeAudio: playAtIndex - invalid index $index (queue size: ${_queue.length})');
      return;
    }

    final song = _queue[index];
    if (song.path == null) {
      Log.audio.d('VibeAudio: playAtIndex - song has no path');
      return;
    }

    _currentIndex = index;
    _currentIndexController.add(index);
    _currentSongController.add(song);

    Log.audio.d('VibeAudio: Playing "${song.title}" at index $index');

    // Prepare and play
    final success = await prepare(song.path!);
    if (success) {
      await play();

      // Prepare next track for gapless playback
      _prepareNextTrackForGapless();
    }
  }

  /// Skip to next track
  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;

    final nextIndex = _getNextIndex();
    if (nextIndex != null) {
      await playAtIndex(nextIndex);
    } else {
      Log.audio.d('VibeAudio: No next track (end of queue, loop off)');
      await stop();
    }
  }

  /// Skip to previous track
  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;

    // If we're more than 3 seconds into the song, restart it
    if (position.inMilliseconds > 3000) {
      await seekTo(Duration.zero);
      return;
    }

    final prevIndex = _getPreviousIndex();
    if (prevIndex != null) {
      await playAtIndex(prevIndex);
    } else {
      // At the beginning, just restart current song
      await seekTo(Duration.zero);
    }
  }

  /// Add song to end of queue
  void addToQueue(Song song) {
    _queue.add(song);
    _queueController.add(List.unmodifiable(_queue));
    Log.audio.d('VibeAudio: Added "${song.title}" to queue (now ${_queue.length} songs)');

    // Update shuffle indices if needed
    if (_shuffleMode) {
      _shuffleIndices.add(_queue.length - 1);
    }
  }

  /// Add song to play next
  void playNext(Song song) {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) {
      addToQueue(song);
      return;
    }

    _queue.insert(_currentIndex + 1, song);
    _queueController.add(List.unmodifiable(_queue));
    Log.audio.d('VibeAudio: Added "${song.title}" to play next');

    // Update shuffle indices if in shuffle mode
    if (_shuffleMode) {
      // Shift indices that are >= insert position
      for (int i = 0; i < _shuffleIndices.length; i++) {
        if (_shuffleIndices[i] > _currentIndex) {
          _shuffleIndices[i]++;
        }
      }
      // Insert the new index after current position in shuffle order
      final currentShufflePos = _shuffleIndices.indexOf(_currentIndex);
      if (currentShufflePos >= 0) {
        _shuffleIndices.insert(currentShufflePos + 1, _currentIndex + 1);
      }
    }

    // Prepare for gapless if this is the next track
    _prepareNextTrackForGapless();
  }

  /// Remove song from queue
  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;

    final wasCurrentSong = index == _currentIndex;
    _queue.removeAt(index);
    _queueController.add(List.unmodifiable(_queue));

    // Update indices
    if (_shuffleMode) {
      _shuffleIndices.remove(index);
      for (int i = 0; i < _shuffleIndices.length; i++) {
        if (_shuffleIndices[i] > index) {
          _shuffleIndices[i]--;
        }
      }
    }

    if (index < _currentIndex) {
      _currentIndex--;
      _currentIndexController.add(_currentIndex);
    }

    Log.audio.d('VibeAudio: Removed song at index $index from queue');

    // If we removed the current song, play the next one
    if (wasCurrentSong && _queue.isNotEmpty) {
      final nextIndex = _currentIndex.clamp(0, _queue.length - 1);
      playAtIndex(nextIndex);
    }
  }

  /// Move song in queue
  void moveInQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0 || newIndex >= _queue.length) return;
    if (oldIndex == newIndex) return;

    final song = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, song);
    _queueController.add(List.unmodifiable(_queue));

    // Update current index if affected
    if (oldIndex == _currentIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }
    _currentIndexController.add(_currentIndex);

    Log.audio.d('VibeAudio: Moved song from $oldIndex to $newIndex');
  }

  /// Clear the queue
  void clearQueue() {
    _queue.clear();
    _shuffleIndices.clear();
    _currentIndex = -1;
    _queueController.add([]);
    _currentIndexController.add(-1);
    _currentSongController.add(null);
    Log.audio.d('VibeAudio: Queue cleared');
  }

  /// Set shuffle mode
  void setShuffleMode(bool enabled) {
    if (_shuffleMode == enabled) return;

    _shuffleMode = enabled;
    _shuffleModeController.add(enabled);

    if (enabled && _queue.isNotEmpty) {
      _generateShuffleIndices(_currentIndex);
    }

    Log.audio.d('VibeAudio: Shuffle ${enabled ? "enabled" : "disabled"}');
  }

  /// Set loop mode
  void setLoopMode(LoopMode mode) {
    _loopMode = mode;
    _loopModeController.add(mode);
    Log.audio.d('VibeAudio: Loop mode set to ${mode.name}');
  }

  /// Handle native auto-transition (native engine already started the next track)
  /// We just need to update our queue state and prepare the NEXT track after that
  Future<void> _onNativeAutoTransition() async {
    Log.audio.d('VibeAudio: Handling native auto-transition');
    Log.audio.d('VibeAudio: Current state before transition - index=$_currentIndex, queue.length=${_queue.length}');

    // Advance to the next index (native already playing it)
    final nextIndex = _getNextIndex();
    Log.audio.d('VibeAudio: _getNextIndex() returned $nextIndex');

    if (nextIndex != null && nextIndex < _queue.length) {
      final newSong = _queue[nextIndex];
      _currentIndex = nextIndex;
      _currentIndexController.add(_currentIndex);
      _currentSongController.add(newSong);

      Log.audio.d('VibeAudio: Queue advanced to index $_currentIndex - "${newSong.title}" by ${newSong.artist}');

      // Update state to playing (native is already playing)
      _stateController.add(VibeAudioState.playing);
      _positionController.add(Duration.zero);

      // Now prepare the NEXT track (the one after the one that's now playing)
      // This ensures continuous background playback
      await _prepareNextTrackForGapless();
    } else {
      Log.audio.d('VibeAudio: No next track in queue after auto-transition (nextIndex=$nextIndex, queue.length=${_queue.length})');
    }
  }

  /// Handle track completion (called when native engine signals completion)
  Future<void> onTrackCompleted() async {
    Log.audio.d('VibeAudio: Track completed, loopMode=$_loopMode');

    if (_loopMode == LoopMode.one) {
      // Repeat the same track
      await seekTo(Duration.zero);
      await play();
      return;
    }

    // Try gapless transition first
    final nextIndex = _getNextIndex();
    if (nextIndex != null) {
      final nextReady = await isNextTrackReady();
      if (nextReady) {
        // Gapless transition
        final success = await transitionToNextTrack();
        if (success) {
          _currentIndex = nextIndex;
          _currentIndexController.add(_currentIndex);
          _currentSongController.add(_queue[_currentIndex]);
          Log.audio.d('VibeAudio: Gapless transition to index $nextIndex');
          _prepareNextTrackForGapless();
          return;
        }
      }

      // Fall back to regular playback
      await playAtIndex(nextIndex);
    } else {
      Log.audio.d('VibeAudio: End of queue reached');
      _stateController.add(VibeAudioState.stopped);
    }
  }

  /// Get next track index respecting shuffle and loop modes
  int? _getNextIndex() {
    if (_queue.isEmpty) return null;

    if (_shuffleMode) {
      final currentShufflePos = _shuffleIndices.indexOf(_currentIndex);
      if (currentShufflePos < _shuffleIndices.length - 1) {
        return _shuffleIndices[currentShufflePos + 1];
      } else if (_loopMode == LoopMode.all) {
        return _shuffleIndices[0];
      }
      return null;
    } else {
      if (_currentIndex < _queue.length - 1) {
        return _currentIndex + 1;
      } else if (_loopMode == LoopMode.all) {
        return 0;
      }
      return null;
    }
  }

  /// Get previous track index
  int? _getPreviousIndex() {
    if (_queue.isEmpty) return null;

    if (_shuffleMode) {
      final currentShufflePos = _shuffleIndices.indexOf(_currentIndex);
      if (currentShufflePos > 0) {
        return _shuffleIndices[currentShufflePos - 1];
      } else if (_loopMode == LoopMode.all) {
        return _shuffleIndices.last;
      }
      return null;
    } else {
      if (_currentIndex > 0) {
        return _currentIndex - 1;
      } else if (_loopMode == LoopMode.all) {
        return _queue.length - 1;
      }
      return null;
    }
  }

  /// Generate shuffle indices with current song first
  void _generateShuffleIndices(int currentIndex) {
    _shuffleIndices = List.generate(_queue.length, (i) => i);

    // Remove current index and shuffle the rest
    if (currentIndex >= 0 && currentIndex < _queue.length) {
      _shuffleIndices.remove(currentIndex);
      _shuffleIndices.shuffle(Random());
      _shuffleIndices.insert(0, currentIndex);
    } else {
      _shuffleIndices.shuffle(Random());
    }

    Log.audio.d('VibeAudio: Generated shuffle indices: $_shuffleIndices');
  }

  /// Prepare the next track for gapless playback
  Future<void> _prepareNextTrackForGapless() async {
    final nextIndex = _getNextIndex();
    if (nextIndex == null) return;

    final nextSong = _queue[nextIndex];
    if (nextSong.path == null) return;

    Log.audio.d('VibeAudio: Preparing next track for gapless: "${nextSong.title}"');
    await prepareNextTrack(nextSong.path!);
  }

  /// Update a song in the queue (e.g., after tag editing)
  void updateSongInQueue(Song updatedSong) {
    for (int i = 0; i < _queue.length; i++) {
      if (_queue[i].id == updatedSong.id) {
        _queue[i] = updatedSong;
        if (i == _currentIndex) {
          _currentSongController.add(updatedSong);
        }
      }
    }
    _queueController.add(List.unmodifiable(_queue));
  }

  //endregion

  /// Dispose the service
  void dispose() {
    _eventSubscription?.cancel();
    _pulseSubscription?.cancel();
    _stateController.close();
    _positionController.close();
    _durationController.close();
    _pulseController.close();
    _completionController.close();
    // Queue controllers
    _currentSongController.close();
    _currentIndexController.close();
    _queueController.close();
    _shuffleModeController.close();
    _loopModeController.close();
    _isInitialized = false;
  }

  void _handleEvent(dynamic event) {
    if (event is! Map) return;

    final type = event['type'] as String?;
    final data = event['data'] as Map?;

    switch (type) {
      case 'stateChanged':
        final stateName = data?['state'] as String?;
        if (stateName != null) {
          final state = VibeAudioState.values.firstWhere(
            (s) => s.name.toUpperCase() == stateName.toUpperCase(),
            orElse: () => VibeAudioState.idle,
          );
          _stateController.add(state);
        }
        break;

      case 'positionChanged':
        final position = data?['position'] as int?;
        if (position != null) {
          _positionController.add(Duration(milliseconds: position));
        }
        break;

      case 'durationChanged':
        final duration = data?['duration'] as int?;
        if (duration != null) {
          _durationController.add(Duration(milliseconds: duration));
        }
        break;

      case 'completed':
        Log.audio.d('VibeAudio: Track completed event received');
        _completionController.add(null);  // Signal track completion for external listeners
        // Handle completion internally (respects loop mode, advances queue)
        onTrackCompleted();
        break;

      case 'autoTransition':
        // Native engine auto-advanced to the next track without waiting for us
        // We just need to update our queue state and prepare the NEXT track
        Log.audio.d('VibeAudio: Auto-transition event received - native already playing next track');
        _onNativeAutoTransition();
        break;

      case 'error':
        Log.audio.d('VibeAudio error: ${data?['message']}');
        _stateController.add(VibeAudioState.error);
        break;
    }
  }

  void _handlePulse(dynamic event) {
    if (event is Map) {
      final pulse = AudioPulseData.fromMap(event);
      _pulseController.add(pulse);

      // Debug: log occasionally to confirm data is flowing
      _pulseDebugCounter++;
      if (_pulseDebugCounter % 60 == 1) {
        Log.audio.d('VibeAudio PULSE: energy=${pulse.energy.toStringAsFixed(3)} bass=${pulse.bassTotal.toStringAsFixed(3)} beat=${pulse.beat.toStringAsFixed(2)}');
      }
    } else {
      Log.audio.d('VibeAudio: Received non-map pulse data: ${event.runtimeType}');
    }
  }
}

// Global instance
final vibeAudioService = VibeAudioService();
