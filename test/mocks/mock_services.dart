import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';

// ============ Hive Mocks ============

class MockBox<T> extends Mock implements Box<T> {}

// ============ Method Channel Mocks ============

/// Setup mock method channel for equalizer
void setupMockEqualizerChannel({
  void Function(MethodCall)? onMethodCall,
  Map<String, dynamic>? defaultProperties,
}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('com.vibeplay/equalizer'),
    (MethodCall call) async {
      // Allow recording the call
      onMethodCall?.call(call);

      switch (call.method) {
        case 'setAudioSessionId':
          return true;
        case 'setEnabled':
          return true;
        case 'setBandLevel':
          return true;
        case 'setAllBands':
          return true;
        case 'setBassBoost':
          return true;
        case 'setVirtualizer':
          return true;
        case 'getEqualizerProperties':
          return defaultProperties ?? {
            'bandCount': 10,
            'minLevel': -1200,
            'maxLevel': 1200,
            'frequencies': [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000],
          };
        case 'release':
          return null;
        default:
          return null;
      }
    },
  );
}

/// Setup mock method channel for audio effects
void setupMockAudioEffectsChannel({
  bool Function(MethodCall)? onMethodCall,
}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('com.vibeplay/audio_effects'),
    (MethodCall call) async {
      if (onMethodCall != null) {
        return onMethodCall(call);
      }

      switch (call.method) {
        case 'init':
          return true;
        case 'setAudioSessionId':
          return true;
        case 'setLoudnessEnhancer':
          return true;
        case 'setReverb':
          return true;
        case 'release':
          return null;
        default:
          return null;
      }
    },
  );
}

/// Setup mock method channel for VibeAudio engine
void setupMockVibeAudioChannel({
  bool Function(MethodCall)? onMethodCall,
  Map<String, dynamic>? capabilities,
}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('com.vibeplay/vibe_audio'),
    (MethodCall call) async {
      if (onMethodCall != null) {
        return onMethodCall(call);
      }

      switch (call.method) {
        case 'getDeviceCapabilities':
          return capabilities ?? {
            'maxSampleRate': 48000,
            'maxChannels': 2,
            'supportedFormats': ['mp3', 'flac', 'wav', 'm4a'],
            'supportsHiRes': true,
          };
        case 'prepare':
          return true;
        case 'play':
          return true;
        case 'pause':
          return true;
        case 'stop':
          return true;
        case 'seekTo':
          return true;
        case 'setVolume':
          return true;
        case 'setSpeed':
          return true;
        case 'getPosition':
          return 0;
        case 'getDuration':
          return 180000;
        case 'getAudioSessionId':
          return 12345;
        default:
          return null;
      }
    },
  );
}

/// Clear all mock method channels
void clearMockMethodChannels() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('com.vibeplay/equalizer'),
    null,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('com.vibeplay/audio_effects'),
    null,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('com.vibeplay/vibe_audio'),
    null,
  );
}

// ============ Audio Player Mocks ============

class MockAudioPlayer extends Mock implements AudioPlayer {}

// ============ Test Method Call Recorder ============

/// Records method calls for verification
class MethodCallRecorder {
  final List<MethodCall> calls = [];

  void record(MethodCall call) {
    calls.add(call);
  }

  bool hasCall(String method) {
    return calls.any((c) => c.method == method);
  }

  MethodCall? getCall(String method) {
    return calls.cast<MethodCall?>().firstWhere(
      (c) => c?.method == method,
      orElse: () => null,
    );
  }

  List<MethodCall> getCalls(String method) {
    return calls.where((c) => c.method == method).toList();
  }

  void clear() {
    calls.clear();
  }
}
