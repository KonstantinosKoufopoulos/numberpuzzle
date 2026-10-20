/// Player moves and booster interfaces (M1 stubs except [PairMove]/[AddNumbersMove]).
library;

import 'board.dart';
import 'cell.dart';
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

/// Result of a hammer hit (feeds goal progress).
typedef HammerResult = ({Board board, int? value, int stars, int grass, int iceBroken, int slimeRemoved});

/// Hammer: clears one number (or one ice/slime layer; never stone).
///
/// * Plain or unfrozen number: the number is cleared (its star/grass are
///   collected) and the clear damages adjacent ice like a pair clear.
/// * Ice-covered number: the whole ice layer is removed (any hp) and counts as
///   one broken ice; the number stays.
/// * Slime: removed (counts as one slime removed).
/// * Stone and empty cells: not allowed.
class HammerBooster implements Booster {
  const HammerBooster();
  @override
  String get id => 'hammer';

  @override
  bool canApply(Board board, Object? target) {
    if (target is! int || target < 0 || target >= board.length) return false;
    final c = board[target];
    if (c.obstacle?.kind == ObstacleKind.stone) return false;
    return !c.isEmpty;
  }

  @override
  Board apply(Board board, Object? target) => hit(board, target as int).board;

  /// Applies the hammer at [cell] and reports what was collected.
  HammerResult hit(Board board, int cell) {
    if (!canApply(board, cell)) throw ArgumentError('Hammer cannot hit $cell');
    final c = board[cell];
    final kind = c.obstacle?.kind;
    if (kind == ObstacleKind.ice && c.obstacle!.hp > 0) {
      final r = rules.resolveAfterClear(board.replace({cell: c.copyWith(clearObstacle: true)}), const []);
      return (board: r.board, value: null, stars: 0, grass: 0, iceBroken: 1, slimeRemoved: r.slimeRemoved);
    }
    if (kind == ObstacleKind.slime) {
      final r = rules.resolveAfterClear(board.replace({cell: const Cell.empty()}), const []);
      return (board: r.board, value: null, stars: 0, grass: 0, iceBroken: 0, slimeRemoved: 1 + r.slimeRemoved);
    }
    final r = rules.resolveAfterClear(board.replace({cell: const Cell.empty()}), [cell]);
    return (
      board: r.board,
      value: c.value,
      stars: c.item == CellItem.star ? 1 : 0,
      grass: c.grass ? 1 : 0,
      iceBroken: r.iceBroken,
      slimeRemoved: r.slimeRemoved,
    );
  }
}

/// Swap: exchanges the digits of two selectable numbers. Target is
/// `(int, int)`. Layers (star, grass) stay on their cells; only values move.
class SwapBooster implements Booster {
  const SwapBooster();
  @override
  String get id => 'swap';

  @override
  bool canApply(Board board, Object? target) {
    if (target is! (int, int)) return false;
    final (a, b) = target;
    if (a == b || a < 0 || b < 0 || a >= board.length || b >= board.length) return false;
    return board[a].isSelectable && board[b].isSelectable;
  }

  @override
  Board apply(Board board, Object? target) {
    if (!canApply(board, target)) throw ArgumentError('Swap cannot apply to $target');
    final (a, b) = target as (int, int);
    return board.replace({a: board[a].copyWith(value: board[b].value), b: board[b].copyWith(value: board[a].value)});
  }
}

/// Hint: highlights a pair from `hint.dart` (board unchanged).
class HintBooster implements Booster {
  const HintBooster();
  @override
  String get id => 'hint';
  @override
  bool canApply(Board board, Object? target) => true;
  @override
  Board apply(Board board, Object? target) => board;
}
