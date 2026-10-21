import 'dart:convert';
import 'dart:io';

import 'package:numberpuzzle/engine/board.dart';
import 'package:numberpuzzle/engine/cell.dart';
import 'package:numberpuzzle/engine/game.dart';
import 'package:numberpuzzle/engine/goals.dart';
import 'package:numberpuzzle/engine/generator.dart';
import 'package:numberpuzzle/engine/level.dart';
import 'package:numberpuzzle/engine/moves.dart';
import 'package:numberpuzzle/engine/solver.dart';
import 'package:test/test.dart';

void main() {
  final pack = LevelPack.fromJson(
    jsonDecode(File('assets/levels/levels.json').readAsStringSync()) as Map<String, dynamic>,
  );
  const gen = SeededBoardGenerator();
  // Generated once (timed) and shared by the tests below.
  final generated = <int, GeneratedLevel>{};
  final errors = <int, StateError>{};
  var generateMs = 0;
  setUpAll(() {
    final sw = Stopwatch()..start();
    for (final l in pack.levels) {
      try {
        generated[l.id] = gen.generateDetailed(l);
      } on StateError catch (e) {
        errors[l.id] = e;
      }
    }
    generateMs = sw.elapsedMilliseconds;
  });

  test('PRNG is deterministic', () {
    final a = SeededRng(42), b = SeededRng(42);
    expect([for (var i = 0; i < 5; i++) a.nextUint32()], [for (var i = 0; i < 5; i++) b.nextUint32()]);
  });

  test('generator is deterministic', () {
    for (final id in [1, 9, 24, 30]) {
      final l = pack.levels[id - 1];
      expect(gen.generate(l).cells, generated[id]!.board.cells, reason: 'level $id');
    }
  });

  test(
    'late placement: stars/grass only in last 50% of line, never first 3 pairs',
    () {
      expect(SeededBoardGenerator.latePairIndex(4), 3);
      expect(SeededBoardGenerator.latePairIndex(20), 10);
      for (final l in pack.levels.where((l) => l.layers.stars + l.layers.grass > 0 && generated.containsKey(l.id))) {
        final g = generated[l.id]!;
        expect(g.latePlacement, isTrue, reason: 'level ${l.id}');
        final line = g.placementLine;
        final first = SeededBoardGenerator.latePairIndex(line.moves.whereType<PairMove>().length);
        final at = {for (var k = 0; k < line.clearOrder.length; k++) line.clearOrder[k]: line.clearPairIndex[k]};
        for (var i = 0; i < g.board.length; i++) {
          final c = g.board[i];
          if (c.item == CellItem.star || c.grass) {
            expect(at[i], isNotNull, reason: 'level ${l.id} cell $i not cleared by line');
            expect(at[i]!, greaterThanOrEqualTo(first), reason: 'level ${l.id} cell $i');
            expect(at[i]!, greaterThanOrEqualTo(3));
          }
        }
        // Re-verified: solvable without boosters with <= 3 Add numbers.
        expect(g.solution.solvable, isTrue);
        expect(g.solution.moves.whereType<AddNumbersMove>().length, lessThanOrEqualTo(solverAddLimit));
      }
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test('all 30 levels generate (no errors)', () {
    expect(errors, isEmpty);
    expect(generated, hasLength(30));
  });

  test('CI rules: first-pair rule, goal-minPairs, greedy wins for UX levels', () {
    expect(SeededBoardGenerator.kGoalMinPairsTargets, {7: 5, 8: 5, 15: 4, 25: 4, 22: 7});
    for (final l in pack.levels.where((l) => generated.containsKey(l.id))) {
      final g = generated[l.id]!;
      expect(g.latePlacement, isTrue, reason: 'level ${l.id}');
      // No star/grass in any valid first pair.
      expect(SeededBoardGenerator.noFirstPairCollect(g.board), isTrue, reason: 'level ${l.id}');
      for (final (a, b) in fastValidPairs(g.board)) {
        expect(g.board[a].item == null && !g.board[a].grass, isTrue);
        expect(g.board[b].item == null && !g.board[b].grass, isTrue);
      }
      final sgGoals = [
        for (final x in l.goals)
          if (x.type == GoalType.star || x.type == GoalType.grass) x,
      ];
      if (sgGoals.isEmpty) {
        expect(g.goalMinPairsMet, isNull);
      } else {
        final target = SeededBoardGenerator.kGoalMinPairsTargets[l.id] ?? SeededBoardGenerator.kDefaultGoalMinPairs;
        expect(g.goalMinPairsTarget, target);
        expect(g.goalMinPairs, greaterThanOrEqualTo(SeededBoardGenerator.kGoalMinPairsFloor));
        expect(SeededBoardGenerator.goalMinPairsFloor(g.board, sgGoals, target), g.goalMinPairs);
        expect(g.goalMinPairsMet, g.goalMinPairs! >= target);
        expect(
          shortWinCheck(g.board, sgGoals, SeededBoardGenerator.kGoalMinPairsFloor - 1, addNumbersLimit: 0),
          ShortWinCheck.notWinnableWithin,
          reason: 'level ${l.id}',
        );
      }
      if (SeededBoardGenerator.kRequireGreedyWinLevels.contains(l.id)) {
        expect(
          greedyPairsToWin(g.board, l.goals, addNumbersLimit: l.addNumbersLimit),
          isNotNull,
          reason: 'level ${l.id}',
        );
      }
    }
  });

  test('minPairs rejects too-short boards and reseeds', () {
    final l = pack.levels[6]; // level 7: 3 stars, trivially short by default
    const strict = SeededBoardGenerator(minPairs: 3);
    final g = strict.generateDetailed(l);
    expect(shortWinCheck(g.board, l.goals, 2), ShortWinCheck.notWinnableWithin);
    expect(g.solution.moves.whereType<PairMove>().length, greaterThanOrEqualTo(3));
  });

  test('all 30 levels generate, satisfy constraints and are solvable (< 30 s)', () {
    final seeds = <int, int>{
      for (final m in RegExp(
        r'^\| (\d+) \| \d+ \| (\d+) \|',
        multiLine: true,
      ).allMatches(File('docs/generated-seeds.md').readAsStringSync()))
        int.parse(m[1]!): int.parse(m[2]!),
    };
    final sw = Stopwatch()..start();
    for (final l in pack.levels.where((l) => generated.containsKey(l.id))) {
      final g = generated[l.id]!;
      final b = g.board;
      expect(g.seedUsed, seeds[l.id], reason: 'documented seed for level ${l.id}');
      expect(b.columns, l.columns);
      expect(b.rows, l.rows);
      _checkConstraints(l, b, g.solution);
      // Replay the line in a real game without boosters.
      var s = GameState.start(b, l.goals, addNumbersLimit: solverAddLimit);
      for (final m in g.solution.moves) {
        s = s.apply(m);
      }
      expect(s.isWon, isTrue, reason: 'level ${l.id}');
      expect(s.boostersUsed, 0);
      expect(g.solution.moves.whereType<AddNumbersMove>().length, lessThanOrEqualTo(solverAddLimit));
    }
    sw.stop();
    // ignore: avoid_print
    print('${generated.length}/30 levels generated + verified in ${generateMs + sw.elapsedMilliseconds} ms');
    expect(generateMs + sw.elapsedMilliseconds, lessThan(30000));
  }, timeout: const Timeout(Duration(seconds: 90)));
}

void _checkConstraints(Level l, Board b, SolveResult sol) {
  int count(bool Function(Cell) f) => b.cells.where(f).length;
  expect(count((c) => c.obstacle?.kind == ObstacleKind.stone), l.layers.stone);
  expect(count((c) => c.obstacle?.kind == ObstacleKind.slime), l.layers.slime);
  expect(count((c) => c.obstacle?.kind == ObstacleKind.ice), l.layers.ice.count);
  expect(count((c) => c.item == CellItem.star), l.layers.stars);
  expect(count((c) => c.grass), l.layers.grass);
  final corners = {0, b.columns - 1, b.length - b.columns, b.length - 1};
  for (var i = 0; i < b.length; i++) {
    final c = b[i];
    final k = c.obstacle?.kind;
    if (k == ObstacleKind.stone) expect(corners.contains(i), isFalse);
    if (k == ObstacleKind.slime) {
      expect(b.neighbours(i).any((n) => b[n].obstacle?.kind == ObstacleKind.stone), isFalse);
    }
    if (k == ObstacleKind.ice) {
      final hp = c.obstacle!.hp;
      expect(hp, inInclusiveRange(l.layers.ice.hpMin, l.layers.ice.hpMax));
      final near = b.neighbours(i).toSet();
      expect(fastValidPairs(b).any((p) => near.contains(p.$1) || near.contains(p.$2)), isTrue);
    }
    if (c.item == CellItem.star || c.grass) expect(sol.clearedCells.contains(i), isTrue);
  }
  for (var r = 0; r < b.rows; r++) {
    expect(List.generate(b.columns, (c) => b.at(r, c)).every((x) => x.obstacle?.kind == ObstacleKind.stone), isFalse);
  }
}
