/// Solver used by the generator to prove a level is winnable (M1 – Nionios).
///
/// The solver MUST prove that all goals are reachable WITHOUT boosters
/// (hammer/swap/hint) and WITHOUT rewarded ads, using at most
/// [solverAddLimit] "Add numbers" uses (stricter than the in-game
/// default `kDefaultAddNumbersLimit` = 5, leaving the player slack).
library;

import 'board.dart';
import 'goals.dart';
import 'moves.dart';

/// Max "Add numbers" the solver may use to prove solvability.
const int solverAddLimit = 3;

class SolveResult {
  const SolveResult({required this.solvable, this.moves = const [], this.clearedCells = const {}});
  final bool solvable;

  /// A winning line (pairs + add-numbers only).
  final List<Move> moves;

  /// Cells cleared along the line; generator places stars/grass only here.
  final Set<int> clearedCells;
}

abstract interface class Solver {
  /// Searches for a booster-free line reaching all [goals].
  SolveResult solve(Board board, List<Goal> goals, {int addNumbersLimit = solverAddLimit});
}

/// TODO(M1, Nionios): DFS/beam search with memo on board hash and a node budget.
class DfsSolver implements Solver {
  const DfsSolver({this.nodeBudget = 200000});
  final int nodeBudget;

  @override
  SolveResult solve(Board board, List<Goal> goals, {int addNumbersLimit = solverAddLimit}) =>
      throw UnimplementedError('M1');
}
