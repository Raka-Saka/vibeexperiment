import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibeplay/services/equalizer_service.dart';
import 'package:vibeplay/services/log_service.dart';

import '../mocks/mock_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Initialize logging - required for services that use Log
    // The debug output is expected for error handling tests
    await Log.init();
  });

  group('EqualizerService', () {
    late EqualizerService service;
    late MethodCallRecorder recorder;

    setUp(() {
      service = EqualizerService();
      recorder = MethodCallRecorder();

      setupMockEqualizerChannel(
        onMethodCall: (call) => recorder.record(call),
      );
    });

    tearDown(() {
      clearMockMethodChannels();
      recorder.clear();
    });

    group('setAudioSessionId', () {
      test('stores audio session ID', () async {
        await service.setAudioSessionId(12345);

        expect(service.audioSessionId, equals(12345));
      });

      test('invokes native method with correct parameters', () async {
        await service.setAudioSessionId(12345);

        expect(recorder.hasCall('setAudioSessionId'), isTrue);
        final call = recorder.getCall('setAudioSessionId');
        expect(call?.arguments['sessionId'], equals(12345));
      });
    });

    group('setEnabled', () {
      test('returns true on success', () async {
        final result = await service.setEnabled(true);

        expect(result, isTrue);
      });

      test('invokes native method with enabled=true', () async {
        await service.setEnabled(true);

        final call = recorder.getCall('setEnabled');
        expect(call?.arguments['enabled'], isTrue);
      });

      test('invokes native method with enabled=false', () async {
        await service.setEnabled(false);

        final call = recorder.getCall('setEnabled');
        expect(call?.arguments['enabled'], isFalse);
      });
    });

    group('setBandLevel', () {
      test('converts dB to centibels correctly', () async {
        // 5 dB should become 500 centibels
        await service.setBandLevel(0, 5.0);

        final call = recorder.getCall('setBandLevel');
        expect(call?.arguments['band'], equals(0));
        expect(call?.arguments['level'], equals(500));
      });

      test('handles negative dB values', () async {
        // -3 dB should become -300 centibels
        await service.setBandLevel(2, -3.0);

        final call = recorder.getCall('setBandLevel');
        expect(call?.arguments['band'], equals(2));
        expect(call?.arguments['level'], equals(-300));
      });

      test('handles zero dB', () async {
        await service.setBandLevel(5, 0.0);

        final call = recorder.getCall('setBandLevel');
        expect(call?.arguments['level'], equals(0));
      });

      test('handles decimal dB values', () async {
        // 2.5 dB should become 250 centibels
        await service.setBandLevel(3, 2.5);

        final call = recorder.getCall('setBandLevel');
        expect(call?.arguments['level'], equals(250));
      });

      test('returns true on success', () async {
        final result = await service.setBandLevel(0, 5.0);

        expect(result, isTrue);
      });
    });

    group('setAllBands', () {
      test('converts all band levels to centibels', () async {
        final levels = [0.0, 2.0, 4.0, 6.0, 3.0, 0.0, -2.0, -4.0, -3.0, 0.0];
        await service.setAllBands(levels);

        final call = recorder.getCall('setAllBands');
        final sentLevels = call?.arguments['levels'] as List;
        expect(sentLevels, equals([0, 200, 400, 600, 300, 0, -200, -400, -300, 0]));
      });

      test('handles empty list', () async {
        await service.setAllBands([]);

        final call = recorder.getCall('setAllBands');
        final sentLevels = call?.arguments['levels'] as List;
        expect(sentLevels, isEmpty);
      });

      test('returns true on success', () async {
        final result = await service.setAllBands([0.0, 0.0, 0.0]);

        expect(result, isTrue);
      });
    });

    group('setBassBoost', () {
      test('converts 0-1 range to 0-1000', () async {
        await service.setBassBoost(0.5);

        final call = recorder.getCall('setBassBoost');
        expect(call?.arguments['strength'], equals(500));
      });

      test('handles minimum value', () async {
        await service.setBassBoost(0.0);

        final call = recorder.getCall('setBassBoost');
        expect(call?.arguments['strength'], equals(0));
      });

      test('handles maximum value', () async {
        await service.setBassBoost(1.0);

        final call = recorder.getCall('setBassBoost');
        expect(call?.arguments['strength'], equals(1000));
      });

      test('returns true on success', () async {
        final result = await service.setBassBoost(0.5);

        expect(result, isTrue);
      });
    });

    group('setVirtualizer', () {
      test('converts 0-1 range to 0-1000', () async {
        await service.setVirtualizer(0.75);

        final call = recorder.getCall('setVirtualizer');
        expect(call?.arguments['strength'], equals(750));
      });

      test('returns true on success', () async {
        final result = await service.setVirtualizer(0.5);

        expect(result, isTrue);
      });
    });

    group('getEqualizerProperties', () {
      test('returns equalizer properties', () async {
        final properties = await service.getEqualizerProperties();

        expect(properties, isNotNull);
        expect(properties!['bandCount'], equals(10));
        expect(properties['minLevel'], equals(-1200));
        expect(properties['maxLevel'], equals(1200));
      });

      test('returns correct frequency list', () async {
        final properties = await service.getEqualizerProperties();

        final frequencies = properties!['frequencies'] as List;
        expect(frequencies.length, equals(10));
        expect(frequencies.first, equals(31));
        expect(frequencies.last, equals(16000));
      });
    });

    group('release', () {
      test('invokes native release method', () async {
        await service.release();

        expect(recorder.hasCall('release'), isTrue);
      });
    });

    group('error handling', () {
      setUp(() {
        setupMockEqualizerChannel(
          onMethodCall: (call) {
            throw PlatformException(code: 'ERROR', message: 'Test error');
          },
        );
      });

      test('setEnabled returns false on error', () async {
        final result = await service.setEnabled(true);

        expect(result, isFalse);
      });

      test('setBandLevel returns false on error', () async {
        final result = await service.setBandLevel(0, 5.0);

        expect(result, isFalse);
      });

      test('setAllBands returns false on error', () async {
        final result = await service.setAllBands([0.0, 0.0]);

        expect(result, isFalse);
      });

      test('setBassBoost returns false on error', () async {
        final result = await service.setBassBoost(0.5);

        expect(result, isFalse);
      });

      test('setVirtualizer returns false on error', () async {
        final result = await service.setVirtualizer(0.5);

        expect(result, isFalse);
      });

      test('getEqualizerProperties returns null on error', () async {
        final properties = await service.getEqualizerProperties();

        expect(properties, isNull);
      });
    });
  });
}
