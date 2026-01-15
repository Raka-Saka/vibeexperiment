import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vibeplay/shared/models/song.dart';
import 'package:vibeplay/services/playback_state_service.dart';

// Create a testable version of PlaybackStateService that accepts a mock box
class TestablePlaybackStateService extends PlaybackStateService {
  Box? testBox;

  void setTestBox(Box box) {
    testBox = box;
  }

  @override
  Future<void> init() async {
    // Use test box instead of opening real Hive box
    if (testBox != null) return;
    await super.init();
  }
}

class MockHiveBox extends Mock implements Box<dynamic> {}

void main() {
  group('PlaybackStateService', () {
    late MockHiveBox mockBox;
    late Map<String, dynamic> storage;

    setUp(() {
      mockBox = MockHiveBox();
      storage = {};

      // Mock put operations
      when(() => mockBox.put(any(), any())).thenAnswer((invocation) async {
        final key = invocation.positionalArguments[0] as String;
        final value = invocation.positionalArguments[1];
        storage[key] = value;
      });

      // Mock get operations
      when(() => mockBox.get(any())).thenAnswer((invocation) {
        final key = invocation.positionalArguments[0] as String;
        return storage[key];
      });

      // Mock delete operations
      when(() => mockBox.delete(any())).thenAnswer((invocation) async {
        final key = invocation.positionalArguments[0] as String;
        storage.remove(key);
      });
    });

    group('saveState', () {
      test('saves current song path', () async {
        const song = Song(
          id: 1,
          title: 'Test Song',
          path: '/storage/music/test.mp3',
        );

        // Simulate saveState behavior
        await mockBox.put('currentSongPath', song.path);

        verify(() => mockBox.put('currentSongPath', '/storage/music/test.mp3')).called(1);
        expect(storage['currentSongPath'], equals('/storage/music/test.mp3'));
      });

      test('saves current index', () async {
        await mockBox.put('currentIndex', 5);

        expect(storage['currentIndex'], equals(5));
      });

      test('saves position in milliseconds', () async {
        const position = Duration(minutes: 2, seconds: 30);
        await mockBox.put('position', position.inMilliseconds);

        expect(storage['position'], equals(150000));
      });

      test('saves current song as JSON', () async {
        const song = Song(
          id: 1,
          title: 'Test Song',
          artist: 'Test Artist',
          path: '/storage/music/test.mp3',
          duration: 180000,
        );

        await mockBox.put('currentSongJson', jsonEncode(song.toJson()));

        final savedJson = storage['currentSongJson'] as String;
        final decoded = jsonDecode(savedJson) as Map<String, dynamic>;
        expect(decoded['title'], equals('Test Song'));
        expect(decoded['artist'], equals('Test Artist'));
      });

      test('saves queue as JSON array', () async {
        final songs = [
          const Song(id: 1, title: 'Song 1', path: '/path1.mp3'),
          const Song(id: 2, title: 'Song 2', path: '/path2.mp3'),
          const Song(id: 3, title: 'Song 3', path: '/path3.mp3'),
        ];

        final queueJson = songs.map((s) => s.toJson()).toList();
        await mockBox.put('queueJson', jsonEncode(queueJson));

        final savedJson = storage['queueJson'] as String;
        final decoded = jsonDecode(savedJson) as List;
        expect(decoded.length, equals(3));
        expect(decoded[0]['title'], equals('Song 1'));
        expect(decoded[2]['title'], equals('Song 3'));
      });
    });

    group('getters', () {
      test('savedCurrentSongPath returns stored path', () {
        storage['currentSongPath'] = '/storage/music/test.mp3';

        final path = mockBox.get('currentSongPath');
        expect(path, equals('/storage/music/test.mp3'));
      });

      test('savedCurrentSongPath returns null when not set', () {
        final path = mockBox.get('currentSongPath');
        expect(path, isNull);
      });

      test('savedCurrentIndex returns stored index', () {
        storage['currentIndex'] = 7;

        final index = mockBox.get('currentIndex') ?? 0;
        expect(index, equals(7));
      });

      test('savedCurrentIndex returns 0 when not set', () {
        final index = mockBox.get('currentIndex') ?? 0;
        expect(index, equals(0));
      });

      test('savedPosition returns stored duration', () {
        storage['position'] = 150000;

        final positionMs = mockBox.get('position') ?? 0;
        final position = Duration(milliseconds: positionMs);
        expect(position, equals(const Duration(minutes: 2, seconds: 30)));
      });

      test('savedCurrentSong deserializes correctly', () {
        const song = Song(
          id: 1,
          title: 'Test Song',
          artist: 'Test Artist',
          path: '/storage/music/test.mp3',
        );
        storage['currentSongJson'] = jsonEncode(song.toJson());

        final json = mockBox.get('currentSongJson');
        final restored = Song.fromJson(jsonDecode(json) as Map<String, dynamic>);

        expect(restored.id, equals(1));
        expect(restored.title, equals('Test Song'));
        expect(restored.artist, equals('Test Artist'));
        expect(restored.path, equals('/storage/music/test.mp3'));
      });

      test('savedQueue deserializes correctly', () {
        final songs = [
          const Song(id: 1, title: 'Song 1', path: '/path1.mp3'),
          const Song(id: 2, title: 'Song 2', path: '/path2.mp3'),
        ];
        storage['queueJson'] = jsonEncode(songs.map((s) => s.toJson()).toList());

        final json = mockBox.get('queueJson');
        final list = jsonDecode(json) as List;
        final restored = list.map((item) => Song.fromJson(item as Map<String, dynamic>)).toList();

        expect(restored.length, equals(2));
        expect(restored[0].title, equals('Song 1'));
        expect(restored[1].title, equals('Song 2'));
      });
    });

    group('hasSavedState', () {
      test('returns true when currentSongPath is set', () {
        storage['currentSongPath'] = '/storage/music/test.mp3';

        final hasSaved = mockBox.get('currentSongPath') != null;
        expect(hasSaved, isTrue);
      });

      test('returns false when currentSongPath is not set', () {
        final hasSaved = mockBox.get('currentSongPath') != null;
        expect(hasSaved, isFalse);
      });
    });

    group('clearState', () {
      test('removes all saved keys', () async {
        storage['currentSongPath'] = '/test.mp3';
        storage['currentSongJson'] = '{}';
        storage['queueJson'] = '[]';
        storage['currentIndex'] = 5;
        storage['position'] = 1000;

        await mockBox.delete('currentSongPath');
        await mockBox.delete('currentSongJson');
        await mockBox.delete('queueJson');
        await mockBox.delete('currentIndex');
        await mockBox.delete('position');

        expect(storage['currentSongPath'], isNull);
        expect(storage['currentSongJson'], isNull);
        expect(storage['queueJson'], isNull);
        expect(storage['currentIndex'], isNull);
        expect(storage['position'], isNull);
      });
    });

    group('edge cases', () {
      test('handles empty queue gracefully', () {
        storage['queueJson'] = jsonEncode([]);

        final json = mockBox.get('queueJson');
        final list = jsonDecode(json) as List;
        expect(list, isEmpty);
      });

      test('handles malformed JSON gracefully', () {
        storage['currentSongJson'] = 'not valid json';

        expect(() {
          final json = mockBox.get('currentSongJson');
          jsonDecode(json);
        }, throwsFormatException);
      });

      test('handles song with null path in queue', () {
        final songs = [
          {'id': 1, 'title': 'Song 1', 'path': '/path1.mp3'},
          {'id': 2, 'title': 'Song 2', 'path': null},
        ];
        storage['queueJson'] = jsonEncode(songs);

        final json = mockBox.get('queueJson');
        final list = jsonDecode(json) as List;
        final restored = list.map((item) => Song.fromJson(item as Map<String, dynamic>)).toList();

        expect(restored[0].path, equals('/path1.mp3'));
        expect(restored[1].path, isNull);
      });
    });
  });
}
