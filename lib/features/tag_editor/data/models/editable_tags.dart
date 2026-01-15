import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import '../../../../shared/models/song.dart';

/// Represents editable metadata tags for an audio file
class EditableTags extends Equatable {
  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final String? genre;
  final int? year;
  final int? trackNumber;
  final int? totalTracks;
  final int? discNumber;
  final int? totalDiscs;
  final String? composer;
  final int? bpm;
  final String? comment;
  final String? lyrics;
  final Uint8List? artwork;
  final String? artworkMimeType;

  const EditableTags({
    this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.genre,
    this.year,
    this.trackNumber,
    this.totalTracks,
    this.discNumber,
    this.totalDiscs,
    this.composer,
    this.bpm,
    this.comment,
    this.lyrics,
    this.artwork,
    this.artworkMimeType,
  });

  /// Create EditableTags from existing Song model
  factory EditableTags.fromSong(Song song) {
    return EditableTags(
      title: song.title,
      artist: song.artist,
      album: song.album,
      genre: song.genre,
      year: song.year,
      trackNumber: song.trackNumber,
      artwork: song.artwork,
    );
  }

  /// Check if any field has a value
  bool get hasAnyValue =>
      title != null ||
      artist != null ||
      album != null ||
      albumArtist != null ||
      genre != null ||
      year != null ||
      trackNumber != null ||
      artwork != null;

  /// For batch editing: find fields that are identical across all songs
  static EditableTags findCommonTags(List<EditableTags> tagsList) {
    if (tagsList.isEmpty) return const EditableTags();
    if (tagsList.length == 1) return tagsList.first;

    // Find fields that are identical across all songs
    String? commonArtist = tagsList.first.artist;
    String? commonAlbum = tagsList.first.album;
    String? commonAlbumArtist = tagsList.first.albumArtist;
    String? commonGenre = tagsList.first.genre;
    int? commonYear = tagsList.first.year;
    int? commonDiscNumber = tagsList.first.discNumber;
    int? commonTotalDiscs = tagsList.first.totalDiscs;
    String? commonComposer = tagsList.first.composer;

    for (final tags in tagsList.skip(1)) {
      if (commonArtist != tags.artist) commonArtist = null;
      if (commonAlbum != tags.album) commonAlbum = null;
      if (commonAlbumArtist != tags.albumArtist) commonAlbumArtist = null;
      if (commonGenre != tags.genre) commonGenre = null;
      if (commonYear != tags.year) commonYear = null;
      if (commonDiscNumber != tags.discNumber) commonDiscNumber = null;
      if (commonTotalDiscs != tags.totalDiscs) commonTotalDiscs = null;
      if (commonComposer != tags.composer) commonComposer = null;
    }

    return EditableTags(
      artist: commonArtist,
      album: commonAlbum,
      albumArtist: commonAlbumArtist,
      genre: commonGenre,
      year: commonYear,
      discNumber: commonDiscNumber,
      totalDiscs: commonTotalDiscs,
      composer: commonComposer,
    );
  }

  EditableTags copyWith({
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    String? genre,
    int? year,
    int? trackNumber,
    int? totalTracks,
    int? discNumber,
    int? totalDiscs,
    String? composer,
    int? bpm,
    String? comment,
    String? lyrics,
    Uint8List? artwork,
    String? artworkMimeType,
    bool clearTitle = false,
    bool clearArtist = false,
    bool clearAlbum = false,
    bool clearAlbumArtist = false,
    bool clearGenre = false,
    bool clearYear = false,
    bool clearTrackNumber = false,
    bool clearTotalTracks = false,
    bool clearDiscNumber = false,
    bool clearTotalDiscs = false,
    bool clearComposer = false,
    bool clearBpm = false,
    bool clearComment = false,
    bool clearLyrics = false,
    bool clearArtwork = false,
  }) {
    return EditableTags(
      title: clearTitle ? null : (title ?? this.title),
      artist: clearArtist ? null : (artist ?? this.artist),
      album: clearAlbum ? null : (album ?? this.album),
      albumArtist: clearAlbumArtist ? null : (albumArtist ?? this.albumArtist),
      genre: clearGenre ? null : (genre ?? this.genre),
      year: clearYear ? null : (year ?? this.year),
      trackNumber: clearTrackNumber ? null : (trackNumber ?? this.trackNumber),
      totalTracks: clearTotalTracks ? null : (totalTracks ?? this.totalTracks),
      discNumber: clearDiscNumber ? null : (discNumber ?? this.discNumber),
      totalDiscs: clearTotalDiscs ? null : (totalDiscs ?? this.totalDiscs),
      composer: clearComposer ? null : (composer ?? this.composer),
      bpm: clearBpm ? null : (bpm ?? this.bpm),
      comment: clearComment ? null : (comment ?? this.comment),
      lyrics: clearLyrics ? null : (lyrics ?? this.lyrics),
      artwork: clearArtwork ? null : (artwork ?? this.artwork),
      artworkMimeType: clearArtwork ? null : (artworkMimeType ?? this.artworkMimeType),
    );
  }

  @override
  List<Object?> get props => [
        title,
        artist,
        album,
        albumArtist,
        genre,
        year,
        trackNumber,
        totalTracks,
        discNumber,
        totalDiscs,
        composer,
        bpm,
        comment,
        lyrics,
        artwork,
        artworkMimeType,
      ];
}

/// Result of a tag write operation
class TagWriteResult {
  final bool success;
  final String? error;
  final String filePath;

  const TagWriteResult({
    required this.success,
    this.error,
    required this.filePath,
  });
}
