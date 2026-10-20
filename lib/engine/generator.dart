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
import 'moves.dart';
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
    this.latePlacement = true,
    this.placementLine = const SolveResult(solvable: false),
    this.goalMinPairs,
    this.goalMinPairsTarget,
    this.goalMinPairsMet,
    this.greedyRejects = 0,
  });

  /// Seeds rejected by the `requireGreedyWinLevels` flag.
  final int greedyRejects;

  /// Star/grass levels only: proven "no way to collect all star+grass goals
  /// in fewer than this many pairs" (no Add numbers; capped at the target).
  final int? goalMinPairs;
  final int? goalMinPairsTarget;

  /// Null for levels without star/grass goals; false = best-effort board.
  final bool? goalMinPairsMet;

  /// Phase-1 line (board without stars/grass) whose cleared cells received
  /// the stars/grass.
  final SolveResult placementLine;
  final Board board;

  /// The seed that produced [board] (`level.seed + attempts - 1`).
  final int seedUsed;
  final int attempts;

  /// Always true for boards from [SeededBoardGenerator.generateDetailed]
  /// (no fallback; failures throw).
  final bool latePlacement;

  /// Booster-free winning line verified on [board].
  final SolveResult solution;
}

class SeededBoardGenerator implements BoardGenerator {
  const SeededBoardGenerator({
    this.maxReseeds = 50,
    this.solver = const DfsSolver(nodeBudget: 20000),
    this.minPairs = 0,
    this.minPairsNodeBudget = 20000,
    this.levelNodeBudget = 3000000,
    this.goalMinPairsTargets = kGoalMinPairsTargets,
    this.requireGreedyWinLevels = kRequireGreedyWinLevels,
  });

  /// UX flag (revertible): level ids whose board must be won by the cheap
  /// greedy player (`greedyPairsToWin != null`, no boosters, level's Add
  /// numbers limit); otherwise reseed. Pass `{}` to disable.
  static const Set<int> kRequireGreedyWinLevels = {1, 2, 3, 4, 5, 6, 15, 25};
  final Set<int> requireGreedyWinLevels;

  /// Level id -> goal-minPairs target (other star/grass levels use
  /// [kDefaultGoalMinPairs]).
  final Map<int, int> goalMinPairsTargets;
  final int maxReseeds;
  final DfsSolver solver;

  /// Difficulty floor: reject boards whose goals can be met with fewer than
  /// [minPairs] pairs. 0 disables the check. Checked with the depth-limited
  /// [shortWinCheck] (memo, no exhaustive proof); exhausting
  /// [minPairsNodeBudget] rejects the board and reseeds. Generator/CI only.
  final int minPairs;
  final int minPairsNodeBudget;

  /// Deterministic per-level cap on solver + check nodes summed over all
  /// attempts (both placement modes); exceeding it throws [StateError].
  final int levelNodeBudget;

  @override
  Board generate(Level level) => generateDetailed(level).board;

  /// Goal-minPairs targets: min pairs (no Add numbers) to collect ALL
  /// star+grass goals.
  static const Map<int, int> kGoalMinPairsTargets = {7: 5, 8: 5, 15: 4, 25: 4, 22: 7};
  static const int kDefaultGoalMinPairs = 4;

  /// A best-effort board must still need at least this many pairs.
  static const int kGoalMinPairsFloor = 3;

  /// Node budget per `shortWinCheck` depth for the goal-minPairs check.
  static const int kGoalMinPairsCheckNodes = 10000;

  /// Generates and verifies; throws [StateError] (no fallback) when no board
  /// passes within [maxReseeds] seeds / [levelNodeBudget] nodes.
  GeneratedLevel generateDetailed(Level level) {
    final sgGoals = [
      for (final g in level.goals)
        if (g.type == GoalType.star || g.type == GoalType.grass) g,
    ];
    final target = sgGoals.isEmpty ? null : (goalMinPairsTargets[level.id] ?? kDefaultGoalMinPairs);
    final budget = _Budget();
    GeneratedLevel? best;
    for (var attempt = 0; attempt < maxReseeds; attempt++) {
      if (budget.used > levelNodeBudget) break;
      final seed = level.seed + attempt;
      final r = _tryGenerate(level, seed, true, budget, true);
      if (r == null) continue;
      GeneratedLevel make(int? floor, bool? met) => GeneratedLevel(
        board: r.$1,
        seedUsed: seed,
        attempts: attempt + 1,
        solution: r.$2,
        placementLine: r.$3,
        goalMinPairs: floor,
        goalMinPairsTarget: target,
        goalMinPairsMet: met,
        greedyRejects: budget.greedyRejects,
      );
      if (target == null) return make(null, null);
      final floor = goalMinPairsFloor(r.$1, sgGoals, target, onNodes: (n) => budget.used += n);
      if (floor >= target) return make(floor, true);
      if (floor >= kGoalMinPairsFloor && (best == null || floor > best.goalMinPairs!)) {
        best = make(floor, false);
      }
    }
    if (best != null) return best;
    throw StateError(
      'Level ${level.id}: no valid board within $maxReseeds seeds / $levelNodeBudget nodes '
      '(late placement, first-pair rule${target == null ? '' : ', goal-minPairs >= $kGoalMinPairsFloor'}; '
      'no fallback)',
    );
  }

  /// Largest k <= [target] such that [sgGoals] provably cannot be met with
  /// fewer than k pairs (no Add numbers, fixed node budget per depth).
  static int goalMinPairsFloor(
    Board board,
    List<Goal> sgGoals,
    int target, {
    void Function(int)? onNodes,
    int nodeBudget = kGoalMinPairsCheckNodes,
  }) {
    var floor = 1;
    for (var k = 1; k < target; k++) {
      final c = shortWinCheck(
        board,
        sgGoals,
        k,
        addNumbersLimit: 0,
        nodeBudget: nodeBudget,
        onNodes: onNodes,
      );
      if (c != ShortWinCheck.notWinnableWithin) break;
      floor = k + 1;
    }
    return floor;
  }

  /// First-pair rule: true if no star/grass cell is part of any valid pair
  /// on [board] (depth 1, no Add numbers).
  static bool noFirstPairCollect(Board board) {
    for (final (a, b) in fastValidPairs(board)) {
      for (final c in [board[a], board[b]]) {
        if (c.item == CellItem.star || c.grass) return false;
      }
    }
    return true;
  }

  /// Reorders [cands] so the first [k] are spread apart: greedily pick the
  /// candidate maximizing the min Chebyshev distance to those already picked
  /// (ties keep the shuffled order).
  static List<int> _spreadOut(List<int> cands, int k, int cols) {
    int d(int a, int b) {
      final dr = (a ~/ cols - b ~/ cols).abs(), dc = (a % cols - b % cols).abs();
      return dr > dc ? dr : dc;
    }

    final picked = <int>[cands.first];
    final rest = cands.sublist(1);
    while (picked.length < k && rest.isNotEmpty) {
      var bi = 0, bd = -1;
      for (var i = 0; i < rest.length; i++) {
        var m = 1 << 20;
        for (final p in picked) {
          final x = d(rest[i], p);
          if (x < m) m = x;
        }
        if (m > bd) {
          bd = m;
          bi = i;
        }
      }
      picked.add(rest.removeAt(bi));
    }
    return [...picked, ...rest];
  }

  /// One attempt with [seed]; null if the board is not provably solvable.
  /// First pair index (0-based) counted as "late" in a line of [pairs] pairs:
  /// the last 50% of the line and never one of the first 3 pairs.
  static int latePairIndex(int pairs) {
    final half = pairs ~/ 2;
    return half > 3 ? half : 3;
  }

  /// With [late] (default) stars/grass go only on cells cleared in the late
  /// part of the phase-1 line (see [latePairIndex]); otherwise anywhere on it.
  (Board, SolveResult, SolveResult)? tryGenerate(Level level, int seed, {bool late = true}) =>
      _tryGenerate(level, seed, late, _Budget(), true);

  (Board, SolveResult, SolveResult)? _tryGenerate(
    Level level,
    int seed,
    bool late,
    _Budget budget,
    bool spread,
  ) {
    void count(int n) => budget.used += n;
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

    // Phase 1: solve the board without stars/grass, replacing those goals by
    // "clear N original cells" (a star marker on every plain cell), with N
    // large enough that the late part of the line has room for them.
    final sg = l.stars + l.grass;
    final plain = [
      for (var i = 0; i < n; i++)
        if (kind[i] == null) i,
    ].length;
    List<int>? eligible;
    SolveResult? p1;
    // First-pair rule: cells in any valid first pair never get stars/grass.
    final early = late && sg > 0
        ? {
            for (final (x, y) in fastValidPairs(withIce)) ...[x, y],
          }
        : const <int>{};
    final targets = sg == 0
        ? const [0]
        : late
        ? {
            for (final t in [2 * sg + 6, 3 * sg + 6, 4 * sg + 8, plain]) t < plain ? t : plain,
          }.toList()
        : [sg];
    for (final target in targets) {
      final phaseGoals = <Goal>[
        for (final g in level.goals)
          if (g.type != GoalType.star && g.type != GoalType.grass) g,
        if (target > 0) Goal(GoalType.star, target),
      ];
      final marked = [
        for (var i = 0; i < n; i++) kind[i] == null ? cells[i].copyWith(item: CellItem.star) : cells[i],
      ];
      final r = solver.solve(sg > 0 ? Board(cols, marked) : withIce, phaseGoals);
      count(r.nodes);
      // Larger targets are strictly harder: stop at the first failure.
      if (!r.solvable) break;
      final pairs = r.moves.whereType<PairMove>().length;
      final firstLate = late ? latePairIndex(pairs) : 0;
      final e = [
        for (var k = 0; k < r.clearOrder.length; k++)
          if (kind[r.clearOrder[k]] == null &&
              r.clearPairIndex[k] >= firstLate &&
              !early.contains(r.clearOrder[k]))
            r.clearOrder[k],
      ];
      if (e.length < sg) continue;
      p1 = r;
      eligible = e;
      break;
    }
    if (p1 == null || eligible == null) return null;
    rng.shuffle(eligible);
    if (spread && l.stars > 1) eligible = _spreadOut(eligible, l.stars, cols);
    final finalCells = List<Cell>.of(cells);
    for (var k = 0; k < l.stars; k++) {
      finalCells[eligible[k]] = finalCells[eligible[k]].copyWith(item: CellItem.star);
    }
    for (var k = l.stars; k < sg; k++) {
      finalCells[eligible[k]] = finalCells[eligible[k]].copyWith(grass: true);
    }
    final board = Board(cols, finalCells);

    // Verify the real board with the solver (independent proof).
    if (late && sg > 0 && !noFirstPairCollect(board)) return null;
    final p2 = sg > 0 ? solver.solve(board, level.goals) : p1;
    if (sg > 0) count(p2.nodes);
    if (!p2.solvable) return null;
    if (requireGreedyWinLevels.contains(level.id) &&
        greedyPairsToWin(board, level.goals, addNumbersLimit: level.addNumbersLimit) == null) {
      budget.greedyRejects++;
      return null;
    }
    if (minPairs > 1 &&
        shortWinCheck(board, level.goals, minPairs - 1, nodeBudget: minPairsNodeBudget, onNodes: count) !=
            ShortWinCheck.notWinnableWithin) {
      return null;
    }
    return (board, p2, p1);
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

class _Budget {
  int used = 0;
  int greedyRejects = 0;
}
