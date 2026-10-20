/// Matching rules of Number Puzzle (pure Dart).
///
/// * Two numbers match if they are equal or sum to 10.
/// * They must be connected: on the same row, column or diagonal with only
///   empty cells between them, OR consecutive in reading order (left-to-right,
///   top-to-bottom, wrapping from the end of a row to the start of the next)
///   with only empty cells between them.
/// * Stone, slime and every number (including ice-covered ones) block lines.
/// * Ice-covered numbers are not selectable until their ice is broken; every
///   cleared cell removes 1 hp from each adjacent (8-neighbour) ice.
/// * Slime is removed when all 8 neighbours are empty.
/// * Rows that become completely empty are removed.
library;

import 'board.dart';
import 'cell.dart';

/// Values match if equal or summing to 10.
bool valuesMatch(int a, int b) => a == b || a + b == 10;

/// True if every cell strictly between [a] and [b] along the straight line
/// (horizontal, vertical or 45° diagonal) is empty. False if not on a line.
bool connectedInLine(Board board, int a, int b) {
  final dr = board.rowOf(b) - board.rowOf(a);
  final dc = board.colOf(b) - board.colOf(a);
  if (dr == 0 && dc == 0) return false;
  if (dr != 0 && dc != 0 && dr.abs() != dc.abs()) return false;
  final steps = dr.abs() > dc.abs() ? dr.abs() : dc.abs();
  final sr = dr.sign, sc = dc.sign;
  var r = board.rowOf(a), c = board.colOf(a);
  for (var k = 1; k < steps; k++) {
    r += sr;
    c += sc;
    if (!board.at(r, c).isEmpty) return false;
  }
  return true;
}

/// True if every cell strictly between [a] and [b] in reading order is empty
/// (this includes the row-wrap: last of a row to first of the next).
bool connectedInReadingOrder(Board board, int a, int b) {
  if (a == b) return false;
  final lo = a < b ? a : b, hi = a < b ? b : a;
  for (var i = lo + 1; i < hi; i++) {
    if (!board[i].isEmpty) return false;
  }
  return true;
}

bool areConnected(Board board, int a, int b) =>
    connectedInLine(board, a, b) || connectedInReadingOrder(board, a, b);

/// Full validity check for a player pair.
bool canPair(Board board, int a, int b) {
  if (a == b || a < 0 || b < 0 || a >= board.length || b >= board.length) {
    return false;
  }
  final ca = board[a], cb = board[b];
  if (!ca.isSelectable || !cb.isSelectable) return false;
  return valuesMatch(ca.value!, cb.value!) && areConnected(board, a, b);
}

/// All currently valid pairs (a < b). O(n²) – fine for ≤ 9×20 boards.
List<(int, int)> allValidPairs(Board board) => [
      for (var a = 0; a < board.length; a++)
        for (var b = a + 1; b < board.length; b++)
          if (canPair(board, a, b)) (a, b),
    ];

/// What happened when a pair was cleared; feeds [GoalProgress].
class PairResult {
  const PairResult({
    required this.board,
    required this.valueA,
    required this.valueB,
    this.starsCollected = 0,
    this.grassCollected = 0,
    this.iceBroken = 0,
    this.slimeRemoved = 0,
    this.rowsRemoved = 0,
  });

  final Board board;
  final int valueA;
  final int valueB;
  final int starsCollected;
  final int grassCollected;
  final int iceBroken;
  final int slimeRemoved;
  final int rowsRemoved;

  bool get isSamePair => valueA == valueB;
  bool get isTenPair => valueA + valueB == 10;
}

/// Clears a valid pair and resolves ice, slime and empty rows.
/// Throws [ArgumentError] if the pair is invalid.
PairResult applyPair(Board board, int a, int b) {
  if (!canPair(board, a, b)) {
    throw ArgumentError('Invalid pair $a,$b');
  }
  final ca = board[a], cb = board[b];
  var stars = 0, grass = 0;
  for (final c in [ca, cb]) {
    if (c.item == CellItem.star) stars++;
    if (c.grass) grass++;
  }
  var next = board.replace({a: const Cell.empty(), b: const Cell.empty()});
  final r = resolveAfterClear(next, [a, b]);
  return PairResult(
    board: r.board,
    valueA: ca.value!,
    valueB: cb.value!,
    starsCollected: stars,
    grassCollected: grass,
    iceBroken: r.iceBroken,
    slimeRemoved: r.slimeRemoved,
    rowsRemoved: r.rowsRemoved,
  );
}

/// Result of [resolveAfterClear].
typedef Resolution = ({Board board, int iceBroken, int slimeRemoved, int rowsRemoved});

/// Applies side effects of clearing [cleared] cells: damages adjacent ice
/// (1 hp per cleared neighbour), removes slime fully surrounded by empties,
/// then removes empty rows. Shared by pairs and the hammer booster.
Resolution resolveAfterClear(Board board, List<int> cleared) {
  final cells = List<Cell>.of(board.cells);
  var iceBroken = 0;
  for (final i in cleared) {
    for (final n in board.neighbours(i)) {
      final o = cells[n].obstacle;
      if (o != null && o.kind == ObstacleKind.ice && o.hp > 0) {
        final hp = o.hp - 1;
        if (hp <= 0) {
          cells[n] = cells[n].copyWith(clearObstacle: true);
          iceBroken++;
        } else {
          cells[n] = cells[n].copyWith(obstacle: o.withHp(hp));
        }
      }
    }
  }
  var b = Board(board.columns, cells);
  var slime = 0;
  final slimeChanges = <int, Cell>{};
  for (var i = 0; i < b.length; i++) {
    if (b[i].obstacle?.kind == ObstacleKind.slime &&
        b.neighbours(i).every((n) => b[n].isEmpty)) {
      slimeChanges[i] = const Cell.empty();
      slime++;
    }
  }
  if (slimeChanges.isNotEmpty) b = b.replace(slimeChanges);
  final before = b.rows;
  b = removeEmptyRows(b);
  return (board: b, iceBroken: iceBroken, slimeRemoved: slime, rowsRemoved: before - b.rows);
}

/// Removes every row whose cells are all empty (stones/slime keep a row).
Board removeEmptyRows(Board board) {
  final keep = <Cell>[];
  for (var r = 0; r < board.rows; r++) {
    final row = board.cells.sublist(r * board.columns, (r + 1) * board.columns);
    if (!row.every((c) => c.isEmpty)) keep.addAll(row);
  }
  return Board(board.columns, keep);
}

/// "Add numbers": appends a copy of every remaining number, in reading order,
/// right after the last non-empty cell; pads the final row with empties.
/// Copies are plain numbers (no items, grass or obstacles).
Board addNumbers(Board board) {
  final values = [for (final c in board.cells) if (c.value != null) c.value!];
  var last = board.length - 1;
  while (last >= 0 && board[last].isEmpty) {
    last--;
  }
  final cells = <Cell>[...board.cells.take(last + 1), for (final v in values) Cell.n(v)];
  while (cells.length % board.columns != 0) {
    cells.add(const Cell.empty());
  }
  return Board(board.columns, cells);
}
