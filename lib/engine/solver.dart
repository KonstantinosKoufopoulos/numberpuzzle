/// Solver used by the generator to prove a level is winnable (M1).
///
/// The solver MUST prove that all goals are reachable WITHOUT boosters
/// (hammer/swap/hint) and WITHOUT rewarded ads, using at most
/// [solverAddLimit] "Add numbers" uses (stricter than the in-game
/// default `kDefaultAddNumbersLimit` = 5, leaving the player slack).
///
/// Search: depth-first with a node budget, a memo of visited states
/// (board + goal progress + adds used), a beam on the branching factor and
/// goal-driven move ordering. "Add numbers" is only tried after the pairs of
/// a node. Dead states are pruned when a goal can no longer be met.
library;

import 'board.dart';
import 'cell.dart';
import 'goals.dart';
import 'moves.dart';
import 'rules.dart';

/// Max "Add numbers" the solver may use to prove solvability.
const int solverAddLimit = 3;

class SolveResult {
  const SolveResult({
    required this.solvable,
    this.moves = const [],
    this.clearedCells = const {},
    this.nodes = 0,
    this.clearOrder = const [],
    this.clearPairIndex = const [],
  });
  final bool solvable;

  /// A winning line (pairs + add-numbers only), with indices valid on the
  /// board at the time each move is played.
  final List<Move> moves;

  /// Indices (on the starting board) of original cells whose numbers are
  /// cleared along the line; the generator places stars/grass only here.
  final Set<int> clearedCells;

  /// Same cells as [clearedCells], in the order they are cleared.
  final List<int> clearOrder;

  /// For each entry of [clearOrder], the 0-based index of the pair (in the
  /// line, Add numbers not counted) that cleared it.
  final List<int> clearPairIndex;

  /// Search nodes expanded.
  final int nodes;
}

abstract interface class Solver {
  /// Searches for a booster-free line reaching all [goals].
  SolveResult solve(Board board, List<Goal> goals, {int addNumbersLimit = solverAddLimit});
}

/// Fast enumeration of all valid pairs (a < b), equivalent to
/// `allValidPairs` but O(n · rows) instead of O(n²).
List<(int, int)> fastValidPairs(Board board) {
  final out = <(int, int)>[];
  final n = board.length, cols = board.columns, rows = board.rows;
  const dirs = [(0, 1), (1, -1), (1, 0), (1, 1)];
  for (var a = 0; a < n; a++) {
    final ca = board[a];
    if (!ca.isSelectable) continue;
    final va = ca.value!;
    final found = <int>{};
    void consider(int b) {
      final cb = board[b];
      if (cb.isSelectable && valuesMatch(va, cb.value!) && found.add(b)) out.add((a, b));
    }

    // Reading order forward.
    for (var b = a + 1; b < n; b++) {
      if (!board[b].isEmpty) {
        consider(b);
        break;
      }
    }
    final r0 = a ~/ cols, c0 = a % cols;
    for (final (dr, dc) in dirs) {
      var r = r0 + dr, c = c0 + dc;
      while (r < rows && c >= 0 && c < cols) {
        final b = r * cols + c;
        if (!board[b].isEmpty) {
          consider(b);
          break;
        }
        r += dr;
        c += dc;
      }
    }
  }
  return out;
}

/// Search state carried by the solver.
class _Node {
  _Node(this.board, this.ids, this.progress, this.adds);
  final Board board;

  /// Original-board index of each cell, or -1 for cells added later.
  final List<int> ids;
  final GoalProgress progress;
  final int adds;
}

/// Applies a pair, returning the new board, ids and the pair result.
(PairResult, List<int>) _applyWithIds(Board board, List<int> ids, int a, int b) {
  final r = applyPair(board, a, b);
  // Recompute which rows survived (mirrors resolveAfterClear).
  final p = board.replace({a: const Cell.empty(), b: const Cell.empty()});
  final emptyAfter = List<bool>.generate(p.length, (i) => p[i].isEmpty);
  for (var i = 0; i < p.length; i++) {
    if (p[i].obstacle?.kind == ObstacleKind.slime && p.neighbours(i).every((x) => p[x].isEmpty)) {
      emptyAfter[i] = true;
    }
  }
  final next = <int>[];
  for (var row = 0; row < p.rows; row++) {
    final s = row * p.columns;
    var allEmpty = true;
    for (var k = 0; k < p.columns; k++) {
      if (!emptyAfter[s + k]) {
        allEmpty = false;
        break;
      }
    }
    if (!allEmpty) next.addAll(ids.sublist(s, s + p.columns));
  }
  assert(next.length == r.board.length);
  return (r, next);
}

List<int> _idsAfterAdd(Board before, List<int> ids, Board after) {
  var last = before.length - 1;
  while (last >= 0 && before[last].isEmpty) {
    last--;
  }
  return [...ids.take(last + 1), for (var i = last + 1; i < after.length; i++) -1];
}

class DfsSolver implements Solver {
  const DfsSolver({this.nodeBudget = 200000, this.beamWidth = 8});

  /// Max nodes expanded before giving up (returns unsolvable).
  final int nodeBudget;

  /// Max pairs tried per node (best-scored first).
  final int beamWidth;

  @override
  SolveResult solve(Board board, List<Goal> goals, {int addNumbersLimit = solverAddLimit}) =>
      solveFrom(board, GoalProgress(goals), addNumbersLimit: addNumbersLimit);

  /// Like [solve] but starting from existing [progress].
  SolveResult solveFrom(Board board, GoalProgress progress, {int addNumbersLimit = solverAddLimit}) {
    final root = _Node(board, List<int>.generate(board.length, (i) => i), progress.copy(), 0);
    if (progress.isComplete) return const SolveResult(solvable: true);
    final seen = <String>{};
    final path = <Move>[];
    final cleared = <int>[];
    final clearedAt = <int>[];
    var pairDepth = 0;
    var nodes = 0;

    bool dfs(_Node s) {
      if (++nodes > nodeBudget) return false;
      if (!seen.add(_key(s))) return false;
      if (_dead(s, addNumbersLimit)) return false;
      final pairs = fastValidPairs(s.board);
      final scored = <((int, int), double)>[for (final p in pairs) (p, _score(s, p.$1, p.$2))]
        ..sort((x, y) => y.$2.compareTo(x.$2));
      for (final (p, _) in scored.take(beamWidth)) {
        final (r, ids) = _applyWithIds(s.board, s.ids, p.$1, p.$2);
        final prog = s.progress.copy()..onPair(r);
        path.add(PairMove(p.$1, p.$2));
        final mark = cleared.length;
        for (final id in [s.ids[p.$1], s.ids[p.$2]]) {
          if (id >= 0) {
            cleared.add(id);
            clearedAt.add(pairDepth);
          }
        }
        if (prog.isComplete) return true;
        pairDepth++;
        if (dfs(_Node(r.board, ids, prog, s.adds))) return true;
        pairDepth--;
        path.removeLast();
        cleared.length = mark;
        clearedAt.length = mark;
        if (nodes > nodeBudget) return false;
      }
      if (s.adds < addNumbersLimit) {
        final nb = addNumbers(s.board);
        if (nb.length != s.board.length) {
          path.add(const AddNumbersMove());
          if (dfs(_Node(nb, _idsAfterAdd(s.board, s.ids, nb), s.progress, s.adds + 1))) return true;
          path.removeLast();
        }
      }
      return false;
    }

    final ok = dfs(root);
    return SolveResult(
      solvable: ok,
      moves: ok ? List.unmodifiable(path) : const [],
      clearedCells: ok ? Set.unmodifiable(cleared.toSet()) : const {},
      nodes: nodes,
      clearOrder: ok ? List.unmodifiable(cleared) : const [],
      clearPairIndex: ok ? List.unmodifiable(clearedAt) : const [],
    );
  }

  static String _key(_Node s) {
    final sb = StringBuffer()
      ..write(s.adds)
      ..write('|')
      ..write(s.progress.done.join(','))
      ..write('|');
    for (final c in s.board.cells) {
      final o = c.obstacle;
      sb.writeCharCode(
        o == null
            ? (c.value == null ? 46 : 48 + c.value!)
            : switch (o.kind) {
                ObstacleKind.stone => 83,
                ObstacleKind.slime => 76,
                ObstacleKind.ice => 64 + (c.value ?? 0) * 3 + o.hp,
              },
      );
      if (c.item != null) sb.write('*');
      if (c.grass) sb.write('g');
    }
    return sb.toString();
  }

  /// True when some goal can provably no longer be reached.
  static bool _dead(_Node s, int addLimit) {
    final p = s.progress;
    final canAdd = s.adds < addLimit;
    for (var i = 0; i < p.goals.length; i++) {
      final need = p.remaining(i);
      if (need <= 0) continue;
      final g = p.goals[i];
      int have;
      switch (g.type) {
        case GoalType.star:
          have = s.board.cells.where((c) => c.item == CellItem.star && c.value != null).length;
        case GoalType.grass:
          have = s.board.cells.where((c) => c.grass && c.value != null).length;
        case GoalType.breakIce:
          have = s.board.cells.where((c) => c.obstacle?.kind == ObstacleKind.ice).length;
        case GoalType.slime:
          have = s.board.cells.where((c) => c.obstacle?.kind == ObstacleKind.slime).length;
        case GoalType.number:
          if (canAdd) continue;
          have = s.board.cells.where((c) => c.value == g.value).length;
        case GoalType.pairsSame:
        case GoalType.pairsTen:
          if (canAdd) continue;
          have = s.board.cells.where((c) => c.value != null).length ~/ 2;
      }
      if (have < need) return true;
    }
    return false;
  }

  /// Goal-driven score of clearing pair (a, b) in state [s].
  static double _score(_Node s, int a, int b) {
    final board = s.board, p = s.progress;
    final ca = board[a], cb = board[b];
    var score = 0.0;
    var wantIce = false, wantSlime = false;
    for (var i = 0; i < p.goals.length; i++) {
      if (p.remaining(i) <= 0) continue;
      final g = p.goals[i];
      switch (g.type) {
        case GoalType.number:
          if (ca.value == g.value) score += 10;
          if (cb.value == g.value) score += 10;
          // Avoid wasting the complement of the target digit.
          if (ca.value == 10 - g.value! && cb.value != g.value) score -= 3;
          if (cb.value == 10 - g.value! && ca.value != g.value) score -= 3;
        case GoalType.star:
          if (ca.item == CellItem.star) score += 10;
          if (cb.item == CellItem.star) score += 10;
        case GoalType.grass:
          if (ca.grass) score += 10;
          if (cb.grass) score += 10;
        case GoalType.pairsSame:
          if (ca.value == cb.value) score += 10;
        case GoalType.pairsTen:
          if (ca.value != cb.value) score += 10;
        case GoalType.breakIce:
          wantIce = true;
        case GoalType.slime:
          wantSlime = true;
      }
    }
    // Ice in the way of stars/numbers is also worth breaking a bit.
    final iceW = wantIce ? 6.0 : 1.5;
    final slimeW = wantSlime ? 6.0 : 0.0;
    for (final x in [a, b]) {
      for (final n in board.neighbours(x)) {
        final o = board[n].obstacle;
        if (o == null) continue;
        if (o.kind == ObstacleKind.ice) score += iceW;
        if (o.kind == ObstacleKind.slime) score += slimeW;
      }
    }
    // Prefer short-range pairs (keep structure) and earlier cells.
    final dist = (b - a).abs();
    score -= dist / (board.length + 1);
    return score;
  }
}

/// Outcome of [shortWinCheck].
enum ShortWinCheck { winnableWithin, notWinnableWithin, timedOut }

/// Depth-limited search: can [goals] be met with at most [maxPairs] pairs
/// (plus up to [addNumbersLimit] free Add numbers, no boosters)?
///
/// Used by the generator's `minPairs` difficulty check (generator/CI only,
/// never on device): a level is accepted only if this returns
/// [ShortWinCheck.notWinnableWithin] for `minPairs - 1`. Memo on board key +
/// progress + adds, storing the largest remaining depth already explored.
/// Returns [ShortWinCheck.timedOut] when [nodeBudget] nodes are exhausted
/// (deterministic, machine-independent; caller rejects and reseeds).
ShortWinCheck shortWinCheck(
  Board board,
  List<Goal> goals,
  int maxPairs, {
  int addNumbersLimit = solverAddLimit,
  int nodeBudget = 20000,
  void Function(int nodes)? onNodes,
}) {
  final memo = <String, int>{};
  var nodes = 0;
  var timedOut = false;

  bool dfs(_Node s, int depthLeft) {
    if (s.progress.isComplete) return true;
    if (depthLeft <= 0 && s.adds >= addNumbersLimit) return false;
    if (++nodes > nodeBudget) {
      timedOut = true;
      return false;
    }
    if (timedOut) return false;
    final key = DfsSolver._key(s);
    final prev = memo[key];
    if (prev != null && prev >= depthLeft) return false;
    memo[key] = depthLeft;
    if (DfsSolver._dead(s, addNumbersLimit)) return false;
    if (_lowerBoundPairs(s.progress) > depthLeft) return false;
    if (depthLeft > 0) {
      for (final (a, b) in fastValidPairs(s.board)) {
        final (r, ids) = _applyWithIds(s.board, s.ids, a, b);
        final prog = s.progress.copy()..onPair(r);
        if (dfs(_Node(r.board, ids, prog, s.adds), depthLeft - 1)) return true;
        if (timedOut) return false;
      }
    }
    if (s.adds < addNumbersLimit) {
      final nb = addNumbers(s.board);
      if (nb.length != s.board.length &&
          dfs(_Node(nb, _idsAfterAdd(s.board, s.ids, nb), s.progress, s.adds + 1), depthLeft)) {
        return true;
      }
    }
    return false;
  }

  final root = _Node(board, List<int>.generate(board.length, (i) => i), GoalProgress(goals), 0);
  final found = dfs(root, maxPairs);
  onNodes?.call(nodes);
  if (found) return ShortWinCheck.winnableWithin;
  return timedOut ? ShortWinCheck.timedOut : ShortWinCheck.notWinnableWithin;
}

/// Admissible lower bound on pairs still needed: a pair clears 2 cells, so
/// it advances a number/star/grass goal by at most 2 and a pair goal by 1.
int _lowerBoundPairs(GoalProgress p) {
  var lb = 0;
  for (var i = 0; i < p.goals.length; i++) {
    final need = p.remaining(i);
    if (need <= 0) continue;
    final b = switch (p.goals[i].type) {
      GoalType.number || GoalType.star || GoalType.grass => (need + 1) ~/ 2,
      GoalType.pairsSame || GoalType.pairsTen => need,
      GoalType.breakIce || GoalType.slime => 1,
    };
    if (b > lb) lb = b;
  }
  return lb;
}

/// Cheap difficulty metric: pairs a greedy goal-chaser needs to win.
///
/// Each step plays the valid pair with the largest immediate goal progress;
/// ties (and steps with no progress available) go to the pair closest
/// (Chebyshev distance) to the nearest remaining goal cell (star, grass,
/// target digit, ice, slime), then the earliest pair. With no pair it uses
/// "Add numbers" (up to [addNumbersLimit]). Returns the pair count, or null
/// if the greedy player gets stuck or exceeds [maxPairs].
int? greedyPairsToWin(
  Board board,
  List<Goal> goals, {
  int addNumbersLimit = solverAddLimit,
  int maxPairs = 500,
}) {
  var b = board;
  final p = GoalProgress(goals);
  var adds = 0, pairs = 0;
  while (!p.isComplete) {
    final cand = fastValidPairs(b);
    if (cand.isEmpty) {
      if (adds >= addNumbersLimit || !b.cells.any((c) => c.value != null)) return null;
      b = addNumbers(b);
      adds++;
      continue;
    }
    if (pairs >= maxPairs) return null;
    final targets = <int>[];
    for (var i = 0; i < p.goals.length; i++) {
      if (p.remaining(i) <= 0) continue;
      final g = p.goals[i];
      for (var k = 0; k < b.length; k++) {
        final c = b[k];
        final hit = switch (g.type) {
          GoalType.star => c.item == CellItem.star && c.value != null,
          GoalType.grass => c.grass && c.value != null,
          GoalType.number => c.value == g.value,
          GoalType.breakIce => c.obstacle?.kind == ObstacleKind.ice,
          GoalType.slime => c.obstacle?.kind == ObstacleKind.slime,
          GoalType.pairsSame || GoalType.pairsTen => false,
        };
        if (hit) targets.add(k);
      }
    }
    int dist(int x) {
      var best = 1 << 20;
      for (final t in targets) {
        final d = [
          (b.rowOf(x) - b.rowOf(t)).abs(),
          (b.colOf(x) - b.colOf(t)).abs(),
        ].reduce((u, v) => u > v ? u : v);
        if (d < best) best = d;
      }
      return best;
    }

    PairResult? bestR;
    var bestScore = -1 << 40;
    for (final (x, y) in cand) {
      final r = applyPair(b, x, y);
      final q = p.copy()..onPair(r);
      var gain = 0;
      for (var i = 0; i < q.done.length; i++) {
        gain += q.done[i] - p.done[i];
      }
      final dx = dist(x), dy = dist(y);
      final score = gain * 100000 - (dx < dy ? dx : dy);
      if (score > bestScore) {
        bestScore = score;
        bestR = r;
      }
    }
    p.onPair(bestR!);
    b = bestR.board;
    pairs++;
  }
  return pairs;
}
