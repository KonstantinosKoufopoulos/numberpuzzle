/// Level board generator (M1).
///
/// Constraints (see docs/level-schema.md):
/// * Deterministic from `Level.seed` (own seeded PRNG, never `Random()`).
/// * Digits drawn with `Level.digitWeights` (uniform if null).
/// * Stones: never in corners, never fill a whole row.
/// * Slime: never adjacent to stone (nor to other slime or ice, so it can
///   always be uncovered).
/// * Ice (hp `hpMin..hpMax`): placed next to at least one free valid pair.
/// * Stars and grass only on cells the solver actually clears.
/// * If the solver fails, reseed (`seed + attempt`) and retry.
library;

import 'board.dart';
import 'cell.dart';
import 'goals.dart';
import 'level.dart';
import 'rules.dart';
import 'solver.dart';

abstract interface class BoardGenerator {
  /// Builds the starting board for [level].
  Board generate(Level level);
}

/// Deterministic 32-bit PRNG (mulberry32) – identical on every platform.
class SeededRng {
  SeededRng(int seed) : _s = seed & 0xFFFFFFFF;
  int _s;

  int nextUint32() {
    _s = (_s + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _s;
    t = _imul(t ^ (t >> 15), t | 1);
    t ^= (t + _imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF;
    return (t ^ (t >> 14)) & 0xFFFFFFFF;
  }

  static int _imul(int a, int b) => (a * b) & 0xFFFFFFFF;

  /// Uniform int in `[0, max)`.
  int nextInt(int max) => nextUint32() % max;
  double nextDouble() => nextUint32() / 4294967296.0;

  void shuffle<T>(List<T> l) {
    for (var i = l.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final t = l[i];
      l[i] = l[j];
      l[j] = t;
    }
  }
}

/// Output of [SeededBoardGenerator.generateDetailed].
class GeneratedLevel {
  const GeneratedLevel({
    required this.board,
    required this.seedUsed,
    required this.attempts,
    required this.solution,
  });
  final Board board;

  /// The seed that produced [board] (`level.seed + attempts - 1`).
  final int seedUsed;
  final int attempts;

  /// Booster-free winning line verified on [board].
  final SolveResult solution;
}

class SeededBoardGenerator implements BoardGenerator {
  const SeededBoardGenerator({this.maxReseeds = 50, this.solver = const DfsSolver(nodeBudget: 20000)});
  final int maxReseeds;
  final DfsSolver solver;

  @override
  Board generate(Level level) => generateDetailed(level).board;

  /// Generates and verifies; throws [StateError] after [maxReseeds] failures.
  GeneratedLevel generateDetailed(Level level) {
    for (var attempt = 0; attempt < maxReseeds; attempt++) {
      final seed = level.seed + attempt;
      final r = tryGenerate(level, seed);
      if (r != null) {
        return GeneratedLevel(board: r.$1, seedUsed: seed, attempts: attempt + 1, solution: r.$2);
      }
    }
    throw StateError('Level ${level.id}: no solvable board after $maxReseeds seeds');
  }

  /// One attempt with [seed]; null if the board is not provably solvable.
  (Board, SolveResult)? tryGenerate(Level level, int seed) {
    final rng = SeededRng(seed);
    final cols = level.columns, rows = level.rows, n = cols * rows;
    final l = level.layers;
    final weights = level.digitWeights ?? List.filled(9, 1.0);
    final total = weights.fold(0.0, (s, w) => s + w);
    int digit() {
      var x = rng.nextDouble() * total;
      for (var d = 0; d < 9; d++) {
        x -= weights[d];
        if (x < 0) return d + 1;
      }
      return 9;
    }

    final cells = List<Cell>.generate(n, (_) => Cell.n(digit()));
    int rowOf(int i) => i ~/ cols;
    int colOf(int i) => i % cols;
    bool isCorner(int i) =>
        (rowOf(i) == 0 || rowOf(i) == rows - 1) && (colOf(i) == 0 || colOf(i) == cols - 1);
    final grid = Board(cols, cells);
    List<int> nb(int i) => grid.neighbours(i).toList();
    final kind = List<ObstacleKind?>.filled(n, null);

    // Stones.
    final order = List<int>.generate(n, (i) => i);
    rng.shuffle(order);
    var placed = 0;
    for (final i in order) {
      if (placed >= l.stone) break;
      if (isCorner(i)) continue;
      final r = rowOf(i);
      final inRow = [
        for (var c = 0; c < cols; c++) kind[r * cols + c],
      ].where((k) => k == ObstacleKind.stone).length;
      if (inRow + 1 >= cols) continue;
      kind[i] = ObstacleKind.stone;
      cells[i] = const Cell(obstacle: Obstacle.stone());
      placed++;
    }
    if (placed < l.stone) return null;

    // Slime: never next to stone, slime (would never clear) or the board's
    // corner cells (keeps it reachable).
    rng.shuffle(order);
    placed = 0;
    for (final i in order) {
      if (placed >= l.slime) break;
      if (kind[i] != null || isCorner(i)) continue;
      if (nb(i).any((x) => kind[x] != null)) continue;
      kind[i] = ObstacleKind.slime;
      cells[i] = const Cell(obstacle: Obstacle.slime());
      placed++;
    }
    if (placed < l.slime) return null;

    // Ice: next to at least one cell of a currently free valid pair.
    rng.shuffle(order);
    placed = 0;
    for (final i in order) {
      if (placed >= l.ice.count) break;
      if (kind[i] != null) continue;
      if (nb(i).any((x) => kind[x] == ObstacleKind.slime)) continue;
      final hp = l.ice.hpMin + rng.nextInt(l.ice.hpMax - l.ice.hpMin + 1);
      final old = cells[i];
      cells[i] = Cell(value: old.value, obstacle: Obstacle.ice(hp));
      if (!_iceHasFreePairNeighbour(Board(cols, cells), i)) {
        cells[i] = old;
        continue;
      }
      kind[i] = ObstacleKind.ice;
      placed++;
    }
    if (placed < l.ice.count) return null;
    // Re-check all ice once everything is placed.
    final withIce = Board(cols, cells);
    for (var i = 0; i < n; i++) {
      if (kind[i] == ObstacleKind.ice && !_iceHasFreePairNeighbour(withIce, i)) return null;
    }

    // Phase 1: solve with stars/grass replaced by "clear S+G original cells"
    // (a star marker on every eligible cell).
    final sg = l.stars + l.grass;
    final phaseGoals = <Goal>[
      for (final g in level.goals)
        if (g.type != GoalType.star && g.type != GoalType.grass) g,
      if (sg > 0) Goal(GoalType.star, sg),
    ];
    final marked = [
      for (var i = 0; i < n; i++) kind[i] == null ? cells[i].copyWith(item: CellItem.star) : cells[i],
    ];
    final p1 = solver.solve(sg > 0 ? Board(cols, marked) : withIce, phaseGoals);
    if (!p1.solvable) return null;

    // Place stars and grass on cleared plain cells.
    final eligible = p1.clearedCells.where((i) => kind[i] == null).toList()..sort();
    rng.shuffle(eligible);
    if (eligible.length < sg) return null;
    final finalCells = List<Cell>.of(cells);
    for (var k = 0; k < l.stars; k++) {
      finalCells[eligible[k]] = finalCells[eligible[k]].copyWith(item: CellItem.star);
    }
    for (var k = l.stars; k < sg; k++) {
      finalCells[eligible[k]] = finalCells[eligible[k]].copyWith(grass: true);
    }
    final board = Board(cols, finalCells);

    // Verify the real board with the solver (independent proof).
    final p2 = sg > 0 ? solver.solve(board, level.goals) : p1;
    if (!p2.solvable) return null;
    return (board, p2);
  }

  static bool _iceHasFreePairNeighbour(Board b, int ice) {
    final touching = b.neighbours(ice).toSet();
    for (final (x, y) in fastValidPairs(b)) {
      if (touching.contains(x) || touching.contains(y)) return true;
    }
    return false;
  }
}

/// Replays [moves] (pairs / add numbers) from [board] and reports whether
/// [goals] are met within [addNumbersLimit] adds. Used to double-check
/// solver lines.
bool verifyLine(Board board, List<Goal> goals, List<Object> moves, {int addNumbersLimit = solverAddLimit}) {
  var b = board;
  final p = GoalProgress(goals);
  var adds = 0;
  for (final m in moves) {
    if (m is (int, int)) {
      if (!canPair(b, m.$1, m.$2)) return false;
      final r = applyPair(b, m.$1, m.$2);
      p.onPair(r);
      b = r.board;
    } else {
      if (++adds > addNumbersLimit) return false;
      b = addNumbers(b);
    }
  }
  return p.isComplete;
}
