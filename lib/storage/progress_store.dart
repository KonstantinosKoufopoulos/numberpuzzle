import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Player progress: best stars per level, seen intro cards, booster stock.
class Progress {
  Progress({Map<int, int>? stars, Set<String>? seenIntros, Map<String, int>? boosters})
      : stars = stars ?? {},
        seenIntros = seenIntros ?? {},
        boosters = boosters ?? {};

  final Map<int, int> stars;
  final Set<String> seenIntros;
  final Map<String, int> boosters;

  int get highestUnlocked => stars.isEmpty ? 1 : stars.keys.reduce((a, b) => a > b ? a : b) + 1;

  Map<String, dynamic> toJson() => {
        'v': 1,
        'stars': stars.map((k, v) => MapEntry('$k', v)),
        'seenIntros': seenIntros.toList(),
        'boosters': boosters,
      };

  factory Progress.fromJson(Map<String, dynamic> j) => Progress(
        stars: (j['stars'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(int.parse(k), v as int)),
        seenIntros: {...(j['seenIntros'] as List? ?? []).cast<String>()},
        boosters: (j['boosters'] as Map<String, dynamic>? ?? {}).cast<String, int>(),
      );
}

/// Stores [Progress] as one JSON string in shared_preferences.
class ProgressStore {
  static const _key = 'progress_v1';

  Future<Progress> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_key);
    if (s == null) return Progress();
    try {
      return Progress.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } on FormatException {
      return Progress();
    }
  }

  Future<void> save(Progress progress) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(progress.toJson()));
  }

  /// TODO(M2): write JSON to a user-chosen file via file_picker `saveFile`.
  Future<void> exportToFile(Progress progress) => throw UnimplementedError('M2');

  /// TODO(M2): pick a JSON file via file_picker, validate, merge.
  Future<Progress> importFromFile() => throw UnimplementedError('M2');
}
