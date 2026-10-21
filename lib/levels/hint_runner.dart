import 'package:flutter/foundation.dart';

import '../engine/board.dart';
import '../engine/goals.dart';
import '../engine/hint.dart';

/// Computes a hint without blocking the UI.
typedef HintRunner = Future<Hint> Function(Board board, GoalProgress progress, int addNumbersLeft);

/// Solver budget for in-game hints (keeps the worst case well under a second).
const int kHintNodeBudget = 5000;

Hint _hintEntry((Board, GoalProgress, int) a) =>
    computeHint(a.$1, a.$2, addNumbersLeft: a.$3, nodeBudget: kHintNodeBudget);

/// Default runner: [computeHint] in a background isolate via [compute].
Future<Hint> computeHintOffThread(Board board, GoalProgress progress, int addNumbersLeft) =>
    compute(_hintEntry, (board, progress, addNumbersLeft));
