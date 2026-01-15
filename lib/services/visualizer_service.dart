import 'dart:async';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';
import 'log_service.dart';

/// Visualizer data containing FFT and waveform information
class VisualizerData {
  final List<double> fft;          // FFT magnitudes (frequency spectrum)
  final List<double> waveform;     // Waveform data (amplitude over time)
  final DateTime timestamp;

  const VisualizerData({
    required this.fft,
    required this.waveform,
    required this.timestamp,
  });

  /// Get normalized FFT data (0.0 to 1.0)
  List<double> get normalizedFft {
    if (fft.isEmpty) return [];
    final max = fft.reduce((a, b) => a > b ? a : b);
    if (max == 0) return List.filled(fft.length, 0.0);
    return fft.map((v) => (v / max).clamp(0.0, 1.0)).toList();
  }

  /// Get normalized waveform data (-1.0 to 1.0)
  List<double> get normalizedWaveform {
    if (waveform.isEmpty) return [];
    // Waveform data is typically 0-255, center is 128
    return waveform.map((v) => ((v - 128) / 128).clamp(-1.0, 1.0)).toList();
  }

  /// Get frequency bands (bass, mid, treble)
  Map<String, double> get frequencyBands {
    if (fft.isEmpty) return {'bass': 0, 'mid': 0, 'treble': 0};

    final normalized = normalizedFft;
    final bandSize = normalized.length ~/ 3;

    double bass = 0, mid = 0, treble = 0;

    for (int i = 0; i < bandSize; i++) {
      bass += normalized[i];
    }
    for (int i = bandSize; i < bandSize * 2; i++) {
      mid += normalized[i];
    }
    for (int i = bandSize * 2; i < normalized.length; i++) {
      treble += normalized[i];
    }

    return {
      'bass': (bass / bandSize).clamp(0.0, 1.0),
      'mid': (mid / bandSize).clamp(0.0, 1.0),
      'treble': (treble / (normalized.length - bandSize * 2)).clamp(0.0, 1.0),
    };
  }

  /// Reduce FFT to specified number of bands
  List<double> reduceToBands(int numBands) {
    if (fft.isEmpty || numBands <= 0) return [];

    final normalized = normalizedFft;
    final bandSize = normalized.length / numBands;
    final result = <double>[];

    for (int i = 0; i < numBands; i++) {
      final start = (i * bandSize).floor();
      final end = ((i + 1) * bandSize).floor().clamp(0, normalized.length);

      double sum = 0;
      for (int j = start; j < end; j++) {
        sum += normalized[j];
      }
      result.add(sum / (end - start));
    }

    return result;
  }
}

/// Available visualizer types
enum VisualizerType {
  bars,      // Classic frequency bars
  wave,      // Waveform line
  circular,  // Circular spectrum
  particles, // Particle effects based on frequency
  blob,      // Morphing blob
}

/// Permission status for visualizer
enum VisualizerPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  notRequested,
}

/// Service for capturing and streaming audio visualization data
class VisualizerService {
  static const _channel = MethodChannel('com.vibeplay/visualizer');
  static const _eventChannel = EventChannel('com.vibeplay/visualizer_events');

  bool _isCapturing = false;
  StreamSubscription? _eventSubscription;
  VisualizerPermissionStatus _permissionStatus = VisualizerPermissionStatus.notRequested;

  final _dataController = BehaviorSubject<VisualizerData>();
  Stream<VisualizerData> get dataStream => _dataController.stream;
  VisualizerData? get currentData => _dataController.valueOrNull;

  bool get isCapturing => _isCapturing;
  VisualizerPermissionStatus get permissionStatus => _permissionStatus;
  bool get hasPermission => _permissionStatus == VisualizerPermissionStatus.granted;

  /// Check current permission status without requesting
  Future<VisualizerPermissionStatus> checkPermission() async {
    final status = await Permission.microphone.status;
    _permissionStatus = _mapPermissionStatus(status);
    return _permissionStatus;
  }

  /// Request permission for audio visualization
  /// Returns true if permission was granted, false otherwise
  /// Only requests if not already granted or permanently denied
  Future<bool> requestPermission() async {
    // First check current status
    final currentStatus = await Permission.microphone.status;

    if (currentStatus.isGranted) {
      _permissionStatus = VisualizerPermissionStatus.granted;
      return true;
    }

    if (currentStatus.isPermanentlyDenied) {
      _permissionStatus = VisualizerPermissionStatus.permanentlyDenied;
      return false;
    }

    // Request permission
    final result = await Permission.microphone.request();
    _permissionStatus = _mapPermissionStatus(result);

    Log.audio.d('Visualizer: Permission request result: $_permissionStatus');
    return result.isGranted;
  }

  /// Open app settings so user can manually grant permission
  Future<bool> openSettings() async {
    return await openAppSettings();
  }

  VisualizerPermissionStatus _mapPermissionStatus(PermissionStatus status) {
    if (status.isGranted) return VisualizerPermissionStatus.granted;
    if (status.isPermanentlyDenied) return VisualizerPermissionStatus.permanentlyDenied;
    if (status.isDenied) return VisualizerPermissionStatus.denied;
    return VisualizerPermissionStatus.notRequested;
  }

  /// Set the audio session ID for visualization
  Future<void> setAudioSessionId(int sessionId) async {
    try {
      await _channel.invokeMethod('setAudioSessionId', {'sessionId': sessionId});
      Log.audio.d('Visualizer: Set audio session ID: $sessionId');
    } catch (e) {
      Log.audio.d('Visualizer: Failed to set audio session ID: $e');
    }
  }

  /// Check if visualizer is available (requires RECORD_AUDIO permission)
  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (e) {
      Log.audio.d('Visualizer: Availability check failed: $e');
      return false;
    }
  }

  /// Start capturing audio data
  Future<bool> startCapture({int captureRate = 60}) async {
    if (_isCapturing) return true;

    try {
      final result = await _channel.invokeMethod<bool>(
        'startCapture',
        {'captureRate': captureRate},
      );

      if (result == true) {
        _isCapturing = true;
        _startEventStream();
        Log.audio.d('Visualizer: Capture started at $captureRate fps');
        return true;
      }
      return false;
    } catch (e) {
      Log.audio.d('Visualizer: Failed to start capture: $e');
      return false;
    }
  }

  /// Stop capturing audio data
  Future<void> stopCapture() async {
    if (!_isCapturing) return;

    try {
      await _channel.invokeMethod('stopCapture');
      _isCapturing = false;
      _stopEventStream();
      Log.audio.d('Visualizer: Capture stopped');
    } catch (e) {
      Log.audio.d('Visualizer: Failed to stop capture: $e');
    }
  }

  void _startEventStream() {
    _eventSubscription?.cancel();
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic data) {
        if (data is Map) {
          _processEventData(data);
        }
      },
      onError: (error) {
        Log.audio.d('Visualizer: Event stream error: $error');
      },
    );
  }

  void _stopEventStream() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  void _processEventData(Map<dynamic, dynamic> data) {
    try {
      final fftRaw = data['fft'] as List<dynamic>?;
      final waveformRaw = data['waveform'] as List<dynamic>?;
      final timestamp = data['timestamp'] as int?;

      final fft = fftRaw?.map((e) => (e as num).toDouble()).toList() ?? [];
      final waveform = waveformRaw?.map((e) => (e as num).toDouble()).toList() ?? [];

      final visualizerData = VisualizerData(
        fft: fft,
        waveform: waveform,
        timestamp: timestamp != null
            ? DateTime.fromMillisecondsSinceEpoch(timestamp)
            : DateTime.now(),
      );

      _dataController.add(visualizerData);
    } catch (e) {
      Log.audio.d('Visualizer: Failed to process event data: $e');
    }
  }

  /// Get current FFT data (one-shot)
  Future<List<double>?> getFftData() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getFftData');
      return result?.map((e) => (e as num).toDouble()).toList();
    } catch (e) {
      Log.audio.d('Visualizer: Failed to get FFT data: $e');
      return null;
    }
  }

  /// Get current waveform data (one-shot)
  Future<List<double>?> getWaveformData() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getWaveformData');
      return result?.map((e) => (e as num).toDouble()).toList();
    } catch (e) {
      Log.audio.d('Visualizer: Failed to get waveform data: $e');
      return null;
    }
  }

  /// Release resources
  Future<void> release() async {
    await stopCapture();
    try {
      await _channel.invokeMethod('release');
    } catch (e) {
      Log.audio.d('Visualizer: Failed to release: $e');
    }
  }

  void dispose() {
    _stopEventStream();
    _dataController.close();
  }
}

// Global instance
final visualizerService = VisualizerService();
