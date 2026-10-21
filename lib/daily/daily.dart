/// Daily challenge: one deterministic level per local calendar day.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../engine/digit_flip.dart';
import '../engine/level.dart';

/// yyyymmdd of the LOCAL calendar day of [t].
int dayKey(DateTime t) => t.year * 10000 + t.month * 100 + t.day;

DateTime dayFromKey(int k) => DateTime(k ~/ 10000, k ~/ 100 % 100, k % 100);

/// Mid-difficulty templates (map levels 8–20 without intro/gift cards).
const int kDailyMinTemplate = 8, kDailyMaxTemplate = 20;

/// Daily is locked until this map level has been completed.
const int kDailyUnlockLevel = 8;

/// Whether the daily challenge is available for [completedLevels] (map ids
/// with at least one star).
bool dailyUnlocked(Iterable<int> completedLevels) => completedLevels.contains(kDailyUnlockLevel);

/// Whether [day]'s daily uses the digit flip (d -> 10 - d). Date-seeded.
bool dailyDigitFlip(DateTime day) {
  var h = (dayKey(day) * 0x9E3779B1) & 0xFFFFFFFF;
  h ^= h >> 15;
  h = (h * 0x85EBCA6B) & 0xFFFFFFFF;
  h ^= h >> 13;
  return h & 1 == 1;
}

/// The daily level for [day]: a mid map level (8–20) that the player has
/// already completed ([completedLevels]), picked by the date. Its board is
/// exactly that map level's own validated board (same id/seed, see
/// [Level.boardFrom]) with a date-seeded digit flip (number goals and digit
/// weights flipped consistently). No new board is generated, so it cannot
/// fail where the map level doesn't. Same date + same completed set ⇒
/// same level. Its id is the day key (yyyymmdd), which never collides with
/// map ids. Returns null while locked ([dailyUnlocked] is false).
Level? dailyLevel(DateTime day, List<Level> pack, Iterable<int> completedLevels) {
  if (!dailyUnlocked(completedLevels)) return null;
  final done = completedLevels.toSet();
  final templates = [
    for (final l in pack)
      if (l.id >= kDailyMinTemplate &&
          l.id <= kDailyMaxTemplate &&
          l.introduces == null &&
          l.gift == null &&
          done.contains(l.id))
        l,
  ];
  if (templates.isEmpty) return null;
  final key = dayKey(day);
  final dayNumber = DateTime.utc(day.year, day.month, day.day).difference(DateTime.utc(2026)).inDays;
  final t = templates[dayNumber % templates.length];
  final flip = dailyDigitFlip(day);
  return Level(
    id: key,
    columns: t.columns,
    rows: t.rows,
    seed: t.seed,
    goals: flip ? flipGoals(t.goals) : t.goals,
    layers: t.layers,
    digitWeights: flip ? flipWeights(t.digitWeights) : t.digitWeights,
    addNumbersLimit: t.addNumbersLimit,
    tier: t.tier,
    digitFlip: flip,
    boardFrom: t.id,
  );
}

/// Persisted daily results: completed days (day keys) and best streak.
class DailyState {
  DailyState({Set<int>? completed, this.best = 0}) : completed = completed ?? {};
  final Set<int> completed;
  int best;

  bool isDone(DateTime day) => completed.contains(dayKey(day));

  /// Consecutive completed days ending today (or yesterday if today isn't
  /// done yet, so the streak isn't shown as broken before playing). A missed
  /// day simply ends the run: the next win starts again from 1. There is no
  /// "lost streak" state; days without a win are just not in [completed].
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
