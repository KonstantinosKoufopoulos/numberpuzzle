import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:numberpuzzle/daily/daily.dart';
import 'package:numberpuzzle/engine/generator.dart';
import 'package:numberpuzzle/engine/level.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _pack = LevelPack.fromJson(
  jsonDecode(File('assets/levels/levels.json').readAsStringSync()) as Map<String, dynamic>,
).levels;

void main() {
  test('daily level is deterministic per local day and varies across days', () {
    final a = dailyLevel(DateTime(2026, 10, 21, 8), _pack);
    final b = dailyLevel(DateTime(2026, 10, 21, 23, 59), _pack);
    final c = dailyLevel(DateTime(2026, 10, 22), _pack);
    expect(a.id, 20261021);
    expect(a.seed, b.seed);
    expect(a.goals.map((g) => g.toJson()), b.goals.map((g) => g.toJson()));
    expect(c.seed, isNot(a.seed));
    expect(a.validate(), isEmpty);
    expect(a.introduces, isNull);
    expect(a.gift, isNull);
  });

  test('daily goals come from mid map levels (8–20)', () {
    final mid = {
      for (final l in _pack)
        if (l.id >= 8 && l.id <= 20) jsonEncode(l.goals.map((g) => g.toJson()).toList()),
    };
    for (var d = 0; d < 40; d++) {
      final l = dailyLevel(DateTime(2026, 10, 1).add(Duration(days: d)), _pack);
      expect(mid, contains(jsonEncode(l.goals.map((g) => g.toJson()).toList())));
    }
  });

  test('a week of daily boards generates (same board for the same day)', () {
    const gen = SeededBoardGenerator();
    for (var d = 0; d < 7; d++) {
      final l = dailyLevel(DateTime(2026, 10, 21).add(Duration(days: d)), _pack);
      final b1 = gen.generate(l);
      expect(b1.cells.where((c) => c.value != null), isNotEmpty);
      if (d == 0) expect(gen.generate(l).cells, b1.cells);
    }
  });

  group('streak', () {
    final today = DateTime(2026, 10, 21, 12);
    test('counts back from today, or from yesterday if today not done', () {
      final s = DailyState(completed: {20261019, 20261020});
      expect(s.streak(today), 2);
      s.completed.add(20261021);
      expect(s.streak(today), 3);
      expect(DailyState(completed: {20261018}).streak(today), 0);
    });
    test('crosses month boundaries', () {
      final s = DailyState(completed: {20260930, 20261001});
      expect(s.streak(DateTime(2026, 10, 1)), 2);
    });
    test('recordWin persists once per day and keeps best', () async {
      SharedPreferences.setMockInitialValues({});
      final store = DailyStore();
      await store.recordWin(DateTime(2026, 10, 20));
      var s = await store.recordWin(DateTime(2026, 10, 21));
      expect(s.best, 2);
      s = await store.recordWin(DateTime(2026, 10, 21));
      expect(s.completed.length, 2);
      s = await store.recordWin(DateTime(2026, 10, 25));
      expect(s.streak(DateTime(2026, 10, 25)), 1);
      expect((await DailyStore().load()).best, 2);
    });
  });
}
