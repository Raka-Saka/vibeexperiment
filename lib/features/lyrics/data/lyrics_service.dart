import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/song.dart';
import '../../../services/log_service.dart';

class LyricLine {
  final Duration timestamp;
  final String text;

  const LyricLine({
    required this.timestamp,
    required this.text,
  });
}

class Lyrics {
  final List<LyricLine> lines;
  final bool isSynced;
  final String? title;
  final String? artist;

  const Lyrics({
    required this.lines,
    this.isSynced = false,
    this.title,
    this.artist,
  });

  static const empty = Lyrics(lines: [], isSynced: false);

  String get plainText => lines.map((l) => l.text).join('\n');

  LyricLine? getCurrentLine(Duration position) {
    if (!isSynced || lines.isEmpty) return null;

    for (int i = lines.length - 1; i >= 0; i--) {
      if (position >= lines[i].timestamp) {
        return lines[i];
      }
    }
    return null;
  }

  int? getCurrentLineIndex(Duration position) {
    if (!isSynced || lines.isEmpty) return null;

    for (int i = lines.length - 1; i >= 0; i--) {
      if (position >= lines[i].timestamp) {
        return i;
      }
    }
    return null;
  }
}

class LyricsService {
  static const _channel = MethodChannel('com.vibeplay/lyrics');

  // Parse LRC format lyrics
  Lyrics parseLRC(String lrcContent) {
    final lines = <LyricLine>[];
    // Pattern for timestamps like [00:00.00] or [00:00.000] or [00:00:00]
    final pattern = RegExp(r'\[(\d{2}):(\d{2})[\.:](\d{2,3})\](.*)');
    // Also support simple [mm:ss] format
    final simplePattern = RegExp(r'\[(\d{2}):(\d{2})\](.*)');

    String? title;
    String? artist;

    for (final line in lrcContent.split('\n')) {
      // Check for metadata tags
      if (line.startsWith('[ti:')) {
        title = line.substring(4, line.length - 1).trim();
        continue;
      }
      if (line.startsWith('[ar:')) {
        artist = line.substring(4, line.length - 1).trim();
        continue;
      }
      // Skip other metadata tags
      if (line.startsWith('[al:') || line.startsWith('[by:') ||
          line.startsWith('[offset:') || line.startsWith('[re:') ||
          line.startsWith('[ve:')) {
        continue;
      }

      // Try full timestamp pattern first
      var match = pattern.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final millisStr = match.group(3)!;
        final millis = millisStr.length == 2
            ? int.parse(millisStr) * 10
            : int.parse(millisStr);
        final text = match.group(4)!.trim();

        if (text.isNotEmpty) {
          lines.add(LyricLine(
            timestamp: Duration(
              minutes: minutes,
              seconds: seconds,
              milliseconds: millis,
            ),
            text: text,
          ));
        }
        continue;
      }

      // Try simple pattern
      match = simplePattern.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final text = match.group(3)!.trim();

        if (text.isNotEmpty) {
          lines.add(LyricLine(
            timestamp: Duration(
              minutes: minutes,
              seconds: seconds,
            ),
            text: text,
          ));
        }
      }
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return Lyrics(
      lines: lines,
      isSynced: lines.isNotEmpty,
      title: title,
      artist: artist,
    );
  }

  // Parse plain text lyrics (unsynchronized)
  Lyrics parsePlainText(String text) {
    final lines = text
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => LyricLine(
              timestamp: Duration.zero,
              text: line.trim(),
            ))
        .toList();

    return Lyrics(
      lines: lines,
      isSynced: false,
    );
  }

  // Extract embedded lyrics from song file using platform channel
  Future<Lyrics?> extractEmbeddedLyrics(Song song) async {
    if (song.path == null) return null;

    try {
      final result = await _channel.invokeMethod<Map>('extractLyrics', {
        'path': song.path,
      });

      if (result != null) {
        final lyricsText = result['lyrics'] as String?;
        final isSynced = result['isSynced'] as bool? ?? false;

        if (lyricsText != null && lyricsText.isNotEmpty) {
          if (isSynced) {
            return parseLRC(lyricsText);
          } else {
            return parsePlainText(lyricsText);
          }
        }
      }
    } catch (e) {
      Log.d('LyricsService: Failed to extract embedded lyrics: $e');
    }

    return null;
  }

  // Search for external LRC file
  Future<Lyrics?> findExternalLRC(Song song) async {
    if (song.path == null) return null;

    try {
      // Look for .lrc file with same name as audio file
      final lrcPath = song.path!.replaceAll(RegExp(r'\.[^.]+$'), '.lrc');
      final lrcFile = File(lrcPath);

      if (await lrcFile.exists()) {
        final content = await lrcFile.readAsString();
        return parseLRC(content);
      }

      // Also try lowercase extension
      final lrcPathLower = song.path!.replaceAll(RegExp(r'\.[^.]+$'), '.LRC');
      final lrcFileLower = File(lrcPathLower);

      if (await lrcFileLower.exists()) {
        final content = await lrcFileLower.readAsString();
        return parseLRC(content);
      }

      // Try looking in a "lyrics" subdirectory
      final directory = File(song.path!).parent;
      final lyricsDir = Directory('${directory.path}/lyrics');
      if (await lyricsDir.exists()) {
        final fileName = song.path!.split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '.lrc');
        final lrcInSubdir = File('${lyricsDir.path}/$fileName');
        if (await lrcInSubdir.exists()) {
          final content = await lrcInSubdir.readAsString();
          return parseLRC(content);
        }
      }
    } catch (e) {
      Log.d('LyricsService: Error reading LRC file: $e');
    }

    return null;
  }

  // Get lyrics for a song
  Future<Lyrics?> getLyrics(Song song) async {
    // Try external LRC file first (more likely to be synced)
    var lyrics = await findExternalLRC(song);
    if (lyrics != null && lyrics.lines.isNotEmpty) {
      return lyrics;
    }

    // Try embedded lyrics
    lyrics = await extractEmbeddedLyrics(song);
    if (lyrics != null && lyrics.lines.isNotEmpty) {
      return lyrics;
    }

    return null;
  }
}

// Providers
final lyricsServiceProvider = Provider<LyricsService>((ref) => LyricsService());

final lyricsProvider = FutureProvider.family<Lyrics?, Song>((ref, song) async {
  final service = ref.read(lyricsServiceProvider);
  return service.getLyrics(song);
});
