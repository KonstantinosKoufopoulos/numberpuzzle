/// Cell model of the Number Puzzle board (pure Dart, no Flutter imports).
library;

/// Collectible item sitting on a numbered cell. Collected when the number
/// under it is cleared.
enum CellItem { star }

/// Kinds of obstacles.
///
/// * [stone]: permanent, has no number and blocks lines like a number.
/// * [ice]: covers a numbered cell; the number is not selectable while
///   `hp > 0`. Each clear in one of the 8 neighbouring cells removes 1 hp.
/// * [slime]: has no number and blocks lines; removed when all 8 neighbours
///   are empty (off-board counts as empty). Does not spread.
enum ObstacleKind { stone, ice, slime }

/// An obstacle with optional hit points (only meaningful for ice).
class Obstacle {
  const Obstacle(this.kind, {this.hp = 0});
  const Obstacle.stone() : this(ObstacleKind.stone);
  const Obstacle.slime() : this(ObstacleKind.slime);
  const Obstacle.ice(int hp) : this(ObstacleKind.ice, hp: hp);

  final ObstacleKind kind;
  final int hp;

  Obstacle withHp(int newHp) => Obstacle(kind, hp: newHp);

  @override
  bool operator ==(Object other) =>
      other is Obstacle && other.kind == kind && other.hp == hp;

  @override
  int get hashCode => Object.hash(kind, hp);

  @override
  String toString() => kind == ObstacleKind.ice ? 'ice($hp)' : kind.name;
}

/// One board cell. `value == null` means the number was cleared (or the cell
/// holds a number-less obstacle such as stone/slime).
class Cell {
  const Cell({this.value, this.item, this.grass = false, this.obstacle});

  /// Convenience: a plain numbered cell.
  const Cell.n(int this.value)
      : item = null,
        grass = false,
        obstacle = null;

  /// A cleared, empty cell.
  const Cell.empty()
      : value = null,
        item = null,
        grass = false,
        obstacle = null;

  final int? value;
  final CellItem? item;

  /// Grass layer under the number; collected when the number is cleared.
  final bool grass;
  final Obstacle? obstacle;

  /// Empty = no number and no obstacle. Lines may pass over empty cells only.
  bool get isEmpty => value == null && obstacle == null;

  /// Can the player tap this cell as part of a pair?
  bool get isSelectable =>
      value != null &&
      (obstacle == null || (obstacle!.kind == ObstacleKind.ice && obstacle!.hp <= 0));

  Cell copyWith({
    int? value,
    bool clearValue = false,
    CellItem? item,
    bool clearItem = false,
    bool? grass,
    Obstacle? obstacle,
    bool clearObstacle = false,
  }) =>
      Cell(
        value: clearValue ? null : (value ?? this.value),
        item: clearItem ? null : (item ?? this.item),
        grass: grass ?? this.grass,
        obstacle: clearObstacle ? null : (obstacle ?? this.obstacle),
      );

  @override
  bool operator ==(Object other) =>
      other is Cell &&
      other.value == value &&
      other.item == item &&
      other.grass == grass &&
      other.obstacle == obstacle;

  @override
  int get hashCode => Object.hash(value, item, grass, obstacle);

  @override
  String toString() => isEmpty ? '.' : (obstacle?.toString() ?? '$value');
}
