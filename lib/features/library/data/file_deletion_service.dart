import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/song.dart';
import 'media_scanner.dart';
import '../../../services/log_service.dart';

/// Progress information for batch deletion
class DeleteProgress {
  final int current;
  final int total;
  final int deleted;
  final int failed;
  final String currentFile;

  DeleteProgress({
    required this.current,
    required this.total,
    required this.deleted,
    required this.failed,
    required this.currentFile,
  });

  double get progress => total > 0 ? current / total : 0;
  bool get isComplete => current >= total;
}

/// Result of a single file deletion
class DeleteResult {
  final Song song;
  final bool success;
  final String? error;

  DeleteResult({
    required this.song,
    required this.success,
    this.error,
  });
}

/// Service for deleting song files from the device
class FileDeletionService {
  final MediaScanner _scanner;

  FileDeletionService(this._scanner);

  /// Delete a single song file
  Future<DeleteResult> deleteSong(Song song) async {
    if (song.path == null) {
      return DeleteResult(
        song: song,
        success: false,
        error: 'No file path',
      );
    }

    try {
      final file = File(song.path!);

      if (!await file.exists()) {
        return DeleteResult(
          song: song,
          success: false,
          error: 'File not found',
        );
      }

      // Delete the file
      await file.delete();

      // Notify MediaStore that the file is gone
      await _scanner.rescanFile(song.path!);

      return DeleteResult(song: song, success: true);
    } catch (e) {
      return DeleteResult(
        song: song,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Delete multiple songs with progress updates
  Stream<DeleteProgress> deleteMultiple(List<Song> songs) async* {
    int deleted = 0;
    int failed = 0;

    for (int i = 0; i < songs.length; i++) {
      final song = songs[i];

      yield DeleteProgress(
        current: i,
        total: songs.length,
        deleted: deleted,
        failed: failed,
        currentFile: song.title,
      );

      final result = await deleteSong(song);

      if (result.success) {
        deleted++;
      } else {
        failed++;
        Log.d('Failed to delete ${song.title}: ${result.error}');
      }
    }

    // Final progress update
    yield DeleteProgress(
      current: songs.length,
      total: songs.length,
      deleted: deleted,
      failed: failed,
      currentFile: '',
    );
  }

  /// Delete multiple songs and return all results
  Future<List<DeleteResult>> deleteSongs(List<Song> songs) async {
    final results = <DeleteResult>[];

    for (final song in songs) {
      final result = await deleteSong(song);
      results.add(result);
    }

    // Invalidate cache after batch deletion
    _scanner.invalidateCache();

    return results;
  }
}

/// Provider for file deletion service
final fileDeletionServiceProvider = Provider((ref) {
  final scanner = ref.read(mediaScannerProvider);
  return FileDeletionService(scanner);
});
