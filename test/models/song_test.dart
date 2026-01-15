import 'package:flutter_test/flutter_test.dart';
import 'package:vibeplay/shared/models/song.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('Song', () {
    group('constructor', () {
      test('creates song with required fields', () {
        const song = Song(id: 1, title: 'Test Song');

        expect(song.id, equals(1));
        expect(song.title, equals('Test Song'));
        expect(song.artist, isNull);
        expect(song.album, isNull);
        expect(song.duration, equals(0));
      });

      test('creates song with all fields', () {
        const song = Song(
          id: 1,
          title: 'Test Song',
          artist: 'Test Artist',
          album: 'Test Album',
          albumId: 100,
          artistId: 200,
          path: '/storage/music/test.mp3',
          duration: 180000,
          trackNumber: 5,
          genre: 'Rock',
          year: 2024,
          bitrate: 320,
          fileExtension: 'mp3',
          size: 5000000,
        );

        expect(song.id, equals(1));
        expect(song.title, equals('Test Song'));
        expect(song.artist, equals('Test Artist'));
        expect(song.album, equals('Test Album'));
        expect(song.albumId, equals(100));
        expect(song.artistId, equals(200));
        expect(song.path, equals('/storage/music/test.mp3'));
        expect(song.duration, equals(180000));
        expect(song.trackNumber, equals(5));
        expect(song.genre, equals('Rock'));
        expect(song.year, equals(2024));
        expect(song.bitrate, equals(320));
        expect(song.fileExtension, equals('mp3'));
        expect(song.size, equals(5000000));
      });
    });

    group('durationFormatted', () {
      test('formats duration correctly for minutes and seconds', () {
        const song = Song(id: 1, title: 'Test', duration: 180000); // 3:00
        expect(song.durationFormatted, equals('3:00'));
      });

      test('formats duration with padded seconds', () {
        const song = Song(id: 1, title: 'Test', duration: 185000); // 3:05
        expect(song.durationFormatted, equals('3:05'));
      });

      test('formats zero duration', () {
        const song = Song(id: 1, title: 'Test', duration: 0);
        expect(song.durationFormatted, equals('0:00'));
      });

      test('formats long duration correctly', () {
        const song = Song(id: 1, title: 'Test', duration: 3661000); // 61:01
        expect(song.durationFormatted, equals('61:01'));
      });
    });

    group('display getters', () {
      test('artistDisplay returns artist when present', () {
        const song = Song(id: 1, title: 'Test', artist: 'My Artist');
        expect(song.artistDisplay, equals('My Artist'));
      });

      test('artistDisplay returns fallback when artist is null', () {
        const song = Song(id: 1, title: 'Test');
        expect(song.artistDisplay, equals('Unknown Artist'));
      });

      test('albumDisplay returns album when present', () {
        const song = Song(id: 1, title: 'Test', album: 'My Album');
        expect(song.albumDisplay, equals('My Album'));
      });

      test('albumDisplay returns fallback when album is null', () {
        const song = Song(id: 1, title: 'Test');
        expect(song.albumDisplay, equals('Unknown Album'));
      });
    });

    group('copyWith', () {
      test('copies with new title', () {
        const original = Song(id: 1, title: 'Original', artist: 'Artist');
        final copied = original.copyWith(title: 'New Title');

        expect(copied.id, equals(1));
        expect(copied.title, equals('New Title'));
        expect(copied.artist, equals('Artist'));
      });

      test('copies with multiple new fields', () {
        const original = Song(id: 1, title: 'Original');
        final copied = original.copyWith(
          title: 'New Title',
          artist: 'New Artist',
          duration: 200000,
        );

        expect(copied.title, equals('New Title'));
        expect(copied.artist, equals('New Artist'));
        expect(copied.duration, equals(200000));
      });

      test('preserves all fields when none specified', () {
        const original = Song(
          id: 1,
          title: 'Test',
          artist: 'Artist',
          album: 'Album',
          duration: 180000,
        );
        final copied = original.copyWith();

        expect(copied.id, equals(original.id));
        expect(copied.title, equals(original.title));
        expect(copied.artist, equals(original.artist));
        expect(copied.album, equals(original.album));
        expect(copied.duration, equals(original.duration));
      });
    });

    group('JSON serialization', () {
      test('toJson creates correct map', () {
        const song = Song(
          id: 1,
          title: 'Test Song',
          artist: 'Test Artist',
          album: 'Test Album',
          path: '/storage/music/test.mp3',
          duration: 180000,
        );

        final json = song.toJson();

        expect(json['id'], equals(1));
        expect(json['title'], equals('Test Song'));
        expect(json['artist'], equals('Test Artist'));
        expect(json['album'], equals('Test Album'));
        expect(json['path'], equals('/storage/music/test.mp3'));
        expect(json['duration'], equals(180000));
      });

      test('fromJson creates correct song', () {
        final json = TestFixtures.createSongJson(
          id: 42,
          title: 'JSON Song',
          artist: 'JSON Artist',
        );

        final song = Song.fromJson(json);

        expect(song.id, equals(42));
        expect(song.title, equals('JSON Song'));
        expect(song.artist, equals('JSON Artist'));
      });

      test('roundtrip serialization preserves data', () {
        const original = Song(
          id: 1,
          title: 'Test Song',
          artist: 'Test Artist',
          album: 'Test Album',
          path: '/storage/music/test.mp3',
          duration: 180000,
          genre: 'Rock',
          year: 2024,
        );

        final json = original.toJson();
        final restored = Song.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.title, equals(original.title));
        expect(restored.artist, equals(original.artist));
        expect(restored.album, equals(original.album));
        expect(restored.path, equals(original.path));
        expect(restored.duration, equals(original.duration));
        expect(restored.genre, equals(original.genre));
        expect(restored.year, equals(original.year));
      });

      test('fromJson handles null duration gracefully', () {
        final json = {
          'id': 1,
          'title': 'Test',
          'duration': null,
        };

        final song = Song.fromJson(json);
        expect(song.duration, equals(0));
      });
    });

    group('Equatable', () {
      test('equal songs have same props', () {
        const song1 = Song(
          id: 1,
          title: 'Test',
          artist: 'Artist',
          album: 'Album',
          path: '/test.mp3',
        );
        const song2 = Song(
          id: 1,
          title: 'Test',
          artist: 'Artist',
          album: 'Album',
          path: '/test.mp3',
        );

        expect(song1, equals(song2));
        expect(song1.hashCode, equals(song2.hashCode));
      });

      test('different songs are not equal', () {
        const song1 = Song(id: 1, title: 'Test 1');
        const song2 = Song(id: 2, title: 'Test 2');

        expect(song1, isNot(equals(song2)));
      });

      test('songs with different paths are not equal', () {
        const song1 = Song(id: 1, title: 'Test', path: '/path1.mp3');
        const song2 = Song(id: 1, title: 'Test', path: '/path2.mp3');

        expect(song1, isNot(equals(song2)));
      });
    });
  });
}
