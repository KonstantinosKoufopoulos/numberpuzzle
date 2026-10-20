import 'cell.dart';

/// Immutable rectangular grid stored row-major. Rows may grow when numbers
/// are added and shrink when a row becomes completely empty.
class Board {
  Board(this.columns, List<Cell> cells)
      : assert(columns > 0),
        assert(cells.length % columns == 0),
        cells = List.unmodifiable(cells);

  /// Builds a board from rows of ints; `null` = empty, `0` = stone (tests).
  factory Board.fromRows(List<List<int?>> rows) {
    final cols = rows.first.length;
    final cells = <Cell>[
      for (final r in rows)
        for (final v in r)
          v == null
              ? const Cell.empty()
              : v == 0
                  ? const Cell(obstacle: Obstacle.stone())
                  : Cell.n(v),
    ];
    return Board(cols, cells);
  }

  /// Default classic width.
  static const int classicColumns = 9;

  final int columns;
  final List<Cell> cells;

  int get rows => cells.length ~/ columns;
  int get length => cells.length;

  int index(int row, int col) => row * columns + col;
  int rowOf(int i) => i ~/ columns;
  int colOf(int i) => i % columns;
  bool inBounds(int row, int col) =>
      row >= 0 && row < rows && col >= 0 && col < columns;

  Cell operator [](int i) => cells[i];
  Cell at(int row, int col) => cells[index(row, col)];

  /// Indices of the (up to 8) neighbours of [i].
  Iterable<int> neighbours(int i) sync* {
    final r = rowOf(i), c = colOf(i);
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if ((dr != 0 || dc != 0) && inBounds(r + dr, c + dc)) {
          yield index(r + dr, c + dc);
        }
      }
    }
  }

  Board replace(Map<int, Cell> changes) {
    final next = List<Cell>.of(cells);
    changes.forEach((i, c) => next[i] = c);
    return Board(columns, next);
  }

  bool get isCleared => cells.every((c) => c.value == null);

  @override
  String toString() => [
        for (var r = 0; r < rows; r++)
          cells.sublist(r * columns, (r + 1) * columns).join(' ')
      ].join('\n');
}
