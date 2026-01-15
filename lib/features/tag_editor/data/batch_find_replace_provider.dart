import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../shared/models/song.dart';
import '../../library/data/media_scanner.dart';
import 'models/editable_tags.dart';
import 'tag_editor_service.dart';

/// Field that can be searched/replaced
enum SearchField {
  artist('Artist', 'TPE1'),
  album('Album', 'TALB'),
  title('Title', 'TIT2'),
  albumArtist('Album Artist', 'TPE2'),
  genre('Genre', 'TCON'),
  composer('Composer', 'TCOM');

  final String label;
  final String tagKey;
  const SearchField(this.label, this.tagKey);
}

/// A song with its preview of changes
class SongReplacePreview {
  final Song song;
  final String? originalValue;
  final String? newValue;
  final bool willChange;

  const SongReplacePreview({
    required this.song,
    this.originalValue,
    this.newValue,
    required this.willChange,
  });
}

/// State for batch find/replace
class BatchFindReplaceState {
  final List<Song> songs;
  final SearchField searchField;
  final String findText;
  final String replaceText;
  final bool caseSensitive;
  final bool wholeWord;
  final List<SongReplacePreview> previews;
  final bool isSearching;
  final bool isApplying;
  final int appliedCount;
  final int totalToApply;
  final String? error;
  final String? successMessage;

  const BatchFindReplaceState({
    required this.songs,
    this.searchField = SearchField.artist,
    this.findText = '',
    this.replaceText = '',
    this.caseSensitive = false,
    this.wholeWord = false,
    this.previews = const [],
    this.isSearching = false,
    this.isApplying = false,
    this.appliedCount = 0,
    this.totalToApply = 0,
    this.error,
    this.successMessage,
  });

  int get matchCount => previews.where((p) => p.willChange).length;

  BatchFindReplaceState copyWith({
    List<Song>? songs,
    SearchField? searchField,
    String? findText,
    String? replaceText,
    bool? caseSensitive,
    bool? wholeWord,
    List<SongReplacePreview>? previews,
    bool? isSearching,
    bool? isApplying,
    int? appliedCount,
    int? totalToApply,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return BatchFindReplaceState(
      songs: songs ?? this.songs,
      searchField: searchField ?? this.searchField,
      findText: findText ?? this.findText,
      replaceText: replaceText ?? this.replaceText,
      caseSensitive: caseSensitive ?? this.caseSensitive,
      wholeWord: wholeWord ?? this.wholeWord,
      previews: previews ?? this.previews,
      isSearching: isSearching ?? this.isSearching,
      isApplying: isApplying ?? this.isApplying,
      appliedCount: appliedCount ?? this.appliedCount,
      totalToApply: totalToApply ?? this.totalToApply,
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

/// Notifier for batch find/replace
class BatchFindReplaceNotifier extends StateNotifier<BatchFindReplaceState> {
  final TagEditorService _tagService;
  final Ref _ref;

  BatchFindReplaceNotifier(this._tagService, this._ref, List<Song> songs)
      : super(BatchFindReplaceState(songs: songs));

  /// Update search field
  void setSearchField(SearchField field) {
    state = state.copyWith(searchField: field, clearError: true);
    _updatePreviews();
  }

  /// Update find text
  void setFindText(String text) {
    state = state.copyWith(findText: text, clearError: true);
    _updatePreviews();
  }

  /// Update replace text
  void setReplaceText(String text) {
    state = state.copyWith(replaceText: text, clearError: true);
    _updatePreviews();
  }

  /// Toggle case sensitivity
  void toggleCaseSensitive() {
    state = state.copyWith(caseSensitive: !state.caseSensitive, clearError: true);
    _updatePreviews();
  }

  /// Toggle whole word matching
  void toggleWholeWord() {
    state = state.copyWith(wholeWord: !state.wholeWord, clearError: true);
    _updatePreviews();
  }

  /// Get field value from song
  String? _getFieldValue(Song song, SearchField field) {
    switch (field) {
      case SearchField.artist:
        return song.artist;
      case SearchField.album:
        return song.album;
      case SearchField.title:
        return song.title;
      case SearchField.albumArtist:
        return song.artist; // Fallback to artist if albumArtist not in Song model
      case SearchField.genre:
        return song.genre;
      case SearchField.composer:
        return null; // Not in Song model, will be read from file
    }
  }

  /// Apply replacement to a string
  String? _applyReplacement(String? original, String find, String replace, bool caseSensitive, bool wholeWord) {
    if (original == null || original.isEmpty || find.isEmpty) return original;

    String pattern = find;
    if (wholeWord) {
      pattern = '\\b${RegExp.escape(find)}\\b';
    } else {
      pattern = RegExp.escape(find);
    }

    final regex = RegExp(pattern, caseSensitive: caseSensitive);
    if (!regex.hasMatch(original)) return original;

    return original.replaceAll(regex, replace);
  }

  /// Update previews based on current settings
  void _updatePreviews() {
    if (state.findText.isEmpty) {
      state = state.copyWith(previews: []);
      return;
    }

    final previews = <SongReplacePreview>[];

    for (final song in state.songs) {
      final originalValue = _getFieldValue(song, state.searchField);
      final newValue = _applyReplacement(
        originalValue,
        state.findText,
        state.replaceText,
        state.caseSensitive,
        state.wholeWord,
      );

      final willChange = originalValue != newValue && newValue != null;

      previews.add(SongReplacePreview(
        song: song,
        originalValue: originalValue,
        newValue: newValue,
        willChange: willChange,
      ));
    }

    state = state.copyWith(previews: previews);
  }

  /// Check write permission
  Future<bool> _checkWritePermission() async {
    if (!Platform.isAndroid) return true;

    var status = await Permission.manageExternalStorage.status;
    if (status.isGranted) return true;

    status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;

    status = await Permission.storage.status;
    if (status.isGranted) return true;

    status = await Permission.storage.request();
    return status.isGranted;
  }

  /// Apply all replacements
  Future<void> applyReplacements() async {
    final toApply = state.previews.where((p) => p.willChange).toList();
    if (toApply.isEmpty) {
      state = state.copyWith(error: 'No changes to apply');
      return;
    }

    // Check permissions
    final hasPermission = await _checkWritePermission();
    if (!hasPermission) {
      state = state.copyWith(
        error: 'Storage permission required. Please grant "All files access" in Settings.',
      );
      return;
    }

    state = state.copyWith(
      isApplying: true,
      appliedCount: 0,
      totalToApply: toApply.length,
      clearError: true,
    );

    int successCount = 0;
    final errors = <String>[];

    for (int i = 0; i < toApply.length; i++) {
      final preview = toApply[i];
      final song = preview.song;

      if (song.path == null) {
        errors.add('${song.title}: No file path');
        continue;
      }

      try {
        // Read existing tags
        final existingTags = await _tagService.readTags(song.path!);
        if (existingTags == null) {
          errors.add('${song.title}: Could not read tags');
          continue;
        }

        // Apply replacement to the appropriate field
        EditableTags updatedTags;
        switch (state.searchField) {
          case SearchField.artist:
            updatedTags = existingTags.copyWith(artist: preview.newValue);
            break;
          case SearchField.album:
            updatedTags = existingTags.copyWith(album: preview.newValue);
            break;
          case SearchField.title:
            updatedTags = existingTags.copyWith(title: preview.newValue);
            break;
          case SearchField.albumArtist:
            updatedTags = existingTags.copyWith(albumArtist: preview.newValue);
            break;
          case SearchField.genre:
            updatedTags = existingTags.copyWith(genre: preview.newValue);
            break;
          case SearchField.composer:
            updatedTags = existingTags.copyWith(composer: preview.newValue);
            break;
        }

        // Write tags
        final result = await _tagService.writeTags(song.path!, updatedTags);
        if (result.success) {
          successCount++;
          // Rescan this file to update MediaStore
          await _ref.read(mediaScannerProvider).rescanFile(song.path!);
        } else {
          errors.add('${song.title}: ${result.error}');
        }
      } catch (e) {
        errors.add('${song.title}: $e');
      }

      state = state.copyWith(appliedCount: i + 1);
    }

    // Invalidate caches to reflect changes
    _ref.invalidate(songsProvider);
    _ref.invalidate(albumsProvider);
    _ref.invalidate(artistsProvider);

    if (errors.isEmpty) {
      state = state.copyWith(
        isApplying: false,
        successMessage: 'Successfully updated $successCount songs',
        previews: [], // Clear previews after success
        findText: '',
        replaceText: '',
      );
    } else {
      state = state.copyWith(
        isApplying: false,
        error: 'Updated $successCount songs. Errors:\n${errors.take(5).join('\n')}${errors.length > 5 ? '\n...and ${errors.length - 5} more' : ''}',
      );
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Clear success message
  void clearSuccess() {
    state = state.copyWith(clearSuccess: true);
  }

  /// Open app settings
  Future<void> openSettings() async {
    await openAppSettings();
  }
}

/// Provider for batch find/replace
final batchFindReplaceProvider = StateNotifierProvider.family<
    BatchFindReplaceNotifier, BatchFindReplaceState, List<Song>>((ref, songs) {
  return BatchFindReplaceNotifier(
    ref.read(tagEditorServiceProvider),
    ref,
    songs,
  );
});
