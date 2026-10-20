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
  });
  final bool solvable;

  /// A winning line (pairs + add-numbers only), with indices valid on the
  /// board at the time each move is played.
  final List<Move> moves;

  /// Indices (on the starting board) of original cells whose numbers are
  /// cleared along the line; the generator places stars/grass only here.
  final Set<int> clearedCells;

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
          if (id >= 0) cleared.add(id);
        }
        if (prog.isComplete) return true;
        if (dfs(_Node(r.board, ids, prog, s.adds))) return true;
        path.removeLast();
        cleared.length = mark;
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
