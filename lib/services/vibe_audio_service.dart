import 'dart:async';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import 'log_service.dart';

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
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    await _pulseSubscription?.cancel();
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

  /// Dispose the service
  void dispose() {
    _eventSubscription?.cancel();
    _pulseSubscription?.cancel();
    _stateController.close();
    _positionController.close();
    _durationController.close();
    _pulseController.close();
    _completionController.close();
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
        _stateController.add(VibeAudioState.stopped);
        _positionController.add(Duration.zero);
        _completionController.add(null);  // Signal track completion
        Log.audio.d('VibeAudio: Track completed - signaling completion stream');
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
