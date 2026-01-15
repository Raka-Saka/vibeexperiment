import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'dart:io';

/// Initialize logging for tests (silent logging)
void initLoggingForTests() {
  // This prevents LateInitializationError when services try to log during tests
  // Tests use a no-op logger that doesn't output anything
}

/// Initialize Hive for testing with a temporary directory
Future<void> initHiveForTesting() async {
  final tempDir = Directory.systemTemp.createTempSync('hive_test_');
  Hive.init(tempDir.path);
}

/// Clean up Hive after tests
Future<void> cleanUpHive() async {
  await Hive.deleteFromDisk();
  await Hive.close();
}

/// Mock Box for Hive testing
class MockBox<T> extends Mock implements Box<T> {}

/// Test fixture helper for creating common test data
class TestFixtures {
  static Map<String, dynamic> createSongJson({
    int id = 1,
    String title = 'Test Song',
    String? artist = 'Test Artist',
    String? album = 'Test Album',
    String? path = '/storage/music/test.mp3',
    int duration = 180000,
  }) {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'path': path,
      'duration': duration,
      'albumId': null,
      'artistId': null,
      'trackNumber': null,
      'genre': null,
      'year': null,
      'bitrate': null,
      'fileExtension': 'mp3',
      'size': null,
    };
  }

  static List<Map<String, dynamic>> createSongListJson(int count) {
    return List.generate(count, (i) => createSongJson(
      id: i + 1,
      title: 'Song ${i + 1}',
      path: '/storage/music/song_${i + 1}.mp3',
    ));
  }
}
