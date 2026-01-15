import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../shared/models/song.dart';
import 'log_service.dart';

/// Service to manage home screen widget updates via native method channel
class WidgetService {
  static const _channel = MethodChannel('com.vibeplay/widget');

  static final WidgetService _instance = WidgetService._internal();
  factory WidgetService() => _instance;
  WidgetService._internal();

  bool _initialized = false;

  /// Initialize the widget service
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  /// Update widget with current playback state
  Future<void> updateWidget({
    required Song? song,
    required bool isPlaying,
  }) async {
    try {
      String? artworkPath;

      // Save artwork if available
      if (song?.artwork != null) {
        artworkPath = await _saveArtworkToFile(song!.artwork!);
      }

      await _channel.invokeMethod('updateWidget', {
        'title': song?.title ?? 'No song playing',
        'artist': song?.artistDisplay ?? '',
        'isPlaying': isPlaying,
        'artworkPath': artworkPath,
      });
    } catch (e) {
      Log.d('WidgetService: Failed to update widget: $e');
    }
  }

  /// Update only the playing state (for quick toggle updates)
  Future<void> updatePlayingState(bool isPlaying) async {
    try {
      await _channel.invokeMethod('updatePlayingState', {
        'isPlaying': isPlaying,
      });
    } catch (e) {
      Log.d('WidgetService: Failed to update playing state: $e');
    }
  }

  /// Clear widget data when playback stops
  Future<void> clearWidget() async {
    try {
      await _channel.invokeMethod('clearWidget');
    } catch (e) {
      Log.d('WidgetService: Failed to clear widget: $e');
    }
  }

  Future<String> _saveArtworkToFile(Uint8List artwork) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/widget_artwork.jpg');
    await file.writeAsBytes(artwork);
    return file.path;
  }
}

// Singleton instance
final widgetService = WidgetService();
