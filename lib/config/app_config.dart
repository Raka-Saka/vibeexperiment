// ============================================================================
// APP CONFIGURATION
// ============================================================================
// Non-secret application configuration.
// This file can be committed to version control.
// ============================================================================

class AppConfig {
  // App info
  static const String appName = 'VibePlay';
  static const String appVersion = '1.1.0';

  // YouTube upload defaults
  static const String defaultYouTubePrivacy = 'public'; // public, unlisted, private
  static const String youtubeCategory = '10'; // Music category

  // Audio settings
  static const int defaultCrossfadeDuration = 3; // seconds
  static const int maxCrossfadeDuration = 12; // seconds
  static const int artworkCacheSize = 50; // LRU cache items

  // Visualizer settings
  static const int fftSize = 2048;
  static const int spectrumBands = 32;
  static const double visualizerFps = 60.0;

  // Equalizer
  static const int eqBands = 10;
  static const double eqMinGain = -12.0; // dB
  static const double eqMaxGain = 12.0; // dB

  // Volume normalization
  static const double targetLoudness = -14.0; // LUFS

  // Sleep timer presets (in minutes)
  static const List<int> sleepTimerPresets = [5, 10, 15, 30, 45, 60, 90, 120];
}
