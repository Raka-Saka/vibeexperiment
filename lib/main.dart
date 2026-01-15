import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'services/audio_handler.dart';
import 'services/log_service.dart';
import 'services/play_statistics_service.dart';
import 'services/equalizer_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logging first
  await Log.init();
  Log.i('VibePlay starting...');

  // Initialize Hive for local storage
  await Hive.initFlutter();
  Log.storage.d('Hive initialized');

  // Initialize play statistics service (for play counts on song tiles)
  await playStatisticsService.init();
  Log.storage.d('Play statistics initialized: ${playStatisticsService.statsCount} songs tracked');

  // Initialize equalizer storage (for restoring EQ settings)
  await equalizerStorageService.init();
  final savedEQ = equalizerStorageService.globalState;
  Log.eq.d('Equalizer storage initialized:');
  Log.eq.d('  - EQ enabled: ${savedEQ.isEnabled}');
  Log.eq.d('  - Preset: ${savedEQ.presetName}');
  Log.eq.d('  - Bands: ${savedEQ.bands}');
  Log.eq.d('  - Bass: ${savedEQ.bassBoost}, Virt: ${savedEQ.virtualizer}');

  // Initialize audio service for background playback
  await initAudioService();
  Log.audio.d('Audio service initialized');

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Enable edge-to-edge mode
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  runApp(
    const ProviderScope(
      child: VibePlayApp(),
    ),
  );
}
