import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Player progress: best stars per level, unlocked level, seen intro cards,
/// booster stock. Pure data; see [ProgressStore] for persistence.
class Progress {
  Progress({
    Map<int, int>? stars,
    int unlockedLevel = 1,
    Set<String>? seenIntros,
    Map<String, int>? boosters,
  })  : stars = stars ?? {},
        seenIntros = seenIntros ?? {},
        boosters = boosters ?? {},
        _unlocked = unlockedLevel < 1 ? 1 : unlockedLevel;

  /// Current on-disk schema version.
  static const int schemaVersion = 2;

  final Map<int, int> stars;
  final Set<String> seenIntros;
  final Map<String, int> boosters;
  int _unlocked;

  /// Highest playable level (1-based). Never decreases.
  int get unlockedLevel {
    final fromStars = stars.isEmpty ? 1 : stars.keys.reduce((a, b) => a > b ? a : b) + 1;
    return _unlocked > fromStars ? _unlocked : fromStars;
  }

  /// Back-compat alias.
  int get highestUnlocked => unlockedLevel;

  int starsFor(int levelId) => stars[levelId] ?? 0;
  int boosterCount(String id) => boosters[id] ?? 0;

  /// Record a win. Keeps the best stars (never downgrades) and unlocks next.
  void recordWin(int levelId, int starsEarned) {
    final s = starsEarned.clamp(1, 3);
    if (s > starsFor(levelId)) stars[levelId] = s;
    if (levelId + 1 > _unlocked) _unlocked = levelId + 1;
  }

  void addBooster(String id, int n) {
    final v = boosterCount(id) + n;
    boosters[id] = v < 0 ? 0 : v;
  }

  Map<String, dynamic> toJson() => {
        'v': schemaVersion,
        'stars': stars.map((k, v) => MapEntry('$k', v)),
        'unlocked': unlockedLevel,
        'seenIntros': (seenIntros.toList()..sort()),
        'boosters': boosters,
      };

  /// Tolerant parser for any known schema version (v1 had no 'unlocked').
  /// Unknown keys are ignored; bad entries are skipped rather than fatal.
  factory Progress.fromJson(Map<String, dynamic> j) {
    final stars = <int, int>{};
    final rawStars = j['stars'];
    if (rawStars is Map) {
      rawStars.forEach((k, v) {
        final id = int.tryParse('$k');
        if (id != null && v is int && v > 0) stars[id] = v.clamp(1, 3);
      });
    }
    final boosters = <String, int>{};
    final rawB = j['boosters'];
    if (rawB is Map) {
      rawB.forEach((k, v) {
        if (v is int && v >= 0) boosters['$k'] = v;
      });
    }
    final rawSeen = j['seenIntros'];
    return Progress(
      stars: stars,
      unlockedLevel: j['unlocked'] is int ? j['unlocked'] as int : 1,
      seenIntros: rawSeen is List ? {...rawSeen.whereType<String>()} : {},
      boosters: boosters,
    );
  }
}

/// Stores [Progress] as one JSON string in shared_preferences.
///
/// Key `progress` holds the current schema; legacy `progress_v1` is read
/// once and migrated (kept untouched on disk as a backup).
class ProgressStore {
  ProgressStore({SharedPreferences? prefs}) : _prefs = prefs;

  static const String key = 'progress';
  static const String legacyKeyV1 = 'progress_v1';

  SharedPreferences? _prefs;
  Future<SharedPreferences> get _p async => _prefs ??= await SharedPreferences.getInstance();

  Future<Progress> load() async {
    final p = await _p;
    final s = p.getString(key) ?? p.getString(legacyKeyV1);
    if (s == null) return Progress();
    try {
      final j = jsonDecode(s);
      if (j is! Map<String, dynamic>) return Progress();
      final v = j['v'];
      if (v is int && v > Progress.schemaVersion) {
        debugPrint('Progress schema v$v is newer than ${Progress.schemaVersion}; reading best-effort.');
      }
      return Progress.fromJson(j);
    } on FormatException {
      return Progress();
    }
  }

  Future<void> save(Progress progress) async {
    final p = await _p;
    await p.setString(key, jsonEncode(progress.toJson()));
  }

  /// TODO(M3): write JSON to a user-chosen file via file_picker `saveFile`.
  Future<void> exportToFile(Progress progress) => throw UnimplementedError('M3');

  /// TODO(M3): pick a JSON file via file_picker, validate, merge.
  Future<Progress> importFromFile() => throw UnimplementedError('M3');
}

/// App-wide progress holder: loads once, notifies listeners, saves on change.
class ProgressController extends ChangeNotifier {
  ProgressController(this.store);

  final ProgressStore store;
  Progress _progress = Progress();
  bool _loaded = false;

  Progress get progress => _progress;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    _progress = await store.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _commit() async {
    notifyListeners();
    await store.save(_progress);
  }

  Future<void> recordWin(int levelId, int stars) {
    _progress.recordWin(levelId, stars);
    return _commit();
  }

  Future<void> markIntroSeen(String id) {
    _progress.seenIntros.add(id);
    return _commit();
  }

  Future<void> addBooster(String id, int n) {
    _progress.addBooster(id, n);
    return _commit();
  }

  Future<void> spendBoosters(Map<String, int> spent) {
    spent.forEach((k, v) => _progress.addBooster(k, -v));
    return _commit();
  }
}
