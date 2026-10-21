/// Daily challenge: one deterministic level per local calendar day.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../engine/level.dart';

/// yyyymmdd of the LOCAL calendar day of [t].
int dayKey(DateTime t) => t.year * 10000 + t.month * 100 + t.day;

DateTime dayFromKey(int k) => DateTime(k ~/ 10000, k ~/ 100 % 100, k % 100);

/// Mid-difficulty templates (map levels 8–20 without intro/gift cards).
const int kDailyMinTemplate = 8, kDailyMaxTemplate = 20;

/// The daily level for [day]: goals/layers/size of a mid map level picked by
/// the date, with a date-derived seed. Same date ⇒ same level on every device.
/// Its id is the day key (yyyymmdd), which never collides with map ids.
Level dailyLevel(DateTime day, List<Level> pack) {
  final templates = [
    for (final l in pack)
      if (l.id >= kDailyMinTemplate && l.id <= kDailyMaxTemplate && l.introduces == null && l.gift == null) l,
  ];
  if (templates.isEmpty) throw StateError('no daily templates');
  final key = dayKey(day);
  final dayNumber = DateTime.utc(day.year, day.month, day.day).difference(DateTime.utc(2026)).inDays;
  final t = templates[dayNumber % templates.length];
  return Level(
    id: key,
    columns: t.columns,
    rows: t.rows,
    seed: key * 31 + 7,
    goals: t.goals,
    layers: t.layers,
    digitWeights: t.digitWeights,
    addNumbersLimit: t.addNumbersLimit,
    tier: t.tier,
  );
}

/// Persisted daily results: completed days (day keys) and best streak.
class DailyState {
  DailyState({Set<int>? completed, this.best = 0}) : completed = completed ?? {};
  final Set<int> completed;
  int best;

  bool isDone(DateTime day) => completed.contains(dayKey(day));

  /// Consecutive completed days ending today (or yesterday if today isn't
  /// done yet, so the streak isn't shown as broken before playing).
  int streak(DateTime today) {
    var d = DateTime(today.year, today.month, today.day);
    if (!isDone(d)) d = DateTime(d.year, d.month, d.day - 1);
    var n = 0;
    while (isDone(d)) {
      n++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return n;
  }

  Map<String, dynamic> toJson() => {'v': 1, 'completed': completed.toList()..sort(), 'best': best};

  factory DailyState.fromJson(Map<String, dynamic> j) =>
      DailyState(completed: {...(j['completed'] as List? ?? []).whereType<int>()}, best: j['best'] as int? ?? 0);
}

class DailyStore {
  static const String key = 'daily_v1';

  Future<DailyState> load() async {
    final s = (await SharedPreferences.getInstance()).getString(key);
    if (s == null) return DailyState();
    try {
      return DailyState.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } on Object {
      return DailyState();
    }
  }

  /// Marks [day] won (once) and updates the best streak.
  Future<DailyState> recordWin(DateTime day) async {
    final s = await load();
    s.completed.add(dayKey(day));
    final st = s.streak(day);
    if (st > s.best) s.best = st;
    await (await SharedPreferences.getInstance()).setString(key, jsonEncode(s.toJson()));
    return s;
  }
}
