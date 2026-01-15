import 'package:flutter/services.dart';
import 'log_service.dart';

class EqualizerService {
  static const _channel = MethodChannel('com.vibeplay/equalizer');

  int? _audioSessionId;

  /// Get the current audio session ID (useful for debugging)
  int? get audioSessionId => _audioSessionId;

  Future<void> setAudioSessionId(int sessionId) async {
    _audioSessionId = sessionId;
    try {
      await _channel.invokeMethod('setAudioSessionId', {'sessionId': sessionId});
    } catch (e) {
      Log.eq.d('EqualizerService: Failed to set audio session ID: $e');
    }
  }

  Future<bool> setEnabled(bool enabled) async {
    try {
      final result = await _channel.invokeMethod<bool>('setEnabled', {'enabled': enabled});
      return result ?? false;
    } catch (e) {
      Log.eq.d('EqualizerService: Failed to set enabled: $e');
      return false;
    }
  }

  Future<bool> setBandLevel(int bandIndex, double level) async {
    try {
      // Convert from -10 to 10 dB range to centibels (-1000 to 1000)
      // Native code divides by 100 to get dB, then clamps to -12 to +12 dB
      final centibels = (level * 100).round();
      final result = await _channel.invokeMethod<bool>('setBandLevel', {
        'band': bandIndex,
        'level': centibels,
      });
      return result ?? false;
    } catch (e) {
      Log.eq.d('EqualizerService: Failed to set band level: $e');
      return false;
    }
  }

  Future<bool> setAllBands(List<double> levels) async {
    try {
      // Convert all bands from dB to centibels
      final centibels = levels.map((level) => (level * 100).round()).toList();
      final result = await _channel.invokeMethod<bool>('setAllBands', {
        'levels': centibels,
      });
      return result ?? false;
    } catch (e) {
      Log.eq.d('EqualizerService: Failed to set all bands: $e');
      return false;
    }
  }

  Future<bool> setBassBoost(double strength) async {
    try {
      // Convert from 0-1 to 0-1000
      final result = await _channel.invokeMethod<bool>('setBassBoost', {
        'strength': (strength * 1000).round(),
      });
      return result ?? false;
    } catch (e) {
      Log.eq.d('EqualizerService: Failed to set bass boost: $e');
      return false;
    }
  }

  Future<bool> setVirtualizer(double strength) async {
    try {
      // Convert from 0-1 to 0-1000
      final result = await _channel.invokeMethod<bool>('setVirtualizer', {
        'strength': (strength * 1000).round(),
      });
      return result ?? false;
    } catch (e) {
      Log.eq.d('EqualizerService: Failed to set virtualizer: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getEqualizerProperties() async {
    try {
      final result = await _channel.invokeMethod<Map>('getEqualizerProperties');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e) {
      Log.eq.d('EqualizerService: Failed to get equalizer properties: $e');
      return null;
    }
  }

  Future<void> release() async {
    try {
      await _channel.invokeMethod('release');
    } catch (e) {
      Log.eq.d('EqualizerService: Failed to release: $e');
    }
  }
}

// Singleton instance
final equalizerService = EqualizerService();
