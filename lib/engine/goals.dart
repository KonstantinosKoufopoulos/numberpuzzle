/// Level goals and progress tracking (pure Dart).
library;

import 'rules.dart';

/// Goal types supported by the level schema (see docs/level-schema.md).
enum GoalType {
  /// Clear [Goal.count] pairs of equal numbers.
  pairsSame,

  /// Clear [Goal.count] pairs of different numbers summing to 10
  /// (5+5 counts as [pairsSame]).
  pairsTen,

  /// Clear [Goal.count] cells holding digit [Goal.value].
  number,

  /// Collect [Goal.count] stars.
  star,

  /// Clear [Goal.count] grass cells.
  grass,

  /// Break [Goal.count] ice blocks.
  breakIce,

  /// Remove [Goal.count] slime blobs.
  slime,
}

class Goal {
  const Goal(this.type, this.count, {this.value});

  final GoalType type;
  final int count;

  /// Digit 1–9; only for [GoalType.number].
  final int? value;

  factory Goal.fromJson(Map<String, dynamic> j) {
    final name = j['type'] as String;
    final type = GoalType.values.where((t) => t.name == name).firstOrNull;
    if (type == null) throw FormatException('Unknown goal type "$name"');
    return Goal(type, j['count'] as int, value: j['value'] as int?);
  }

  Map<String, dynamic> toJson() =>
      {'type': type.name, if (value != null) 'value': value, 'count': count};
}

/// Mutable progress for the goals of one level.
class GoalProgress {
  GoalProgress(this.goals) : done = List.filled(goals.length, 0);

  final List<Goal> goals;
  final List<int> done;

  void onPair(PairResult r) {
    for (var i = 0; i < goals.length; i++) {
      final g = goals[i];
      final inc = switch (g.type) {
        GoalType.pairsSame => r.isSamePair ? 1 : 0,
        GoalType.pairsTen => r.isTenPair && !r.isSamePair ? 1 : 0,
        GoalType.number =>
          (r.valueA == g.value ? 1 : 0) + (r.valueB == g.value ? 1 : 0),
        GoalType.star => r.starsCollected,
        GoalType.grass => r.grassCollected,
        GoalType.breakIce => r.iceBroken,
        GoalType.slime => r.slimeRemoved,
      };
      done[i] = (done[i] + inc).clamp(0, g.count);
    }
  }

  int remaining(int i) => goals[i].count - done[i];
  bool get isComplete => [for (var i = 0; i < goals.length; i++) remaining(i)].every((r) => r <= 0);
}
