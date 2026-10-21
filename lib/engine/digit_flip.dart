/// Daily variation: the digit flip d -> 10 - d (1↔9, 2↔8, 3↔7, 4↔6, 5↔5).
///
/// Pair rules are preserved exactly: a == b ⇔ f(a) == f(b) and
/// a + b == 10 ⇔ f(a) + f(b) == 10. Positions, adjacency (incl. row wrap),
/// obstacles, stars and grass are untouched, so a flipped board is solvable
/// iff the original is (with number goals flipped too).
library;

import 'board.dart';
import 'goals.dart';

int flipDigit(int d) => 10 - d;

Board flipBoardDigits(Board b) => Board(b.columns, [
      for (final c in b.cells) c.value == null ? c : c.copyWith(value: flipDigit(c.value!)),
    ]);

/// Number goals target the flipped digit; other goals are unchanged.
List<Goal> flipGoals(List<Goal> goals) => [
      for (final g in goals) g.type == GoalType.number ? Goal(g.type, g.count, value: flipDigit(g.value!)) : g,
    ];

/// Weights for digits 1..9 re-indexed so digit d gets the weight of 10 - d.
List<double>? flipWeights(List<double>? w) => w?.reversed.toList();
