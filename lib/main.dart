import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'services/audio_handler.dart';
import 'services/log_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logging first
  await Log.init();
  Log.i('VibePlay starting...');

  // Initialize Hive for local storage
  await Hive.initFlutter();
  Log.storage.d('Hive initialized');

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
