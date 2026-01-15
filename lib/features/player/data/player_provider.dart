import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../services/audio_handler.dart';
import '../../../services/widget_service.dart';
import '../../../shared/models/song.dart';

// Player state
class AppPlayerState {
  final Song? currentSong;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final LoopMode loopMode;
  final bool shuffleMode;
  final double speed;
  final List<Song> queue;
  final int currentIndex;

  const AppPlayerState({
    this.currentSong,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.loopMode = LoopMode.off,
    this.shuffleMode = false,
    this.speed = 1.0,
    this.queue = const [],
    this.currentIndex = 0,
  });

  AppPlayerState copyWith({
    Song? currentSong,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    LoopMode? loopMode,
    bool? shuffleMode,
    double? speed,
    List<Song>? queue,
    int? currentIndex,
  }) {
    return AppPlayerState(
      currentSong: currentSong ?? this.currentSong,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      loopMode: loopMode ?? this.loopMode,
      shuffleMode: shuffleMode ?? this.shuffleMode,
      speed: speed ?? this.speed,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

// Player notifier
class PlayerNotifier extends StateNotifier<AppPlayerState> {
  final WidgetService _widgetService = WidgetService();
  final List<StreamSubscription> _subscriptions = [];

  PlayerNotifier() : super(const AppPlayerState()) {
    _init();
  }

  void _init() {
    // Initialize widget service
    _widgetService.initialize();

    // Listen to audio handler streams and store subscriptions for cleanup
    _subscriptions.add(
      audioHandler.currentSongStream.listen((song) {
        state = state.copyWith(currentSong: song);
        // Update widget when song changes
        _widgetService.updateWidget(
          song: song,
          isPlaying: state.isPlaying,
        );
      }),
    );

    _subscriptions.add(
      audioHandler.playingStream.listen((playing) {
        state = state.copyWith(isPlaying: playing);
        // Update widget when playing state changes
        _widgetService.updatePlayingState(playing);
      }),
    );

    _subscriptions.add(
      audioHandler.positionStream.listen((position) {
        state = state.copyWith(position: position);
      }),
    );

    _subscriptions.add(
      audioHandler.durationStream.listen((duration) {
        if (duration != null) {
          state = state.copyWith(duration: duration);
        }
      }),
    );

    _subscriptions.add(
      audioHandler.loopModeStream.listen((mode) {
        state = state.copyWith(loopMode: mode);
      }),
    );

    _subscriptions.add(
      audioHandler.shuffleModeStream.listen((enabled) {
        state = state.copyWith(shuffleMode: enabled);
      }),
    );

    _subscriptions.add(
      audioHandler.speedStream.listen((speed) {
        state = state.copyWith(speed: speed);
      }),
    );

    // Listen to queue changes
    _subscriptions.add(
      audioHandler.queueStream.listen((queue) {
        state = state.copyWith(queue: queue);
      }),
    );

    // Listen to current index changes
    _subscriptions.add(
      audioHandler.currentIndexStream.listen((index) {
        state = state.copyWith(currentIndex: index);
      }),
    );
  }

  @override
  void dispose() {
    // Cancel all stream subscriptions to prevent memory leaks
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }

  Future<void> playSong(Song song, List<Song> queue) async {
    state = state.copyWith(
      queue: queue,
      currentIndex: queue.indexWhere((s) => s.id == song.id),
    );
    await audioHandler.playSong(song, queue);
  }

  Future<void> play() => audioHandler.play();
  Future<void> pause() => audioHandler.pause();
  Future<void> skipToNext() => audioHandler.skipToNext();
  Future<void> skipToPrevious() => audioHandler.skipToPrevious();
  Future<void> seek(Duration position) => audioHandler.seek(position);

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> toggleShuffle() async {
    await audioHandler.setShuffleModeEnabled(!state.shuffleMode);
  }

  Future<void> cycleRepeatMode() async {
    LoopMode nextMode;
    switch (state.loopMode) {
      case LoopMode.off:
        nextMode = LoopMode.all;
        break;
      case LoopMode.all:
        nextMode = LoopMode.one;
        break;
      case LoopMode.one:
        nextMode = LoopMode.off;
        break;
    }
    await audioHandler.setLoopMode(nextMode);
  }

  Future<void> setSpeed(double speed) => audioHandler.setPlaybackSpeed(speed);

  /// Update a song in the queue (e.g., after tag editing)
  void updateSongInQueue(Song updatedSong) {
    final newQueue = state.queue.map((song) {
      if (song.id == updatedSong.id || song.path == updatedSong.path) {
        return updatedSong;
      }
      return song;
    }).toList();

    // Also update currentSong if it's the one being edited
    Song? newCurrentSong = state.currentSong;
    if (state.currentSong != null &&
        (state.currentSong!.id == updatedSong.id || state.currentSong!.path == updatedSong.path)) {
      newCurrentSong = updatedSong;
    }

    state = state.copyWith(
      queue: newQueue,
      currentSong: newCurrentSong,
    );
  }

  /// Update multiple songs in the queue
  void updateSongsInQueue(List<Song> updatedSongs) {
    final updatedMap = {for (var s in updatedSongs) s.path: s};

    final newQueue = state.queue.map((song) {
      if (song.path != null && updatedMap.containsKey(song.path)) {
        return updatedMap[song.path]!;
      }
      return song;
    }).toList();

    Song? newCurrentSong = state.currentSong;
    if (state.currentSong?.path != null && updatedMap.containsKey(state.currentSong!.path)) {
      newCurrentSong = updatedMap[state.currentSong!.path];
    }

    state = state.copyWith(
      queue: newQueue,
      currentSong: newCurrentSong,
    );
  }
}

// Providers
final playerProvider = StateNotifierProvider<PlayerNotifier, AppPlayerState>((ref) {
  return PlayerNotifier();
});

final currentSongProvider = Provider<Song?>((ref) {
  return ref.watch(playerProvider).currentSong;
});

final isPlayingProvider = Provider<bool>((ref) {
  return ref.watch(playerProvider).isPlaying;
});

final positionProvider = Provider<Duration>((ref) {
  return ref.watch(playerProvider).position;
});

final durationProvider = Provider<Duration>((ref) {
  return ref.watch(playerProvider).duration;
});

final progressProvider = Provider<double>((ref) {
  final position = ref.watch(positionProvider);
  final duration = ref.watch(durationProvider);
  if (duration.inMilliseconds == 0) return 0.0;
  return position.inMilliseconds / duration.inMilliseconds;
});
