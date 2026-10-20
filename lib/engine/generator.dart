/// Level board generator (M1 – Nionios).
///
/// Constraints (see docs/level-schema.md):
/// * Deterministic from `Level.seed` (use a seeded PRNG, never `Random()`).
/// * Digits drawn with `Level.digitWeights` (uniform if null).
/// * Stones: never in corners, never fill a whole row.
/// * Slime: never adjacent to stone.
/// * Ice (hp `hpMin..hpMax`): placed next to at least one free valid pair.
/// * Stars and grass only on cells the solver actually clears.
/// * If [Solver.isSolvable] fails, reseed (`seed + attempt`) and retry.
library;

import 'board.dart';
import 'level.dart';

abstract interface class BoardGenerator {
  /// Builds the starting board for [level].
  Board generate(Level level);
}

/// TODO(M1, Nionios): implement.
class SeededBoardGenerator implements BoardGenerator {
  const SeededBoardGenerator({this.maxReseeds = 50});
  final int maxReseeds;

  @override
  Board generate(Level level) => throw UnimplementedError('M1');
}
