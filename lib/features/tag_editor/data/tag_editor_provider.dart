import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../shared/models/song.dart';
import '../../library/data/media_scanner.dart';
import '../../player/data/player_provider.dart';
import 'models/editable_tags.dart';
import 'tag_editor_service.dart';

/// State for single song editing
class TagEditorState {
  final Song song;
  final EditableTags originalTags;
  final EditableTags currentTags;
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final String? successMessage;

  const TagEditorState({
    required this.song,
    required this.originalTags,
    required this.currentTags,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.successMessage,
  });

  bool get hasChanges => originalTags != currentTags;

  TagEditorState copyWith({
    Song? song,
    EditableTags? originalTags,
    EditableTags? currentTags,
    bool? isLoading,
    bool? isSaving,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return TagEditorState(
      song: song ?? this.song,
      originalTags: originalTags ?? this.originalTags,
      currentTags: currentTags ?? this.currentTags,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

/// Notifier for single song tag editing
class TagEditorNotifier extends StateNotifier<TagEditorState?> {
  final TagEditorService _tagService;
  final Ref _ref;

  TagEditorNotifier(this._tagService, this._ref) : super(null);

  /// Initialize editing for a song
  Future<void> startEditing(Song song) async {
    state = TagEditorState(
      song: song,
      originalTags: EditableTags.fromSong(song),
      currentTags: EditableTags.fromSong(song),
      isLoading: true,
    );

    // Check if format is supported
    if (!_tagService.isFormatSupported(song.path)) {
      state = state!.copyWith(
        isLoading: false,
        error: 'This file format is not supported for tag editing',
      );
      return;
    }

    // Load full tags from file
    if (song.path != null) {
      final tags = await _tagService.readTags(song.path!);
      if (tags != null) {
        state = state!.copyWith(
          originalTags: tags,
          currentTags: tags,
          isLoading: false,
        );
        return;
      }
    }

    state = state!.copyWith(isLoading: false);
  }

  /// Update title
  void updateTitle(String value) {
    if (state == null) return;
    state = state!.copyWith(
      currentTags: state!.currentTags.copyWith(title: value.isEmpty ? null : value),
      clearError: true,
    );
  }

  /// Update artist
  void updateArtist(String value) {
    if (state == null) return;
    state = state!.copyWith(
      currentTags: state!.currentTags.copyWith(artist: value.isEmpty ? null : value),
      clearError: true,
    );
  }

  /// Update album
  void updateAlbum(String value) {
    if (state == null) return;
    state = state!.copyWith(
      currentTags: state!.currentTags.copyWith(album: value.isEmpty ? null : value),
      clearError: true,
    );
  }

  /// Update album artist
  void updateAlbumArtist(String value) {
    if (state == null) return;
    state = state!.copyWith(
      currentTags: state!.currentTags.copyWith(albumArtist: value.isEmpty ? null : value),
      clearError: true,
    );
  }

  /// Update genre
  void updateGenre(String value) {
    if (state == null) return;
    state = state!.copyWith(
      currentTags: state!.currentTags.copyWith(genre: value.isEmpty ? null : value),
      clearError: true,
    );
  }

  /// Update year
  void updateYear(String value) {
    if (state == null) return;
    final year = int.tryParse(value);
    state = state!.copyWith(
      currentTags: state!.currentTags.copyWith(
        year: year,
        clearYear: value.isEmpty,
      ),
      clearError: true,
    );
  }

  /// Update track number
  void updateTrackNumber(String value) {
    if (state == null) return;
    final track = int.tryParse(value);
    state = state!.copyWith(
      currentTags: state!.currentTags.copyWith(
        trackNumber: track,
        clearTrackNumber: value.isEmpty,
      ),
      clearError: true,
    );
  }

  /// Update total tracks
  void updateTotalTracks(String value) {
    if (state == null) return;
    final total = int.tryParse(value);
    state = state!.copyWith(
      currentTags: state!.currentTags.copyWith(
        totalTracks: total,
        clearTotalTracks: value.isEmpty,
      ),
      clearError: true,
    );
  }

  /// Update disc number
  void updateDiscNumber(String value) {
    if (state == null) return;
    final disc = int.tryParse(value);
    state = state!.copyWith(
      currentTags: state!.currentTags.copyWith(
        discNumber: disc,
        clearDiscNumber: value.isEmpty,
      ),
      clearError: true,
    );
  }

  /// Update total discs
  void updateTotalDiscs(String value) {
    if (state == null) return;
    final total = int.tryParse(value);
    state = state!.copyWith(
      currentTags: state!.currentTags.copyWith(
        totalDiscs: total,
        clearTotalDiscs: value.isEmpty,
      ),
      clearError: true,
    );
  }

  /// Update composer
  void updateComposer(String value) {
    if (state == null) return;
    state = state!.copyWith(
      currentTags: state!.currentTags.copyWith(
        composer: value.isEmpty ? null : value,
        clearComposer: value.isEmpty,
      ),
      clearError: true,
    );
  }

  /// Update BPM
  void updateBpm(String value) {
    if (state == null) return;
    final bpm = int.tryParse(value);
    state = state!.copyWith(
      currentTags: state!.currentTags.copyWith(
        bpm: bpm,
        clearBpm: value.isEmpty,
      ),
      clearError: true,
    );
  }

  /// Update comment
  void updateComment(String value) {
    if (state == null) return;
    state = state!.copyWith(
      currentTags: state!.currentTags.copyWith(
        comment: value.isEmpty ? null : value,
        clearComment: value.isEmpty,
      ),
      clearError: true,
    );
  }

  /// Update lyrics
  void updateLyrics(String value) {
    if (state == null) return;
    state = state!.copyWith(
      currentTags: state!.currentTags.copyWith(
        lyrics: value.isEmpty ? null : value,
        clearLyrics: value.isEmpty,
      ),
      clearError: true,
    );
  }

  /// Update artwork from bytes
  void updateArtwork(Uint8List? bytes, {String mimeType = 'image/jpeg'}) {
    if (state == null) return;
    state = state!.copyWith(
      currentTags: state!.currentTags.copyWith(
        artwork: bytes,
        artworkMimeType: mimeType,
        clearArtwork: bytes == null,
      ),
      clearError: true,
    );
  }

  /// Pick artwork from local file
  Future<void> pickArtworkFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Uint8List? bytes;

        if (file.bytes != null) {
          bytes = file.bytes;
        } else if (file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }

        if (bytes != null) {
          final mimeType = _getMimeType(file.extension ?? 'jpg');
          updateArtwork(bytes, mimeType: mimeType);
        }
      }
    } catch (e) {
      state = state?.copyWith(error: 'Failed to load image: $e');
    }
  }

  /// Remove artwork
  void removeArtwork() {
    updateArtwork(null);
  }

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Check and request storage write permissions
  Future<bool> _checkWritePermission() async {
    // Check if we're on Android
    if (!Platform.isAndroid) return true;

    // First check if we have manage external storage permission (Android 11+)
    var status = await Permission.manageExternalStorage.status;
    if (status.isGranted) return true;

    // Try requesting it
    status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;

    // If not granted, check storage permission (Android 10 and below)
    status = await Permission.storage.status;
    if (status.isGranted) return true;

    status = await Permission.storage.request();
    return status.isGranted;
  }

  /// Save changes to file
  Future<bool> saveChanges() async {
    if (state == null || state!.song.path == null) return false;
    if (!state!.hasChanges) return true;

    state = state!.copyWith(isSaving: true, clearError: true);

    // Check permissions first
    final hasPermission = await _checkWritePermission();
    if (!hasPermission) {
      state = state!.copyWith(
        isSaving: false,
        error: 'Storage permission required. Please grant "All files access" in Settings > Apps > VibePlay > Permissions',
      );
      return false;
    }

    final result = await _tagService.writeTags(
      state!.song.path!,
      state!.currentTags,
    );

    if (result.success) {
      // Create updated Song object with new metadata for immediate UI update
      final updatedSong = state!.song.copyWith(
        title: state!.currentTags.title ?? state!.song.title,
        artist: state!.currentTags.artist,
        album: state!.currentTags.album,
        genre: state!.currentTags.genre,
        year: state!.currentTags.year,
        trackNumber: state!.currentTags.trackNumber,
      );

      // Immediately update the player queue so the now playing screen shows new info
      _ref.read(playerProvider.notifier).updateSongInQueue(updatedSong);

      // Rescan the file to update MediaStore with new metadata
      final scanner = _ref.read(mediaScannerProvider);
      await scanner.rescanFile(state!.song.path!);

      // Invalidate caches to reflect changes
      _ref.invalidate(songsProvider);
      _ref.invalidate(albumsProvider);
      _ref.invalidate(artistsProvider);

      state = state!.copyWith(
        originalTags: state!.currentTags,
        isSaving: false,
        successMessage: 'Tags saved successfully',
      );
      return true;
    } else {
      state = state!.copyWith(
        isSaving: false,
        error: result.error ?? 'Failed to save tags',
      );
      return false;
    }
  }

  /// Reset to original tags
  void resetChanges() {
    if (state == null) return;
    state = state!.copyWith(
      currentTags: state!.originalTags,
      clearError: true,
    );
  }

  /// Clear error message
  void clearError() {
    if (state == null) return;
    state = state!.copyWith(clearError: true);
  }

  /// Clear success message
  void clearSuccess() {
    if (state == null) return;
    state = state!.copyWith(clearSuccess: true);
  }

  /// Open app settings for permission management
  Future<void> openSettings() async {
    await openAppSettings();
  }

  /// Remove URL frames from the current song
  Future<bool> removeUrls() async {
    if (state == null || state!.song.path == null) return false;

    state = state!.copyWith(isSaving: true, clearError: true);

    final hasPermission = await _checkWritePermission();
    if (!hasPermission) {
      state = state!.copyWith(
        isSaving: false,
        error: 'Storage permission required',
      );
      return false;
    }

    final result = await _tagService.removeUrlFrames(state!.song.path!);

    if (result.success) {
      // Rescan to update MediaStore
      await _ref.read(mediaScannerProvider).rescanFile(state!.song.path!);
      _ref.invalidate(songsProvider);

      state = state!.copyWith(
        isSaving: false,
        successMessage: result.error ?? 'URLs removed successfully',
      );
      return true;
    } else {
      state = state!.copyWith(
        isSaving: false,
        error: result.error ?? 'Failed to remove URLs',
      );
      return false;
    }
  }

  /// Stop editing
  void stopEditing() {
    state = null;
  }
}

/// Provider for tag editing
final tagEditorProvider =
    StateNotifierProvider<TagEditorNotifier, TagEditorState?>((ref) {
  return TagEditorNotifier(
    ref.read(tagEditorServiceProvider),
    ref,
  );
});
