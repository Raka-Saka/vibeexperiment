import 'dart:typed_data';
import 'package:equatable/equatable.dart';

class Song extends Equatable {
  final int id;
  final String title;
  final String? artist;
  final String? album;
  final int? albumId;
  final int? artistId;
  final String? path;
  final int duration;
  final int? trackNumber;
  final String? genre;
  final int? year;
  final int? bitrate;
  final String? fileExtension;
  final int? size;
  final Uint8List? artwork;

  const Song({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    this.albumId,
    this.artistId,
    this.path,
    this.duration = 0,
    this.trackNumber,
    this.genre,
    this.year,
    this.bitrate,
    this.fileExtension,
    this.size,
    this.artwork,
  });

  String get durationFormatted {
    final minutes = (duration ~/ 60000);
    final seconds = ((duration % 60000) ~/ 1000);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get artistDisplay => artist ?? 'Unknown Artist';
  String get albumDisplay => album ?? 'Unknown Album';

  Song copyWith({
    int? id,
    String? title,
    String? artist,
    String? album,
    int? albumId,
    int? artistId,
    String? path,
    int? duration,
    int? trackNumber,
    String? genre,
    int? year,
    int? bitrate,
    String? fileExtension,
    int? size,
    Uint8List? artwork,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumId: albumId ?? this.albumId,
      artistId: artistId ?? this.artistId,
      path: path ?? this.path,
      duration: duration ?? this.duration,
      trackNumber: trackNumber ?? this.trackNumber,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      bitrate: bitrate ?? this.bitrate,
      fileExtension: fileExtension ?? this.fileExtension,
      size: size ?? this.size,
      artwork: artwork ?? this.artwork,
    );
  }

  /// Convert to JSON for persistence (e.g., saving playback queue state).
  ///
  /// NOTE: `artwork` is intentionally excluded from serialization because:
  /// 1. Artwork bytes can be large (50KB-500KB per song), making queue
  ///    serialization slow and storage-heavy for large playlists.
  /// 2. Artwork can be re-fetched efficiently using `albumId` when needed.
  /// 3. The artwork provider handles caching separately.
  ///
  /// When restoring from JSON, artwork will be null and should be loaded
  /// on-demand via the artwork provider.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'albumId': albumId,
    'artistId': artistId,
    'path': path,
    'duration': duration,
    'trackNumber': trackNumber,
    'genre': genre,
    'year': year,
    'bitrate': bitrate,
    'fileExtension': fileExtension,
    'size': size,
    // artwork intentionally excluded - see doc comment above
  };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
    id: json['id'] as int,
    title: json['title'] as String,
    artist: json['artist'] as String?,
    album: json['album'] as String?,
    albumId: json['albumId'] as int?,
    artistId: json['artistId'] as int?,
    path: json['path'] as String?,
    duration: json['duration'] as int? ?? 0,
    trackNumber: json['trackNumber'] as int?,
    genre: json['genre'] as String?,
    year: json['year'] as int?,
    bitrate: json['bitrate'] as int?,
    fileExtension: json['fileExtension'] as String?,
    size: json['size'] as int?,
  );

  @override
  List<Object?> get props => [id, title, artist, album, path];
}
