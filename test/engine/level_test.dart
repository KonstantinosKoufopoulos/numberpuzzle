import 'dart:convert';
import 'dart:io';

import 'package:numberpuzzle/engine/goals.dart';
import 'package:numberpuzzle/engine/level.dart';
import 'package:numberpuzzle/engine/rules.dart';
import 'package:numberpuzzle/engine/board.dart';
import 'package:numberpuzzle/engine/scoring.dart';
import 'package:test/test.dart';

void main() {
  final pack = LevelPack.fromJson(
      jsonDecode(File('assets/levels/levels.json').readAsStringSync()) as Map<String, dynamic>);

  test('pack has 30 levels and validates', () {
    expect(pack.levels, hasLength(30));
    expect(pack.validate(), isEmpty);
  });

  for (var i = 0; i < 30; i++) {
    test('level ${i + 1} parses, validates, round-trips', () {
      final l = pack.levels[i];
      expect(l.validate(), isEmpty);
      final again = Level.fromJson(jsonDecode(jsonEncode(l.toJson())) as Map<String, dynamic>);
      expect(again.toJson(), l.toJson());
      expect(l.addNumbersLimit, 5);
    });
  }

  test('introduces flags', () {
    final m = {for (final l in pack.levels) if (l.introduces != null) l.introduces!: l.id};
    expect(m, {'stars': 7, 'grass': 11, 'stone': 16, 'ice': 21, 'slime': 26});
  });

  test('gifts', () {
    expect(pack.levels[9].gift, 'hammer');
    expect(pack.levels[19].gift, 'swap');
  });

  test('defaults and derived layers', () {
    final l = Level.fromJson({
      'id': 1, 'columns': 5, 'rows': 4,
      'goals': [{'type': 'star', 'count': 3}],
    });
    expect(l.addNumbersLimit, kDefaultAddNumbersLimit);
    expect(l.layers.stars, 3);
    expect(l.seed, 7919);
  });

  group('validation errors', () {
    Level mk(Map<String, dynamic> extra) => Level.fromJson({
          'id': 1, 'columns': 6, 'rows': 6,
          'goals': [{'type': 'number', 'value': 5, 'count': 4}],
          ...extra,
        });
    test('bad columns', () => expect(mk({'columns': 12}).validate(), isNotEmpty));
    test('number goal without value', () {
      expect(mk({'goals': [{'type': 'number', 'count': 3}]}).validate(), isNotEmpty);
    });
    test('breakIce more than ice', () {
      expect(
          mk({'goals': [{'type': 'breakIce', 'count': 3}], 'layers': {'ice': {'count': 2, 'hpMin': 1}}})
              .validate(),
          isNotEmpty);
    });
    test('ice hp 3', () {
      expect(mk({'layers': {'ice': {'count': 2, 'hpMin': 1, 'hpMax': 3}}}).validate(), isNotEmpty);
    });
    test('unknown introduces / gift', () {
      expect(mk({'introduces': 'lava'}).validate(), isNotEmpty);
      expect(mk({'gift': 'bomb'}).validate(), isNotEmpty);
    });
    test('unknown goal type throws', () {
      expect(() => mk({'goals': [{'type': 'lava', 'count': 1}]}), throwsFormatException);
    });
    test('schemaVersion mismatch', () {
      expect(() => LevelPack.fromJson({'schemaVersion': 2, 'levels': []}), throwsFormatException);
    });
  });

  group('GoalProgress', () {
    test('counts number, same and ten pairs', () {
      final p = GoalProgress(const [
        Goal(GoalType.number, 2, value: 5),
        Goal(GoalType.pairsSame, 1),
        Goal(GoalType.pairsTen, 1),
      ]);
      p.onPair(applyPair(Board.fromRows([[5, 5, 1]]), 0, 1));
      expect(p.done, [2, 1, 0]);
      expect(p.isComplete, isFalse);
      p.onPair(applyPair(Board.fromRows([[3, 7, 1]]), 0, 1));
      expect(p.isComplete, isTrue);
    });
  });

  group('starsForWin', () {
    test('0 boosters = 3', () => expect(starsForWin(boostersUsed: 0), 3));
    test('1 booster = 2', () => expect(starsForWin(boostersUsed: 1), 2));
    test('2+ boosters = 1', () => expect(starsForWin(boostersUsed: 4), 1));
  });
}
