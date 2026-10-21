/// Classic mode: endless Number Match with no goals. Clear pairs, use
/// "Add numbers", score points; a cleared board deals a new one.
library;

import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../engine/board.dart';
import '../engine/cell.dart';
import '../engine/game.dart';
import '../engine/level.dart';
import '../engine/rules.dart' as rules;

/// Level id used for classic games (route name, save slot).
const int kClassicLevelId = 0;

/// Starting rows of a classic board (9 × 4 = 36 numbers).
const int kClassicRows = 4;

/// Minimum valid pairs on a fresh classic board.
const int kClassicMinPairs = 3;

/// A classic "level": 9 columns, no goals, the default 5 "Add numbers".
Level classicLevel(int seed) =>
    Level(id: kClassicLevelId, columns: Board.classicColumns, rows: kClassicRows, seed: seed, goals: const []);

/// Deterministic random digits 1–9 with at least [kClassicMinPairs] pairs.
/// Cheap (no solver), so it runs on the UI thread.
Board classicBoard(int seed) {
  for (var k = 0; ; k++) {
    final r = Random(seed * 7919 + k);
    final b = Board(Board.classicColumns, [
      for (var i = 0; i < Board.classicColumns * kClassicRows; i++) Cell.n(1 + r.nextInt(9)),
    ]);
    if (rules.allValidPairs(b).length >= kClassicMinPairs || k > 50) return b;
  }
}

/// Fresh classic state for [seed].
GameState classicStart(int seed) =>
    GameState.start(classicBoard(seed), const [], addNumbersLimit: kDefaultAddNumbersLimit, endless: true);

/// Next board after a clear: depends on the game's seed and move count, so
/// it is deterministic for a given play-through.
Board classicNextBoard(int seed, GameState s) => classicBoard(seed + 1000003 * s.moveCount);

/// Best classic score (shared_preferences key `classic_best_v1`).
class ClassicStore {
  static const String key = 'classic_best_v1';

  Future<int> best() async => (await SharedPreferences.getInstance()).getInt(key) ?? 0;

  /// Saves [score] if it beats the best; returns the (new) best.
  Future<int> record(int score) async {
    final p = await SharedPreferences.getInstance();
    final best = p.getInt(key) ?? 0;
    if (score <= best) return best;
    await p.setInt(key, score);
    return score;
  }
}
