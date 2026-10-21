import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:numberpuzzle/daily/daily.dart';
import 'package:numberpuzzle/engine/board.dart';
import 'package:numberpuzzle/engine/digit_flip.dart';
import 'package:numberpuzzle/engine/generator.dart';
import 'package:numberpuzzle/engine/goals.dart';
import 'package:numberpuzzle/engine/level.dart';
import 'package:numberpuzzle/engine/solver.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _all = {for (var i = 1; i <= 40; i++) i};

final _pack = LevelPack.fromJson(
  jsonDecode(File('assets/levels/levels.json').readAsStringSync()) as Map<String, dynamic>,
).levels;

void main() {
  test('daily level is deterministic per local day and varies across days', () {
    final a = dailyLevel(DateTime(2026, 10, 21, 8), _pack, _all)!;
    final b = dailyLevel(DateTime(2026, 10, 21, 23, 59), _pack, _all)!;
    final c = dailyLevel(DateTime(2026, 10, 22), _pack, _all)!;
    expect(a.id, 20261021);
    expect(a.seed, b.seed);
    expect(c.id, isNot(a.id));
    expect(a.goals.map((g) => g.toJson()), b.goals.map((g) => g.toJson()));
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
      final l = dailyLevel(DateTime(2026, 10, 1).add(Duration(days: d)), _pack, _all)!;
      final goals = l.digitFlip ? flipGoals(l.goals) : l.goals;
      expect(mid, contains(jsonEncode(goals.map((g) => g.toJson()).toList())));
    }
  });

  test('a week of daily boards generates (same board for the same day)', () {
    const gen = SeededBoardGenerator();
    for (var d = 0; d < 7; d++) {
      final l = dailyLevel(DateTime(2026, 10, 21).add(Duration(days: d)), _pack, _all)!;
      final b1 = gen.generate(l);
      expect(b1.cells.where((c) => c.value != null), isNotEmpty);
      if (d == 0) expect(gen.generate(l).cells, b1.cells);
    }
  });

  group('unlock and template pool', () {
    final day = DateTime(2026, 10, 21);
    test('locked until level 8 is completed', () {
      expect(dailyUnlocked({1, 2, 3, 4, 5, 6, 7}), isFalse);
      expect(dailyLevel(day, _pack, {1, 2, 3, 4, 5, 6, 7}), isNull);
      expect(dailyUnlocked({8}), isTrue);
      expect(dailyLevel(day, _pack, {for (var i = 1; i <= 8; i++) i}), isNotNull);
    });
    test('only completed map levels in 8..20 are used, deterministic by date', () {
      String sig(Level l) =>
          jsonEncode((l.digitFlip ? flipGoals(l.goals) : l.goals).map((g) => g.toJson()).toList());
      final byId = {for (final l in _pack) l.id: l};
      final onlyL8 = {for (var i = 1; i <= 8; i++) i};
      for (var d = 0; d < 30; d++) {
        final dd = day.add(Duration(days: d));
        final l = dailyLevel(dd, _pack, onlyL8)!;
        expect(sig(l), jsonEncode(byId[8]!.goals.map((g) => g.toJson()).toList()));
        expect(l.columns, byId[8]!.columns);
        expect(l.rows, byId[8]!.rows);
      }
      final done = {for (var i = 1; i <= 12; i++) i};
      final allowed = {
        for (final id in [8, 9, 12]) jsonEncode(byId[id]!.goals.map((g) => g.toJson()).toList()),
      };
      final seen = <String>{};
      for (var d = 0; d < 30; d++) {
        final dd = day.add(Duration(days: d));
        final l = dailyLevel(dd, _pack, done)!;
        expect(allowed, contains(sig(l)), reason: 'level 10 (gift) / 11 (intro) / >12 excluded');
        expect(dailyLevel(dd, _pack, done)!.toJson(), l.toJson());
        seen.add(sig(l));
      }
      expect(seen.length, 3);
    });
  });

  group('digit flip variation', () {
    test('flip is date-seeded and both variants occur', () {
      final flips = [for (var d = 0; d < 60; d++) dailyDigitFlip(DateTime(2026, 10, 1).add(Duration(days: d)))];
      expect(flips, contains(true));
      expect(flips, contains(false));
      expect(dailyDigitFlip(DateTime(2026, 10, 21, 1)), dailyDigitFlip(DateTime(2026, 10, 21, 23)));
    });

    test('number goals and weights flipped consistently; stars/grass/obstacles unchanged', () {
      const gen = SeededBoardGenerator();
      final day = List.generate(60, (d) => DateTime(2026, 10, 1).add(Duration(days: d)))
          .firstWhere((d) => dailyDigitFlip(d) && dailyLevel(d, _pack, _all)!.goals.any((g) => g.type == GoalType.number));
      final l = dailyLevel(day, _pack, _all)!;
      final plain = Level(
        id: l.boardFrom!,
        columns: l.columns,
        rows: l.rows,
        seed: l.seed,
        goals: flipGoals(l.goals),
        layers: l.layers,
        digitWeights: flipWeights(l.digitWeights),
        addNumbersLimit: l.addNumbersLimit,
        tier: l.tier,
      );
      final a = gen.generate(plain), b = gen.generate(l);
      expect(b.cells, flipBoardDigits(a).cells);
      for (var i = 0; i < a.length; i++) {
        expect(b[i].item, a[i].item);
        expect(b[i].grass, a[i].grass);
        expect(b[i].obstacle, a[i].obstacle);
        if (a[i].value != null) expect(b[i].value, 10 - a[i].value!);
      }
      for (var i = 0; i < l.goals.length; i++) {
        final g = l.goals[i], o = plain.goals[i];
        expect(g.type, o.type);
        if (g.type == GoalType.number) expect(g.value, 10 - o.value!);
      }
    });

    test('365 consecutive dates: map level board (+flip) always builds, both variants, solver sample', () {
      const gen = SeededBoardGenerator();
      const solver = DfsSolver(nodeBudget: 200000);
      final byId = {for (final l in _pack) l.id: l};
      final mapBoards = <int, Board>{};
      final solved = <String>{};
      var flipped = 0;
      for (var d = 0; d < 365; d++) {
        final l = dailyLevel(DateTime(2026, 1, 1).add(Duration(days: d)), _pack, _all)!;
        final t = byId[l.boardFrom]!;
        expect(l.seed, t.seed, reason: 'no date-derived seed');
        final mapBoard = mapBoards[t.id] ??= gen.generate(t);
        final b = gen.generate(l);
        expect(b.cells, (l.digitFlip ? flipBoardDigits(mapBoard) : mapBoard).cells, reason: '${l.id} L${t.id} ${l.digitFlip}');
        if (l.digitFlip) flipped++;
        if (solved.add('${t.id}-${l.digitFlip}')) {
          expect(solver.solve(b, l.goals).solvable, isTrue, reason: 'daily ${l.id} (L${t.id}) flip=${l.digitFlip}');
        }
      }
      expect(flipped, inInclusiveRange(1, 364), reason: 'both variants appear');
      expect(solved.length, greaterThan(mapBoards.length), reason: 'solver ran on both variants');
    });
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
    test('a missed day restarts from 1 on the next win; no zero/lost state persisted', () async {
      SharedPreferences.setMockInitialValues({});
      final store = DailyStore();
      for (final d in [18, 19, 20]) {
        await store.recordWin(DateTime(2026, 10, d));
      }
      // 21 missed. On the 22nd, before playing: yesterday not done -> 0 shown,
      // but nothing is reset; past wins stay in the calendar.
      var s = await store.load();
      expect(s.streak(DateTime(2026, 10, 22)), 0);
      expect(s.isDone(DateTime(2026, 10, 21)), isFalse, reason: 'missed day is just empty');
      expect(s.completed, {20261018, 20261019, 20261020});
      s = await store.recordWin(DateTime(2026, 10, 22));
      expect(s.streak(DateTime(2026, 10, 22)), 1);
      expect(s.best, 3);
      s = await store.recordWin(DateTime(2026, 10, 23));
      expect(s.streak(DateTime(2026, 10, 23)), 2);
      expect(s.toJson().keys, unorderedEquals(['v', 'completed', 'best']));
    });
  });
}
