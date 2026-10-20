import 'package:numberpuzzle/engine/board.dart';
import 'package:numberpuzzle/engine/cell.dart';
import 'package:numberpuzzle/engine/game.dart';
import 'package:numberpuzzle/engine/goals.dart';
import 'package:numberpuzzle/engine/hint.dart';
import 'package:numberpuzzle/engine/moves.dart';
import 'package:numberpuzzle/engine/rules.dart';
import 'package:numberpuzzle/engine/solver.dart';
import 'package:test/test.dart';

const int? _ = null;

void main() {
  group('goal types', () {
    test('number counts cells of that digit', () {
      var g = GameState.start(
        Board.fromRows([
          [3, 7, 3, 3, 1],
        ]),
        const [Goal(GoalType.number, 3, value: 3)],
      );
      g = g.pair(0, 1); // 3+7 -> one 3
      expect(g.goalDone, [1]);
      g = g.pair(2, 3); // 3,3 -> three
      expect(g.isWon, isTrue);
    });
    test('star', () {
      final b = Board(3, const [Cell(value: 2, item: CellItem.star), Cell.n(8), Cell.n(1)]);
      final g = GameState.start(b, const [Goal(GoalType.star, 1)]).pair(0, 1);
      expect(g.isWon, isTrue);
    });
    test('grass cleared with its number', () {
      final b = Board(3, const [Cell(value: 2, grass: true), Cell(value: 8, grass: true), Cell.n(1)]);
      final g = GameState.start(b, const [Goal(GoalType.grass, 2)]).pair(0, 1);
      expect(g.isWon, isTrue);
      expect(g.board[0].grass, isFalse);
    });
    test('breakIce', () {
      final b = Board(3, const [Cell.n(4), Cell.n(6), Cell(value: 1, obstacle: Obstacle.ice(1))]);
      final g = GameState.start(b, const [Goal(GoalType.breakIce, 1)]).pair(0, 1);
      expect(g.isWon, isTrue);
    });
    test('slime', () {
      final b = Board(3, const [
        Cell.n(1),
        Cell(obstacle: Obstacle.slime()),
        Cell.empty(),
        Cell.n(9),
        Cell.empty(),
        Cell.empty(),
      ]);
      final g = GameState.start(b, const [Goal(GoalType.slime, 1)]).pair(0, 3);
      expect(g.isWon, isTrue);
    });
    test('win with non-empty board and multiple goals', () {
      final b = Board(4, const [Cell(value: 5, item: CellItem.star), Cell.n(5), Cell.n(1), Cell.n(2)]);
      final g = GameState.start(b, const [
        Goal(GoalType.star, 1),
        Goal(GoalType.number, 2, value: 5),
      ]).pair(0, 1);
      expect(g.isWon, isTrue);
      expect(g.board.isCleared, isFalse);
    });
  });

  group('layers', () {
    test('stone blocks and is permanent', () {
      final b = Board.fromRows([
        [1, 0, 1, 9],
      ]);
      expect(canPair(b, 0, 2), isFalse);
      final r = applyPair(b, 2, 3);
      expect(r.board[1].obstacle?.kind, ObstacleKind.stone);
      expect(r.board.rows, 1);
    });
    test('ice hp2 loses 1 hp per adjacent clear and blocks selection', () {
      final b = Board(4, const [
        Cell.n(3),
        Cell.n(7),
        Cell(value: 5, obstacle: Obstacle.ice(2)),
        Cell.n(5),
        Cell.n(2),
        Cell.n(8),
        Cell.n(1),
        Cell.n(1),
      ]);
      var g = GameState.start(b, const [Goal(GoalType.breakIce, 1)]);
      expect(g.canPair(2, 3), isFalse);
      g = g.pair(0, 1); // only cell 1 touches ice -> hp 1
      expect(g.board[2].obstacle, const Obstacle.ice(1));
      expect(g.isWon, isFalse);
      g = g.pair(4, 5); // cell 5 touches ice -> broken
      expect(g.board[2].obstacle, isNull);
      expect(g.isWon, isTrue);
    });
    test('slime stays until all neighbours empty; off-board counts empty', () {
      final b = Board(3, const [
        Cell(obstacle: Obstacle.slime()),
        Cell.n(4),
        Cell.n(6),
        Cell.n(2),
        Cell.n(8),
        Cell.n(7),
      ]);
      var g = GameState.start(b, const [Goal(GoalType.slime, 1), Goal(GoalType.number, 1, value: 7)]);
      g = g.pair(1, 2);
      expect(g.board[0].obstacle?.kind, ObstacleKind.slime);
      g = g.pair(3, 4); // corner slime: all on-board neighbours now empty
      expect(g.goalDone[0], 1);
      expect(g.board.cells.any((c) => c.obstacle?.kind == ObstacleKind.slime), isFalse);
    });
    test('slime never spreads grass', () {
      final b = Board(3, const [Cell(obstacle: Obstacle.slime()), Cell(value: 4, grass: true), Cell.n(6)]);
      final r = applyPair(b, 1, 2);
      expect(r.board.cells.where((c) => c.grass), isEmpty);
    });
  });

  test('row removal shifts cells below up', () {
    final b = Board.fromRows([
      [1, 2],
      [4, 6],
      [3, 9],
    ]);
    final g = GameState.start(b, const [Goal(GoalType.pairsSame, 5)]).pair(2, 3);
    expect(g.board.rows, 2);
    expect(g.board.cells.map((c) => c.value), [1, 2, 3, 9]);
  });

  test('wrap pairing across empties', () {
    final b = Board.fromRows([
      [5, 3, _],
      [_, _, 7],
    ]);
    expect(canPair(b, 1, 5), isTrue);
    final g = GameState.start(b, const [Goal(GoalType.pairsTen, 1)]).pair(1, 5);
    expect(g.isWon, isTrue);
  });

  group('hammer', () {
    test('clears a number and counts goals', () {
      final b = Board(3, const [Cell(value: 4, item: CellItem.star), Cell.n(1), Cell.n(2)]);
      final g = GameState.start(b, const [Goal(GoalType.star, 1)]).hammer(0);
      expect(g.board[0].isEmpty, isTrue);
      expect(g.isWon, isTrue);
      expect(g.boostersUsed, 1);
    });
    test('removes ice layer, number stays', () {
      final b = Board(2, const [Cell(value: 4, obstacle: Obstacle.ice(2)), Cell.n(1)]);
      final g = GameState.start(b, const [Goal(GoalType.breakIce, 1)]).hammer(0);
      expect(g.board[0].value, 4);
      expect(g.board[0].isSelectable, isTrue);
      expect(g.isWon, isTrue);
    });
    test('removes slime, never stone or empty', () {
      final b = Board(3, const [
        Cell(obstacle: Obstacle.slime()),
        Cell(obstacle: Obstacle.stone()),
        Cell.empty(),
      ]);
      const h = HammerBooster();
      expect(h.canApply(b, 0), isTrue);
      expect(h.canApply(b, 1), isFalse);
      expect(h.canApply(b, 2), isFalse);
      expect(h.apply(b, 0)[0].isEmpty, isTrue);
    });
  });

  test('swap exchanges values, keeps layers', () {
    final b = Board(3, const [Cell(value: 1, item: CellItem.star), Cell.n(5), Cell.n(9)]);
    final g = GameState.start(b, const [Goal(GoalType.star, 1)]).swap(0, 1);
    expect(g.board[0].value, 5);
    expect(g.board[0].item, CellItem.star);
    expect(g.board[1].value, 1);
    expect(g.canPair(1, 2), isTrue);
    expect(const SwapBooster().canApply(b, (0, 0)), isFalse);
    final ice = Board(2, const [Cell(value: 1, obstacle: Obstacle.ice(1)), Cell.n(2)]);
    expect(const SwapBooster().canApply(ice, (0, 1)), isFalse);
  });

  test('undo restores board, progress and adds; boosters stay counted', () {
    final b = Board.fromRows([
      [3, 7, 2],
    ]);
    final g0 = GameState.start(b, const [Goal(GoalType.number, 4, value: 3)]);
    final g1 = g0.pair(0, 1).addNumbers().hammer(2);
    expect(g1.addNumbersUsed, 1);
    var u = g1.undo().undo().undo();
    expect(u.board.cells, g0.board.cells);
    expect(u.goalDone, [0]);
    expect(u.addNumbersUsed, 0);
    expect(u.boostersUsed, 1);
    expect(u.canUndo, isFalse);
    expect(() => u.undo(), throwsStateError);
    u = g0.pair(0, 1);
    expect(g0.goalDone, [0], reason: 'states are immutable');
  });

  test('addNumbers limit', () {
    var g = GameState.start(
      Board.fromRows([
        [1, 2, 3],
      ]),
      const [Goal(GoalType.number, 99, value: 1)],
      addNumbersLimit: 2,
    );
    g = g.addNumbers().addNumbers();
    expect(g.addNumbersLeft, 0);
    expect(g.canAddNumbers, isFalse);
    expect(() => g.addNumbers(), throwsStateError);
  });

  test('lose condition', () {
    final b = Board.fromRows([
      [1, 2, 4],
    ]);
    var g = GameState.start(b, const [Goal(GoalType.number, 4, value: 1)], addNumbersLimit: 1);
    expect(allValidPairs(g.board), isEmpty);
    expect(g.status, GameStatus.playing, reason: 'an Add numbers is still left');
    g = g.addNumbers();
    expect(g.status, GameStatus.playing, reason: 'pairs appeared');
    final lost = GameState.start(
      Board.fromRows([
        [1, 2, 4],
      ]),
      const [Goal(GoalType.number, 4, value: 1)],
      addNumbersLimit: 0,
    );
    expect(lost.status, GameStatus.lost);
    expect(() => lost.addNumbers(), throwsStateError);
    expect(GameState.start(b, const [Goal(GoalType.pairsSame, 1)], addNumbersLimit: 0).isLost, isTrue);
  });

  group('hint', () {
    test('returns a winning pair when one exists', () {
      final b = Board.fromRows([
        [1, 9, 4, 4, 2],
      ]);
      final p = GoalProgress(const [Goal(GoalType.number, 2, value: 4)]);
      final h = computeHint(b, p);
      expect(h.pair, (2, 3));
      expect(h.leadsToWin, isTrue);
      expect(findHint(b, p), (2, 3));
    });
    test('valid pair when no winning line', () {
      final b = Board.fromRows([
        [1, 9, 3],
      ]);
      final h = computeHint(b, GoalProgress(const [Goal(GoalType.number, 5, value: 3)]), addNumbersLeft: 0);
      expect(h.pair, (0, 1));
      expect(h.leadsToWin, isFalse);
    });
    test('suggests addNumbers when no pair', () {
      final b = Board.fromRows([
        [1, 2],
      ]);
      final h = computeHint(b, GoalProgress(const [Goal(GoalType.pairsSame, 1)]));
      expect(h.pair, isNull);
      expect(h.addNumbers, isTrue);
      expect(findHint(b, GoalProgress(const [Goal(GoalType.pairsSame, 1)])), isNull);
    });
    test('hint pair is always valid', () {
      final b = Board.fromRows([
        [3, 4, 6, 7],
        [5, 2, 8, 5],
      ]);
      final h = computeHint(b, GoalProgress(const [Goal(GoalType.pairsTen, 3)]));
      expect(canPair(b, h.pair!.$1, h.pair!.$2), isTrue);
    });
  });

  group('solver', () {
    const s = DfsSolver();
    test('fastValidPairs equals allValidPairs', () {
      final b = Board.fromRows([
        [1, _, 9, 0, 1],
        [_, 5, _, _, 5],
        [9, 3, 7, _, 1],
      ]);
      final f = fastValidPairs(b).toSet();
      expect(f, allValidPairs(b).toSet());
    });
    test('solves a board needing a specific order', () {
      // Only line: clear 3+7 first, which opens 6..4 and then 9..1.
      final b = Board.fromRows([
        [9, 6, 3, 7, 4, 1],
      ]);
      const goals = [Goal(GoalType.number, 1, value: 9)];
      final r = s.solve(b, goals, addNumbersLimit: 0);
      expect(r.solvable, isTrue);
      var g = GameState.start(b, goals, addNumbersLimit: 0);
      for (final m in r.moves) {
        g = g.apply(m);
      }
      expect(g.isWon, isTrue);
      expect(r.moves.length, 3);
    });
    test('uses addNumbers when needed', () {
      final b = Board.fromRows([
        [1, 2, 3],
      ]);
      final r = s.solve(b, const [Goal(GoalType.number, 1, value: 1)]);
      expect(r.solvable, isTrue);
      expect(r.moves.whereType<AddNumbersMove>(), isNotEmpty);
    });
    test('proves unsolvable', () {
      final b = Board.fromRows([
        [1, 2],
      ]);
      expect(s.solve(b, const [Goal(GoalType.number, 1, value: 1)], addNumbersLimit: 0).solvable, isFalse);
      expect(s.solve(b, const [Goal(GoalType.star, 1)]).solvable, isFalse);
    });
    test('respects add limit', () {
      // Need 4 sevens cleared from a single 7 and a 3: requires 2 adds.
      final b = Board.fromRows([
        [7, 3, 1],
      ]);
      const goals = [Goal(GoalType.number, 4, value: 7)];
      expect(s.solve(b, goals, addNumbersLimit: 0).solvable, isFalse);
      expect(s.solve(b, goals, addNumbersLimit: 3).solvable, isTrue);
      expect(solverAddLimit, 3);
    });
    test('shortWinCheck is depth-limited', () {
      final b = Board.fromRows([
        [9, 6, 3, 7, 4, 1],
      ]);
      const goals = [Goal(GoalType.number, 1, value: 9)];
      expect(shortWinCheck(b, goals, 2, addNumbersLimit: 0), ShortWinCheck.notWinnableWithin);
      expect(shortWinCheck(b, goals, 3, addNumbersLimit: 0), ShortWinCheck.winnableWithin);
      final big = Board(9, [for (var i = 0; i < 81; i++) Cell.n(1 + (i * 7) % 9)]);
      expect(
        shortWinCheck(big, const [Goal(GoalType.number, 60, value: 1)], 40, nodeBudget: 0),
        ShortWinCheck.timedOut,
      );
    });
    test('greedyPairsToWin', () {
      final b = Board.fromRows([
        [9, 6, 3, 7, 4, 1],
      ]);
      expect(greedyPairsToWin(b, const [Goal(GoalType.number, 1, value: 9)], addNumbersLimit: 0), 3);
      expect(
        greedyPairsToWin(
          Board.fromRows([
            [1, 2],
          ]),
          const [Goal(GoalType.star, 1)],
        ),
        isNull,
      );
      final s2 = Board(4, const [Cell.n(1), Cell.n(9), Cell.n(2), Cell(value: 8, item: CellItem.star)]);
      expect(greedyPairsToWin(s2, const [Goal(GoalType.star, 1)]), 1);
    });
    test('clearedCells refer to original indices', () {
      final b = Board.fromRows([
        [2, 8, 5],
        [1, 9, 5],
      ]);
      final r = s.solve(b, const [Goal(GoalType.number, 2, value: 5)], addNumbersLimit: 0);
      expect(r.solvable, isTrue);
      expect(r.clearedCells, {2, 5});
    });
  });
}
