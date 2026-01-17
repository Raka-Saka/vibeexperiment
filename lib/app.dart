import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/library/presentation/screens/library_screen.dart';
import 'l10n/app_localizations.dart';

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
      // Localization support
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),      // English
        Locale('ja'),      // Japanese
        Locale('fr'),      // French
        Locale('my'),      // Myanmar (Burmese)
        Locale('bn'),      // Bengali
        Locale('pt'),      // Portuguese
        Locale('es'),      // Spanish
      ],
      home: const LibraryScreen(),
    );
  }
}
