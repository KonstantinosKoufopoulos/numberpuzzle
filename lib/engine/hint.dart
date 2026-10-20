/// Hint selection (M1).
library;

import 'board.dart';
import 'goals.dart';
import 'moves.dart';
import 'solver.dart';

/// What the hint suggests.
class Hint {
  const Hint.pair(int a, int b, {this.leadsToWin = false}) : pair = (a, b), addNumbers = false;
  const Hint.addNumbers({this.leadsToWin = false}) : pair = null, addNumbers = true;
  const Hint.none() : pair = null, addNumbers = false, leadsToWin = false;

  final (int, int)? pair;
  final bool addNumbers;

  /// True when the solver found a winning line starting with this move.
  final bool leadsToWin;
}

/// Full hint: the first move of a solver line if one exists (within
/// [addNumbersLeft], capped at [solverAddLimit] for speed); otherwise any
/// valid pair; otherwise "Add numbers" if any are left; otherwise none.
Hint computeHint(
  Board board,
  GoalProgress progress, {
  int addNumbersLeft = solverAddLimit,
  int nodeBudget = 20000,
}) {
  final limit = addNumbersLeft < solverAddLimit ? addNumbersLeft : solverAddLimit;
  final r = DfsSolver(nodeBudget: nodeBudget).solveFrom(board, progress, addNumbersLimit: limit);
  if (r.solvable && r.moves.isNotEmpty) {
    final m = r.moves.first;
    if (m is PairMove) return Hint.pair(m.a, m.b, leadsToWin: true);
  }
  final pairs = fastValidPairs(board);
  if (pairs.isNotEmpty) return Hint.pair(pairs.first.$1, pairs.first.$2);
  if (addNumbersLeft > 0 && board.cells.any((c) => c.value != null)) {
    return Hint.addNumbers(leadsToWin: r.solvable);
  }
  return const Hint.none();
}

/// Picks the most useful valid pair for the player, preferring a pair that
/// starts a winning solver line, else any valid pair. Returns null if no
/// pair exists (UI then suggests "Add numbers").
(int, int)? findHint(Board board, GoalProgress progress, {int addNumbersLeft = solverAddLimit}) =>
    computeHint(board, progress, addNumbersLeft: addNumbersLeft).pair;
