/// Level data model, JSON parsing and validation (pure Dart).
/// Schema documented in docs/level-schema.md.
library;

import 'goals.dart';

/// Obstacle/feature ids used by `introduces` (first-time explainer card).
const Set<String> kIntroducible = {'stars', 'grass', 'stone', 'ice', 'slime'};

/// Booster ids used by `gift`.
const Set<String> kGiftable = {'hammer', 'swap'};

/// Default number of "Add numbers" uses per level.
const int kDefaultAddNumbersLimit = 5;

class IceSpec {
  const IceSpec({this.count = 0, this.hpMin = 1, this.hpMax = 1});
  final int count;
  final int hpMin;
  final int hpMax;

  factory IceSpec.fromJson(Map<String, dynamic> j) => IceSpec(
        count: j['count'] as int? ?? 0,
        hpMin: j['hpMin'] as int? ?? 1,
        hpMax: j['hpMax'] as int? ?? (j['hpMin'] as int? ?? 1),
      );
  Map<String, dynamic> toJson() => {'count': count, 'hpMin': hpMin, 'hpMax': hpMax};
}

/// Layer counts placed by the generator.
class LayerSpec {
  const LayerSpec({
    this.stars = 0,
    this.grass = 0,
    this.stone = 0,
    this.ice = const IceSpec(),
    this.slime = 0,
  });

  final int stars;
  final int grass;
  final int stone;
  final IceSpec ice;
  final int slime;

  factory LayerSpec.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const LayerSpec();
    return LayerSpec(
      stars: j['stars'] as int? ?? 0,
      grass: j['grass'] as int? ?? 0,
      stone: j['stone'] as int? ?? 0,
      ice: j['ice'] == null ? const IceSpec() : IceSpec.fromJson(j['ice'] as Map<String, dynamic>),
      slime: j['slime'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        if (stars > 0) 'stars': stars,
        if (grass > 0) 'grass': grass,
        if (stone > 0) 'stone': stone,
        if (ice.count > 0) 'ice': ice.toJson(),
        if (slime > 0) 'slime': slime,
      };
}

class Level {
  const Level({
    required this.id,
    required this.columns,
    required this.rows,
    required this.seed,
    required this.goals,
    this.layers = const LayerSpec(),
    this.digitWeights,
    this.addNumbersLimit = kDefaultAddNumbersLimit,
    this.gift,
    this.introduces,
    this.tier = 1,
    this.note,
    this.digitFlip = false,
    this.boardFrom,
  });

  final int id;
  final int columns;

  /// Starting rows.
  final int rows;
  final int seed;
  final List<Goal> goals;
  final LayerSpec layers;

  /// Optional relative weights for digits 1..9 (length 9).
  final List<double>? digitWeights;
  final int addNumbersLimit;

  /// Booster granted on first completion: `hammer` | `swap`.
  final String? gift;

  /// Feature explained by a first-time card: stars|grass|stone|ice|slime.
  final String? introduces;
  final int tier;
  final String? note;

  /// Daily variation: every digit of the board is flipped (d -> 10 - d).
  /// [goals] and [digitWeights] are already flipped.
  final bool digitFlip;

  /// Daily: build exactly the board of map level [boardFrom] (its own id and
  /// fixed seed, already validated), then apply [digitFlip]. Never generates
  /// a new board.
  final int? boardFrom;

  int get cellCount => columns * rows;

  factory Level.fromJson(Map<String, dynamic> j) {
    final goals = (j['goals'] as List).cast<Map<String, dynamic>>().map(Goal.fromJson).toList();
    final layers = LayerSpec.fromJson(j['layers'] as Map<String, dynamic>?);
    // Stars/grass/slime default to what the goals need.
    int need(GoalType t) => goals.where((g) => g.type == t).fold(0, (s, g) => s + g.count);
    final raw = j['layers'] as Map<String, dynamic>? ?? const {};
    final filled = LayerSpec(
      stars: raw.containsKey('stars') ? layers.stars : need(GoalType.star),
      grass: raw.containsKey('grass') ? layers.grass : need(GoalType.grass),
      stone: layers.stone,
      ice: layers.ice,
      slime: raw.containsKey('slime') ? layers.slime : need(GoalType.slime),
    );
    return Level(
      id: j['id'] as int,
      columns: j['columns'] as int,
      rows: j['rows'] as int,
      seed: j['seed'] as int? ?? (j['id'] as int) * 7919,
      goals: goals,
      layers: filled,
      digitWeights: (j['digitWeights'] as List?)?.map((e) => (e as num).toDouble()).toList(),
      addNumbersLimit: j['addNumbersLimit'] as int? ?? kDefaultAddNumbersLimit,
      gift: j['gift'] as String?,
      introduces: j['introduces'] as String?,
      tier: j['tier'] as int? ?? 1,
      note: j['note'] as String?,
      digitFlip: j['digitFlip'] as bool? ?? false,
      boardFrom: j['boardFrom'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'columns': columns,
        'rows': rows,
        'seed': seed,
        'tier': tier,
        'goals': [for (final g in goals) g.toJson()],
        'layers': layers.toJson(),
        if (digitWeights != null) 'digitWeights': digitWeights,
        'addNumbersLimit': addNumbersLimit,
        if (gift != null) 'gift': gift,
        if (introduces != null) 'introduces': introduces,
        if (note != null) 'note': note,
        if (digitFlip) 'digitFlip': true,
        if (boardFrom != null) 'boardFrom': boardFrom,
      };

  /// Returns a list of human-readable problems; empty = valid.
  List<String> validate() {
    final e = <String>[];
    if (id < 1) e.add('id must be >= 1');
    if (columns < 4 || columns > 9) e.add('columns must be 4..9');
    if (rows < 3 || rows > 12) e.add('rows must be 3..12');
    if (goals.isEmpty) e.add('at least one goal');
    for (final g in goals) {
      if (g.count <= 0) e.add('${g.type.name}: count must be > 0');
      if (g.type == GoalType.number && (g.value == null || g.value! < 1 || g.value! > 9)) {
        e.add('number goal needs value 1..9');
      }
      if (g.type != GoalType.number && g.value != null) e.add('${g.type.name}: value not allowed');
    }
    int need(GoalType t) => goals.where((g) => g.type == t).fold(0, (s, g) => s + g.count);
    final l = layers;
    if (l.stars < need(GoalType.star)) e.add('fewer stars than star goal');
    if (l.grass < need(GoalType.grass)) e.add('fewer grass than grass goal');
    if (l.slime < need(GoalType.slime)) e.add('fewer slime than slime goal');
    if (l.ice.count < need(GoalType.breakIce)) e.add('fewer ice than breakIce goal');
    if (l.ice.count > 0 && (l.ice.hpMin < 1 || l.ice.hpMax > 2 || l.ice.hpMin > l.ice.hpMax)) {
      e.add('ice hp must satisfy 1 <= hpMin <= hpMax <= 2');
    }
    final blockers = l.stone + l.slime;
    if (blockers > cellCount ~/ 4) e.add('too many stone+slime for board');
    if (l.stone + l.slime + l.ice.count > cellCount ~/ 2) e.add('too many obstacles');
    if (l.stars + l.grass > cellCount) e.add('too many stars+grass');
    if (digitWeights != null && (digitWeights!.length != 9 || digitWeights!.any((w) => w < 0))) {
      e.add('digitWeights must be 9 non-negative numbers');
    }
    if (addNumbersLimit < 0) e.add('addNumbersLimit must be >= 0');
    if (gift != null && !kGiftable.contains(gift)) e.add('unknown gift "$gift"');
    if (introduces != null && !kIntroducible.contains(introduces)) {
      e.add('unknown introduces "$introduces"');
    }
    if (tier < 1 || tier > 5) e.add('tier must be 1..5');
    return e;
  }
}

/// Parses `{ "schemaVersion": 1, "levels": [...] }` and validates the pack:
/// each level valid, ids unique and 1..N contiguous.
class LevelPack {
  LevelPack(this.levels);
  final List<Level> levels;

  static const int schemaVersion = 1;

  factory LevelPack.fromJson(Map<String, dynamic> j) {
    final v = j['schemaVersion'];
    if (v != schemaVersion) throw FormatException('Unsupported schemaVersion $v');
    return LevelPack([
      for (final l in (j['levels'] as List).cast<Map<String, dynamic>>()) Level.fromJson(l),
    ]);
  }

  List<String> validate() {
    final e = <String>[];
    for (final l in levels) {
      for (final p in l.validate()) {
        e.add('level ${l.id}: $p');
      }
    }
    final ids = levels.map((l) => l.id).toList();
    if (ids.toSet().length != ids.length) e.add('duplicate ids');
    for (var i = 0; i < ids.length; i++) {
      if (ids[i] != i + 1) {
        e.add('ids must be 1..N in order');
        break;
      }
    }
    return e;
  }
}
