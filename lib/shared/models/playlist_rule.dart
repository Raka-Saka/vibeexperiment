import 'package:equatable/equatable.dart';
import 'song.dart';

/// Types of rules that can be applied to filter songs
enum RuleField {
  artist,
  album,
  genre,
  year,
  playCount,
  duration,
  title,
}

/// Comparison operators for rules
enum RuleOperator {
  equals,
  notEquals,
  contains,
  notContains,
  greaterThan,
  lessThan,
  between,
}

/// A single rule that filters songs
class PlaylistRule extends Equatable {
  final RuleField field;
  final RuleOperator operator;
  final String value;
  final String? value2; // For 'between' operator

  const PlaylistRule({
    required this.field,
    required this.operator,
    required this.value,
    this.value2,
  });

  /// Check if a song matches this rule
  bool matches(Song song, {int? playCount}) {
    final fieldValue = _getFieldValue(song, playCount);

    switch (operator) {
      case RuleOperator.equals:
        return _normalizeString(fieldValue) == _normalizeString(value);
      case RuleOperator.notEquals:
        return _normalizeString(fieldValue) != _normalizeString(value);
      case RuleOperator.contains:
        return _normalizeString(fieldValue).contains(_normalizeString(value));
      case RuleOperator.notContains:
        return !_normalizeString(fieldValue).contains(_normalizeString(value));
      case RuleOperator.greaterThan:
        return _compareNumeric(fieldValue, value) > 0;
      case RuleOperator.lessThan:
        return _compareNumeric(fieldValue, value) < 0;
      case RuleOperator.between:
        if (value2 == null) return false;
        final numVal = _parseNumber(fieldValue);
        final min = _parseNumber(value);
        final max = _parseNumber(value2!);
        return numVal >= min && numVal <= max;
    }
  }

  String _getFieldValue(Song song, int? playCount) {
    switch (field) {
      case RuleField.artist:
        return song.artist ?? '';
      case RuleField.album:
        return song.album ?? '';
      case RuleField.genre:
        return song.genre ?? '';
      case RuleField.year:
        return (song.year ?? 0).toString();
      case RuleField.playCount:
        return (playCount ?? 0).toString();
      case RuleField.duration:
        return (song.duration ~/ 1000).toString(); // Convert to seconds
      case RuleField.title:
        return song.title;
    }
  }

  String _normalizeString(String s) => s.toLowerCase().trim();

  int _compareNumeric(String a, String b) {
    final numA = _parseNumber(a);
    final numB = _parseNumber(b);
    return numA.compareTo(numB);
  }

  double _parseNumber(String s) {
    return double.tryParse(s.trim()) ?? 0;
  }

  /// Get display name for the field
  static String fieldDisplayName(RuleField field) {
    switch (field) {
      case RuleField.artist:
        return 'Artist';
      case RuleField.album:
        return 'Album';
      case RuleField.genre:
        return 'Genre';
      case RuleField.year:
        return 'Year';
      case RuleField.playCount:
        return 'Play Count';
      case RuleField.duration:
        return 'Duration (sec)';
      case RuleField.title:
        return 'Title';
    }
  }

  /// Get display name for the operator
  static String operatorDisplayName(RuleOperator op) {
    switch (op) {
      case RuleOperator.equals:
        return 'equals';
      case RuleOperator.notEquals:
        return 'does not equal';
      case RuleOperator.contains:
        return 'contains';
      case RuleOperator.notContains:
        return 'does not contain';
      case RuleOperator.greaterThan:
        return 'greater than';
      case RuleOperator.lessThan:
        return 'less than';
      case RuleOperator.between:
        return 'between';
    }
  }

  /// Get valid operators for a field
  static List<RuleOperator> operatorsForField(RuleField field) {
    switch (field) {
      case RuleField.artist:
      case RuleField.album:
      case RuleField.genre:
      case RuleField.title:
        return [
          RuleOperator.equals,
          RuleOperator.notEquals,
          RuleOperator.contains,
          RuleOperator.notContains,
        ];
      case RuleField.year:
      case RuleField.playCount:
      case RuleField.duration:
        return [
          RuleOperator.equals,
          RuleOperator.notEquals,
          RuleOperator.greaterThan,
          RuleOperator.lessThan,
          RuleOperator.between,
        ];
    }
  }

  Map<String, dynamic> toJson() => {
    'field': field.index,
    'operator': operator.index,
    'value': value,
    'value2': value2,
  };

  factory PlaylistRule.fromJson(Map<String, dynamic> json) {
    return PlaylistRule(
      field: RuleField.values[json['field'] as int],
      operator: RuleOperator.values[json['operator'] as int],
      value: json['value'] as String,
      value2: json['value2'] as String?,
    );
  }

  @override
  List<Object?> get props => [field, operator, value, value2];
}

/// Logic for combining multiple rules
enum RuleLogic {
  and, // All rules must match
  or,  // Any rule must match
}

/// A rule-based smart playlist definition
class RuleBasedPlaylist extends Equatable {
  final String id;
  final String name;
  final List<PlaylistRule> rules;
  final RuleLogic logic;
  final int? maxSongs; // Limit number of songs (null = unlimited)
  final DateTime createdAt;
  final DateTime updatedAt;

  const RuleBasedPlaylist({
    required this.id,
    required this.name,
    required this.rules,
    this.logic = RuleLogic.and,
    this.maxSongs,
    required this.createdAt,
    required this.updatedAt,
  });

  RuleBasedPlaylist copyWith({
    String? id,
    String? name,
    List<PlaylistRule>? rules,
    RuleLogic? logic,
    int? maxSongs,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RuleBasedPlaylist(
      id: id ?? this.id,
      name: name ?? this.name,
      rules: rules ?? this.rules,
      logic: logic ?? this.logic,
      maxSongs: maxSongs ?? this.maxSongs,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'rules': rules.map((r) => r.toJson()).toList(),
    'logic': logic.index,
    'maxSongs': maxSongs,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory RuleBasedPlaylist.fromJson(Map<String, dynamic> json) {
    return RuleBasedPlaylist(
      id: json['id'] as String,
      name: json['name'] as String,
      rules: (json['rules'] as List)
          .map((r) => PlaylistRule.fromJson(Map<String, dynamic>.from(r)))
          .toList(),
      logic: RuleLogic.values[json['logic'] as int? ?? 0],
      maxSongs: json['maxSongs'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  List<Object?> get props => [id, name, rules, logic, maxSongs];
}
