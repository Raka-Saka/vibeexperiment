import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_handler.dart';

class SleepTimerState {
  final bool isActive;
  final Duration remaining;
  final Duration total;
  final bool fadeOut;

  const SleepTimerState({
    this.isActive = false,
    this.remaining = Duration.zero,
    this.total = Duration.zero,
    this.fadeOut = true,
  });

  SleepTimerState copyWith({
    bool? isActive,
    Duration? remaining,
    Duration? total,
    bool? fadeOut,
  }) {
    return SleepTimerState(
      isActive: isActive ?? this.isActive,
      remaining: remaining ?? this.remaining,
      total: total ?? this.total,
      fadeOut: fadeOut ?? this.fadeOut,
    );
  }

  double get progress => total.inSeconds > 0
      ? remaining.inSeconds / total.inSeconds
      : 0.0;

  String get remainingFormatted {
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}

class SleepTimerNotifier extends StateNotifier<SleepTimerState> {
  Timer? _timer;
  Timer? _fadeTimer;
  double _originalVolume = 1.0;

  SleepTimerNotifier() : super(const SleepTimerState());

  void start(Duration duration, {bool fadeOut = true}) {
    cancel();

    state = SleepTimerState(
      isActive: true,
      remaining: duration,
      total: duration,
      fadeOut: fadeOut,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remaining.inSeconds <= 0) {
        _stop();
      } else {
        state = state.copyWith(
          remaining: state.remaining - const Duration(seconds: 1),
        );

        // Start fade out in last 30 seconds
        if (fadeOut && state.remaining.inSeconds <= 30 && _fadeTimer == null) {
          _startFadeOut();
        }
      }
    });
  }

  void _startFadeOut() {
    _originalVolume = 1.0; // audioHandler.volume
    final fadeSteps = 30; // 30 seconds
    final volumeStep = _originalVolume / fadeSteps;

    _fadeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final newVolume = _originalVolume - (volumeStep * (fadeSteps - state.remaining.inSeconds + 1));
      if (newVolume > 0) {
        audioHandler.setVolume(newVolume.clamp(0.0, 1.0));
      } else {
        timer.cancel();
      }
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _fadeTimer?.cancel();
    _fadeTimer = null;

    // Stop playback
    audioHandler.pause();

    // Restore volume
    audioHandler.setVolume(_originalVolume);

    state = const SleepTimerState();
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _fadeTimer?.cancel();
    _fadeTimer = null;

    // Restore volume if we were fading
    audioHandler.setVolume(_originalVolume);

    state = const SleepTimerState();
  }

  void addTime(Duration duration) {
    if (state.isActive) {
      state = state.copyWith(
        remaining: state.remaining + duration,
        total: state.total + duration,
      );
    }
  }

  void toggleFadeOut() {
    state = state.copyWith(fadeOut: !state.fadeOut);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeTimer?.cancel();
    super.dispose();
  }
}

// Preset durations
class SleepTimerPresets {
  static const fiveMinutes = Duration(minutes: 5);
  static const tenMinutes = Duration(minutes: 10);
  static const fifteenMinutes = Duration(minutes: 15);
  static const thirtyMinutes = Duration(minutes: 30);
  static const fortyFiveMinutes = Duration(minutes: 45);
  static const oneHour = Duration(hours: 1);
  static const oneAndHalfHours = Duration(hours: 1, minutes: 30);
  static const twoHours = Duration(hours: 2);

  static const all = [
    ('5 min', fiveMinutes),
    ('10 min', tenMinutes),
    ('15 min', fifteenMinutes),
    ('30 min', thirtyMinutes),
    ('45 min', fortyFiveMinutes),
    ('1 hour', oneHour),
    ('1.5 hours', oneAndHalfHours),
    ('2 hours', twoHours),
  ];
}

// Provider
final sleepTimerProvider = StateNotifierProvider<SleepTimerNotifier, SleepTimerState>(
  (ref) => SleepTimerNotifier(),
);
