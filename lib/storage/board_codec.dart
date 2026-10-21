/// JSON codec for [Board] (save/resume and future prebaked boards).
library;

import '../engine/board.dart';
import '../engine/cell.dart';

Map<String, dynamic> cellToJson(Cell c) => {
  if (c.value != null) 'v': c.value,
  if (c.item == CellItem.star) 's': 1,
  if (c.grass) 'g': 1,
  if (c.obstacle != null) 'o': c.obstacle!.kind.name,
  if (c.obstacle?.kind == ObstacleKind.ice) 'hp': c.obstacle!.hp,
};

Cell cellFromJson(Map<String, dynamic> j) {
  final o = j['o'] as String?;
  final kind = o == null ? null : ObstacleKind.values.firstWhere((k) => k.name == o);
  return Cell(
    value: j['v'] as int?,
    item: j['s'] == 1 ? CellItem.star : null,
    grass: j['g'] == 1,
    obstacle: kind == null ? null : Obstacle(kind, hp: j['hp'] as int? ?? 0),
  );
}

Map<String, dynamic> boardToJson(Board b) => {
  'columns': b.columns,
  'cells': [for (final c in b.cells) cellToJson(c)],
};

Board boardFromJson(Map<String, dynamic> j) => Board(j['columns'] as int, [
  for (final c in (j['cells'] as List).cast<Map<String, dynamic>>()) cellFromJson(c),
]);
