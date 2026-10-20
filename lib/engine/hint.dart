/// Hint selection (M1 – Nionios).
library;

import 'board.dart';
import 'goals.dart';

/// Picks the most useful valid pair for the player, preferring pairs that
/// advance [progress] goals (stars, grass, ice, slime, target digit), then
/// pairs that keep future pairs available. Returns null if no pair exists
/// (UI then suggests "Add numbers").
///
/// TODO(M1, Nionios): implement; may reuse `allValidPairs` from rules.dart.
(int, int)? findHint(Board board, GoalProgress progress) => throw UnimplementedError('M1');
