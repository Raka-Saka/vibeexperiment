import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/library/presentation/screens/library_screen.dart';

class VibePlayApp extends ConsumerWidget {
  const VibePlayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Set system UI overlay style for immersive experience
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppTheme.darkBackground,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    return MaterialApp(
      title: 'VibePlay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const LibraryScreen(),
    );
  }
}
