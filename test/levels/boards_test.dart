import 'dart:convert';
import 'dart:io';

import 'package:numberpuzzle/engine/cell.dart';
import 'package:numberpuzzle/engine/game.dart';
import 'package:numberpuzzle/engine/generator.dart';
import 'package:numberpuzzle/engine/goals.dart';
import 'package:numberpuzzle/engine/moves.dart';
import 'package:numberpuzzle/engine/solver.dart';
import 'package:numberpuzzle/levels/board_codec.dart';
import 'package:test/test.dart';

import '../../tool/bake_boards.dart' as bake;

void main() {
  final pack = bake.loadPack();
  final file = File(bake.boardsPath).readAsStringSync();
  final boards = parseBoards(jsonDecode(file) as Map<String, dynamic>);

  test('boards.json is byte-identical to a fresh bake', () {
    final sw = Stopwatch()..start();
    final fresh = bake.bakeAll(pack);
    // ignore: avoid_print
    print('re-baked 30 levels in ${sw.elapsedMilliseconds} ms');
    expect(fresh == file, isTrue, reason: 'run `dart run tool/bake_boards.dart` and commit boards.json');
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('codec round-trips', () {
    expect(bake.encodeBoards(boards.values.toList()), file);
  });

  test('every board matches its level and the rules', () {
    expect(boards.keys, [for (final l in pack.levels) l.id]);
    final seeds = <int, int>{
      for (final m in RegExp(
        r'^\| (\d+) \| \d+ \| (\d+) \|',
        multiLine: true,
      ).allMatches(File('docs/generated-seeds.md').readAsStringSync()))
        int.parse(m[1]!): int.parse(m[2]!),
    };
    for (final l in pack.levels) {
      final bb = boards[l.id]!, b = bb.board;
      final why = 'level ${l.id}';
      expect(bb.seed, l.seed, reason: why);
      expect(bb.seedUsed, seeds[l.id], reason: why);
      expect(bb.width, l.columns, reason: why);
      expect(bb.height, l.rows, reason: why);
      expect(jsonEncode(bb.goals), jsonEncode(l.goals), reason: why);
      int count(bool Function(Cell) f) => b.cells.where(f).length;
      expect(count((c) => c.item == CellItem.star), l.layers.stars, reason: why);
      expect(count((c) => c.grass), l.layers.grass, reason: why);
      expect(count((c) => c.obstacle?.kind == ObstacleKind.stone), l.layers.stone, reason: why);
      expect(count((c) => c.obstacle?.kind == ObstacleKind.slime), l.layers.slime, reason: why);
      expect(count((c) => c.obstacle?.kind == ObstacleKind.ice), l.layers.ice.count, reason: why);

      // Solvable: replay the stored line (0 boosters, <= solverAddLimit adds).
      final line = [for (final m in bb.solution) m is PairMove ? (m.a, m.b) : 'add' as Object];
      expect(verifyLine(b, l.goals, line), isTrue, reason: why);
      var s = GameState.start(b, l.goals, addNumbersLimit: solverAddLimit);
      for (final m in bb.solution) {
        s = s.apply(m);
      }
      expect(s.isWon, isTrue, reason: why);
      expect(s.boostersUsed, 0, reason: why);
      expect(bb.solution.whereType<AddNumbersMove>().length, lessThanOrEqualTo(solverAddLimit));

      // First-pair rule.
      expect(SeededBoardGenerator.noFirstPairCollect(b), isTrue, reason: why);

      // Goal-minPairs.
      final sg = [
        for (final g in l.goals)
          if (g.type == GoalType.star || g.type == GoalType.grass) g,
      ];
      if (sg.isEmpty) {
        expect(bb.metrics['goalMinPairs'], isNull, reason: why);
      } else {
        final target = SeededBoardGenerator.kGoalMinPairsTargets[l.id] ?? SeededBoardGenerator.kDefaultGoalMinPairs;
        final floor = SeededBoardGenerator.goalMinPairsFloor(b, sg, target);
        expect(bb.metrics['goalMinPairs'], floor, reason: why);
        expect(bb.metrics['goalMinPairsTarget'], target, reason: why);
        expect(floor, greaterThanOrEqualTo(SeededBoardGenerator.kGoalMinPairsFloor), reason: why);
      }

      // Greedy-win UX levels.
      final greedy = greedyPairsToWin(b, l.goals, addNumbersLimit: l.addNumbersLimit);
      expect(bb.metrics['greedyPairs'], greedy, reason: why);
      if (SeededBoardGenerator.kRequireGreedyWinLevels.contains(l.id)) {
        expect(greedy, isNotNull, reason: why);
      }
    }
  });
}
