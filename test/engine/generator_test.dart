import 'dart:convert';
import 'dart:io';

import 'package:numberpuzzle/engine/board.dart';
import 'package:numberpuzzle/engine/cell.dart';
import 'package:numberpuzzle/engine/game.dart';
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

  test('PRNG is deterministic', () {
    final a = SeededRng(42), b = SeededRng(42);
    expect([for (var i = 0; i < 5; i++) a.nextUint32()], [for (var i = 0; i < 5; i++) b.nextUint32()]);
  });

  test('generator is deterministic', () {
    for (final id in [1, 9, 24, 30]) {
      final l = pack.levels[id - 1];
      expect(gen.generate(l).cells, gen.generate(l).cells, reason: 'level $id');
    }
  });

  test('minPairs rejects too-short boards and reseeds', () {
    final l = pack.levels[6]; // level 7: 3 stars, trivially short by default
    const strict = SeededBoardGenerator(minPairs: 3);
    final g = strict.generateDetailed(l);
    expect(shortWinCheck(g.board, l.goals, 2), ShortWinCheck.notWinnableWithin);
    expect(g.solution.moves.whereType<PairMove>().length, greaterThanOrEqualTo(3));
  });

  test(
    'all 30 levels generate, satisfy constraints and are solvable (< 30 s)',
    () {
      final seeds = <int, int>{
        for (final m in RegExp(
          r'^\| (\d+) \| \d+ \| (\d+) \|',
          multiLine: true,
        ).allMatches(File('docs/generated-seeds.md').readAsStringSync()))
          int.parse(m[1]!): int.parse(m[2]!),
      };
      final sw = Stopwatch()..start();
      for (final l in pack.levels) {
        final g = gen.generateDetailed(l);
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
      print('30 levels generated + verified in ${sw.elapsedMilliseconds} ms');
      expect(sw.elapsed.inSeconds, lessThan(30));
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
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
    expect(
      List.generate(b.columns, (c) => b.at(r, c)).every((x) => x.obstacle?.kind == ObstacleKind.stone),
      isFalse,
    );
  }
}
