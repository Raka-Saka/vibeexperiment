import 'package:equatable/equatable.dart';

class Artist extends Equatable {
  final int id;
  final String name;
  final int songCount;
  final int albumCount;

  const Artist({
    required this.id,
    required this.name,
    this.songCount = 0,
    this.albumCount = 0,
  });

  Artist copyWith({
    int? id,
    String? name,
    int? songCount,
    int? albumCount,
  }) {
    return Artist(
      id: id ?? this.id,
      name: name ?? this.name,
      songCount: songCount ?? this.songCount,
      albumCount: albumCount ?? this.albumCount,
    );
  }

  @override
  List<Object?> get props => [id, name];
}
