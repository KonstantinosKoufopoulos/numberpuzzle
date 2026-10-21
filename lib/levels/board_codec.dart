/// Pre-baked board file codec (pure Dart, no Flutter imports).
/// Schema: docs/level-schema.md ("Pre-baked boards").
library;

import '../engine/board.dart';
import '../engine/cell.dart';
import '../engine/goals.dart';
import '../engine/moves.dart';

/// Schema version of assets/levels/boards.json.
const int kBoardsSchemaVersion = 1;

/// Encodes one cell: `{"n":d}` plus optional `"star":true`, `"grass":true`,
/// `"ice":hp`; obstacles without number: `{"stone":true}` / `{"slime":true}`.
Map<String, Object> encodeCell(Cell c) {
  final k = c.obstacle?.kind;
  if (k == ObstacleKind.stone) return {'stone': true};
  if (k == ObstacleKind.slime) return {'slime': true};
  return {
    if (c.value != null) 'n': c.value!,
    if (c.item == CellItem.star) 'star': true,
    if (c.grass) 'grass': true,
    if (k == ObstacleKind.ice) 'ice': c.obstacle!.hp,
  };
}

Cell decodeCell(Map<String, dynamic> j) {
  if (j['stone'] == true) return const Cell(obstacle: Obstacle.stone());
  if (j['slime'] == true) return const Cell(obstacle: Obstacle.slime());
  final ice = j['ice'] as int?;
  return Cell(
    value: j['n'] as int?,
    item: j['star'] == true ? CellItem.star : null,
    grass: j['grass'] == true,
    obstacle: ice == null ? null : Obstacle.ice(ice),
  );
}

/// Solution move: `[a, b]` = pair, `"add"` = Add numbers.
Object encodeMove(Move m) => switch (m) {
  PairMove(:final a, :final b) => [a, b],
  AddNumbersMove() => 'add',
  _ => throw ArgumentError('booster in solution line: $m'),
};

Move decodeMove(Object j) => j == 'add' ? const AddNumbersMove() : PairMove((j as List)[0] as int, j[1] as int);

/// One pre-baked level board.
class BakedBoard {
  const BakedBoard({
    required this.levelId,
    required this.seed,
    required this.seedUsed,
    required this.board,
    required this.goals,
    required this.solution,
    required this.metrics,
  });

  final int levelId;

  /// `Level.seed` and the reseeded seed that produced [board].
  final int seed;
  final int seedUsed;
  final Board board;
  final List<Goal> goals;

  /// Booster-free winning line (pairs + Add numbers).
  final List<Move> solution;

  /// Generator metrics (attempts, goalMinPairs, greedyPairs, ...).
  final Map<String, Object?> metrics;

  int get width => board.columns;
  int get height => board.rows;
  int get solutionLength => solution.length;

  factory BakedBoard.fromJson(Map<String, dynamic> j) {
    final w = j['width'] as int, h = j['height'] as int;
    final cells = [for (final c in (j['cells'] as List).cast<Map<String, dynamic>>()) decodeCell(c)];
    if (cells.length != w * h) throw FormatException('level ${j['id']}: ${cells.length} cells != $w x $h');
    final sol = [for (final m in j['solution'] as List) decodeMove(m as Object)];
    if (sol.length != j['solutionLength']) throw FormatException('level ${j['id']}: solutionLength mismatch');
    return BakedBoard(
      levelId: j['id'] as int,
      seed: j['seed'] as int,
      seedUsed: j['seedUsed'] as int,
      board: Board(w, cells),
      goals: [for (final g in (j['goals'] as List).cast<Map<String, dynamic>>()) Goal.fromJson(g)],
      solution: sol,
      metrics: Map<String, Object?>.from(j['metrics'] as Map),
    );
  }

  Map<String, Object?> toJson() => {
    'id': levelId,
    'seed': seed,
    'seedUsed': seedUsed,
    'width': width,
    'height': height,
    'cells': [for (final c in board.cells) encodeCell(c)],
    'goals': [for (final g in goals) g.toJson()],
    'solutionLength': solutionLength,
    'solution': [for (final m in solution) encodeMove(m)],
    'metrics': metrics,
  };
}

/// Parses the whole boards.json document; ids must be 1..N in order.
Map<int, BakedBoard> parseBoards(Map<String, dynamic> j) {
  final v = j['schemaVersion'];
  if (v != kBoardsSchemaVersion) throw FormatException('Unsupported boards schemaVersion $v');
  final out = <int, BakedBoard>{};
  for (final b in (j['boards'] as List).cast<Map<String, dynamic>>()) {
    final bb = BakedBoard.fromJson(b);
    if (bb.levelId != out.length + 1) throw const FormatException('board ids must be 1..N in order');
    out[bb.levelId] = bb;
  }
  return out;
}
