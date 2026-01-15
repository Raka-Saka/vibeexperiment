import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class Playlist extends Equatable {
  final String id;
  final String name;
  final List<int> songIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? description;
  final bool isFavorites;

  Playlist({
    String? id,
    required this.name,
    List<int>? songIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.description,
    this.isFavorites = false,
  })  : id = id ?? const Uuid().v4(),
        songIds = songIds ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get songCount => songIds.length;

  Playlist copyWith({
    String? id,
    String? name,
    List<int>? songIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? description,
    bool? isFavorites,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      songIds: songIds ?? List.from(this.songIds),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      description: description ?? this.description,
      isFavorites: isFavorites ?? this.isFavorites,
    );
  }

  Playlist addSong(int songId) {
    if (songIds.contains(songId)) return this;
    return copyWith(songIds: [...songIds, songId]);
  }

  Playlist removeSong(int songId) {
    return copyWith(songIds: songIds.where((id) => id != songId).toList());
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'songIds': songIds,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'description': description,
    'isFavorites': isFavorites,
  };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
    id: json['id'] as String,
    name: json['name'] as String,
    songIds: (json['songIds'] as List).cast<int>(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    description: json['description'] as String?,
    isFavorites: json['isFavorites'] as bool? ?? false,
  );

  @override
  List<Object?> get props => [id, name, songIds];
}
