import 'dart:typed_data';
import 'package:equatable/equatable.dart';

class Album extends Equatable {
  final int id;
  final String name;
  final String? artist;
  final int? artistId;
  final int songCount;
  final int? year;
  final Uint8List? artwork;

  const Album({
    required this.id,
    required this.name,
    this.artist,
    this.artistId,
    this.songCount = 0,
    this.year,
    this.artwork,
  });

  String get artistDisplay => artist ?? 'Unknown Artist';

  Album copyWith({
    int? id,
    String? name,
    String? artist,
    int? artistId,
    int? songCount,
    int? year,
    Uint8List? artwork,
  }) {
    return Album(
      id: id ?? this.id,
      name: name ?? this.name,
      artist: artist ?? this.artist,
      artistId: artistId ?? this.artistId,
      songCount: songCount ?? this.songCount,
      year: year ?? this.year,
      artwork: artwork ?? this.artwork,
    );
  }

  @override
  List<Object?> get props => [id, name, artist];
}
