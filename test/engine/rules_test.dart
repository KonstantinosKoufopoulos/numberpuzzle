import 'package:numberpuzzle/engine/board.dart';
import 'package:numberpuzzle/engine/cell.dart';
import 'package:numberpuzzle/engine/rules.dart';
import 'package:test/test.dart';

const int? _ = null;

void main() {
  group('valuesMatch', () {
    test('equal', () => expect(valuesMatch(4, 4), isTrue));
    test('sum 10', () => expect(valuesMatch(3, 7), isTrue));
    test('5+5', () => expect(valuesMatch(5, 5), isTrue));
    test('no match', () => expect(valuesMatch(3, 6), isFalse));
  });

  group('directions', () {
    final b = Board.fromRows([
      [1, _, _, 1, 2],
      [_, 3, _, _, 4],
      [_, _, 1, _, 6],
      [9, _, _, _, 8],
    ]);
    test('horizontal over empties', () => expect(canPair(b, 0, 3), isTrue));
    test('vertical over empties', () {
      final v = Board.fromRows([
        [2, 1],
        [_, 3],
        [8, 4],
      ]);
      expect(canPair(v, 0, 4), isTrue);
    });
    test('diagonal down-right blocked by 3', () => expect(canPair(b, 0, 12), isFalse));
    test('diagonal down-left', () {
      final d = Board.fromRows([
        [_, _, 4],
        [_, _, _],
        [6, _, _],
      ]);
      expect(canPair(d, 2, 6), isTrue);
    });
    test('vertical adjacent', () => expect(canPair(b, 9, 14), isTrue)); // 4 & 6
    test('not on a line and not reading-adjacent', () => expect(canPair(b, 0, 9), isFalse));
    test('non-matching values', () => expect(canPair(b, 3, 4), isFalse));
    test('same cell invalid', () => expect(canPair(b, 0, 0), isFalse));
  });

  group('blocking', () {
    test('number between blocks horizontal', () {
      final b = Board.fromRows([
        [1, 2, 1],
      ]);
      expect(canPair(b, 0, 2), isFalse);
    });
    test('stone blocks like a number', () {
      final b = Board.fromRows([
        [1, 0, 1],
        [1, _, _],
      ]);
      expect(canPair(b, 0, 2), isFalse);
      expect(b[1].isSelectable, isFalse);
    });
    test('stone blocks vertical and diagonal', () {
      final b = Board.fromRows([
        [1, _, 1],
        [_, 0, _],
        [1, _, 9],
      ]);
      expect(canPair(b, 0, 8), isFalse);
      expect(canPair(b, 0, 6), isTrue);
    });
  });

  group('row wrap / reading order', () {
    test('last of row to first of next', () {
      final b = Board.fromRows([
        [5, 2, 3],
        [7, 4, 6],
      ]);
      expect(canPair(b, 2, 3), isTrue); // 3 & 7
    });
    test('wrap over empties', () {
      final b = Board.fromRows([
        [8, 1, _],
        [_, 4, 2],
      ]);
      expect(canPair(b, 1, 4), isFalse); // 1 & 4 no match
      expect(canPair(b, 1, 5), isFalse); // 4 in between in reading order
      final c = Board.fromRows([
        [8, 1, _],
        [_, 9, 2],
      ]);
      expect(canPair(c, 1, 4), isTrue);
    });
    test('wrap blocked', () {
      final b = Board.fromRows([
        [3, 1, 2],
        [7, 4, 6],
      ]);
      expect(canPair(b, 0, 3), isTrue); // vertical
      expect(canPair(b, 1, 3), isFalse); // 2 between, not on line
    });
  });

  group('applyPair', () {
    test('clears cells and removes empty rows', () {
      final b = Board.fromRows([
        [1, 9, _],
        [2, 3, 4],
      ]);
      final r = applyPair(b, 0, 1);
      expect(r.rowsRemoved, 1);
      expect(r.board.rows, 1);
      expect(r.board.cells.map((c) => c.value), [2, 3, 4]);
      expect(r.isTenPair, isTrue);
    });
    test('row with stone is not removed', () {
      final b = Board.fromRows([
        [1, 1, 0],
        [2, 3, 4],
      ]);
      expect(applyPair(b, 0, 1).board.rows, 2);
    });
    test('middle row removal keeps order', () {
      final b = Board.fromRows([
        [2, _, _],
        [6, 4, _],
        [8, _, _],
      ]);
      final r = applyPair(b, 3, 4);
      expect(r.board.rows, 2);
      expect(r.board.cells.map((c) => c.value), [2, null, null, 8, null, null]);
    });
    test('invalid pair throws', () {
      final b = Board.fromRows([
        [1, 2],
      ]);
      expect(() => applyPair(b, 0, 1), throwsArgumentError);
    });
    test('collects stars and grass', () {
      final b = Board(3, const [
        Cell(value: 4, item: CellItem.star),
        Cell(value: 6, grass: true),
        Cell.n(1),
      ]);
      final r = applyPair(b, 0, 1);
      expect(r.starsCollected, 1);
      expect(r.grassCollected, 1);
    });
  });

  group('ice', () {
    test('ice-covered number not selectable', () {
      final b = Board(3, const [Cell.n(4), Cell(value: 4, obstacle: Obstacle.ice(1)), Cell.n(5)]);
      expect(b[1].isSelectable, isFalse);
      expect(canPair(b, 0, 1), isFalse);
    });
    test('adjacent clear breaks hp1 ice, then selectable', () {
      final b = Board(4, const [
        Cell.n(3), Cell.n(7), Cell(value: 2, obstacle: Obstacle.ice(1)), Cell.n(8),
      ]);
      final r = applyPair(b, 0, 1);
      expect(r.iceBroken, 1);
      expect(r.board[2].obstacle, isNull);
      expect(canPair(r.board, 2, 3), isTrue);
    });
    test('hp2 ice needs two hits (1 hp per adjacent cleared cell)', () {
      final b = Board(4, const [
        Cell(value: 9, obstacle: Obstacle.ice(2)), Cell.n(1), Cell.empty(), Cell.n(1),
      ]);
      final r = applyPair(b, 1, 3);
      expect(r.board[0].obstacle, const Obstacle.ice(1));
      expect(r.iceBroken, 0);
      final c = Board(3, const [
        Cell(value: 9, obstacle: Obstacle.ice(2)), Cell.n(4), Cell.n(2),
        Cell.n(6), Cell.n(3), Cell.n(8),
      ]);
      final r2 = applyPair(c, 1, 3); // both cleared cells touch the ice
      expect(r2.iceBroken, 1);
      expect(r2.board[0].isSelectable, isTrue);
    });
    test('ice blocks lines', () {
      final b = Board(3, const [Cell.n(1), Cell(value: 2, obstacle: Obstacle.ice(1)), Cell.n(1)]);
      expect(canPair(b, 0, 2), isFalse);
    });
  });

  group('slime', () {
    test('removed when all 8 neighbours empty', () {
      final b = Board(3, const [
        Cell.n(1), Cell(obstacle: Obstacle.slime()), Cell.n(9),
      ]);
      // 1 and 9 separated by slime: not connected horizontally.
      expect(canPair(b, 0, 2), isFalse);
      final c = Board(3, const [
        Cell.n(1), Cell(obstacle: Obstacle.slime()), Cell.empty(),
        Cell.n(9), Cell.empty(), Cell.empty(),
      ]);
      final r = applyPair(c, 0, 3);
      expect(r.slimeRemoved, 1);
      expect(r.board.rows, 0);
    });
    test('stays while a neighbour has a number', () {
      final c = Board(3, const [
        Cell.n(1), Cell(obstacle: Obstacle.slime()), Cell.n(4),
        Cell.n(9), Cell.empty(), Cell.empty(),
      ]);
      final r = applyPair(c, 0, 3);
      expect(r.slimeRemoved, 0);
      expect(r.board[1].obstacle?.kind, ObstacleKind.slime);
    });
  });

  group('addNumbers', () {
    test('appends remaining numbers after last non-empty cell', () {
      final b = Board.fromRows([
        [1, _, 3],
        [_, _, _],
      ]);
      final a = addNumbers(b);
      expect(a.cells.map((c) => c.value), [1, null, 3, 1, 3, null]);
    });
  });

  test('allValidPairs', () {
    final b = Board.fromRows([
      [1, 9, 2],
    ]);
    expect(allValidPairs(b), [(0, 1)]);
  });
}
