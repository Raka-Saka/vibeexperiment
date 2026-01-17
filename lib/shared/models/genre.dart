import 'package:equatable/equatable.dart';

/// Represents a music genre with aggregated information
class Genre extends Equatable {
  final String name;
  final int songCount;
  final List<int> songIds;

  const Genre({
    required this.name,
    required this.songCount,
    required this.songIds,
  });

  /// Display name - capitalize first letter of each word
  String get displayName {
    if (name.isEmpty) return 'Unknown';
    return name.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  @override
  List<Object?> get props => [name, songCount];
}
