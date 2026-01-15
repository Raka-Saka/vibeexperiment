import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/song.dart';
import '../../../services/log_service.dart';

/// Represents a group of duplicate songs with the same file size
class DuplicateGroup {
  final int fileSize;
  final List<Song> songs;

  DuplicateGroup({required this.fileSize, required this.songs});

  /// Total count of duplicate files (all copies)
  int get totalCount => songs.length;

  /// Number of duplicates (excluding the first/original)
  int get duplicateCount => songs.length - 1;

  /// Human-readable file size
  String get formattedSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// Potential space savings if duplicates are removed
  int get potentialSavings => fileSize * duplicateCount;

  String get formattedSavings {
    final savings = potentialSavings;
    if (savings < 1024) {
      return '$savings B';
    } else if (savings < 1024 * 1024) {
      return '${(savings / 1024).toStringAsFixed(1)} KB';
    } else if (savings < 1024 * 1024 * 1024) {
      return '${(savings / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(savings / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}

/// Service for finding duplicate songs based on file size
class DuplicateFinder {
  /// Find duplicate songs based on file size
  /// Returns groups of songs that have the same file size (likely duplicates)
  List<DuplicateGroup> findDuplicates(List<Song> songs) {
    // Group by file size
    final Map<int, List<Song>> sizeGroups = {};

    for (final song in songs) {
      if (song.size != null && song.size! > 0) {
        sizeGroups.putIfAbsent(song.size!, () => []).add(song);
      }
    }

    // Filter to only groups with 2+ songs (actual duplicates)
    // Sort by file size descending (largest duplicates first for max space savings)
    final duplicates = sizeGroups.entries
        .where((e) => e.value.length > 1)
        .map((e) => DuplicateGroup(fileSize: e.key, songs: e.value))
        .toList()
      ..sort((a, b) => b.fileSize.compareTo(a.fileSize));

    return duplicates;
  }

  /// Find duplicates by reading file sizes directly from filesystem
  /// Use this if MediaStore doesn't provide file sizes
  Future<List<DuplicateGroup>> findDuplicatesFromFiles(List<Song> songs) async {
    final Map<int, List<Song>> sizeGroups = {};

    for (final song in songs) {
      if (song.path == null) continue;

      try {
        final file = File(song.path!);
        if (await file.exists()) {
          final size = await file.length();
          if (size > 0) {
            sizeGroups.putIfAbsent(size, () => []).add(song);
          }
        }
      } catch (e) {
        Log.w('Error getting size for ${song.path}: $e');
      }
    }

    // Filter to only groups with 2+ songs (actual duplicates)
    final duplicates = sizeGroups.entries
        .where((e) => e.value.length > 1)
        .map((e) => DuplicateGroup(fileSize: e.key, songs: e.value))
        .toList()
      ..sort((a, b) => b.fileSize.compareTo(a.fileSize));

    return duplicates;
  }

  /// Get total number of duplicate files found
  int getTotalDuplicateCount(List<DuplicateGroup> groups) {
    return groups.fold(0, (sum, group) => sum + group.duplicateCount);
  }

  /// Get total potential space savings
  int getTotalPotentialSavings(List<DuplicateGroup> groups) {
    return groups.fold(0, (sum, group) => sum + group.potentialSavings);
  }

  /// Format bytes to human-readable string
  String formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}

/// Provider for duplicate finder
final duplicateFinderProvider = Provider((ref) => DuplicateFinder());
