/// Player moves and booster interfaces (M1 stubs except [PairMove]/[AddNumbersMove]).
library;

import 'board.dart';
import 'rules.dart' as rules;

/// A player action.
sealed class Move {
  const Move();

  /// Whether this move counts as a booster for [starsForWin].
  bool get isBooster => false;
}

class PairMove extends Move {
  const PairMove(this.a, this.b);
  final int a, b;
}

/// Appends remaining numbers; limited by `Level.addNumbersLimit`.
/// Free: never triggers ads and never reduces the star rating.
class AddNumbersMove extends Move {
  const AddNumbersMove();
}

class HammerMove extends Move {
  const HammerMove(this.cell);
  final int cell;
  @override
  bool get isBooster => true;
}

class SwapMove extends Move {
  const SwapMove(this.a, this.b);
  final int a, b;
  @override
  bool get isBooster => true;
}

class HintMove extends Move {
  const HintMove();
  @override
  bool get isBooster => true;
}

/// Undo is free (no ad, no star penalty).
class UndoMove extends Move {
  const UndoMove();
}

/// Common booster interface.
abstract interface class Booster {
  String get id;

  /// Whether the booster can be applied at [target] on [board].
  bool canApply(Board board, Object? target);

  /// Applies the booster and returns the new board.
  Board apply(Board board, Object? target);
}

/// Hammer: clears one number (or one ice/slime layer; never stone).
/// TODO(M1, Nionios): implement using [rules.resolveAfterClear].
class HammerBooster implements Booster {
  @override
  String get id => 'hammer';
  @override
  bool canApply(Board board, Object? target) => throw UnimplementedError();
  @override
  Board apply(Board board, Object? target) => throw UnimplementedError();
}

/// Swap: exchanges two selectable numbers. Target is `(int, int)`.
/// TODO(M1, Nionios).
class SwapBooster implements Booster {
  @override
  String get id => 'swap';
  @override
  bool canApply(Board board, Object? target) => throw UnimplementedError();
  @override
  Board apply(Board board, Object? target) => throw UnimplementedError();
}

/// Hint: highlights a pair from `hint.dart` (board unchanged).
/// TODO(M1, Nionios).
class HintBooster implements Booster {
  @override
  String get id => 'hint';
  @override
  bool canApply(Board board, Object? target) => throw UnimplementedError();
  @override
  Board apply(Board board, Object? target) => board;
}

/// Undo history (free). TODO(M1, Nionios): also restore GoalProgress.
class UndoStack {
  final List<Board> _history = [];
  void push(Board b) => _history.add(b);
  bool get canUndo => _history.isNotEmpty;
  Board pop() => _history.removeLast();
}
