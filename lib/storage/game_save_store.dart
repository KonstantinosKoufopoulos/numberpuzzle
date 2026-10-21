import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../engine/board.dart';
import '../engine/game.dart';
import '../engine/level.dart';
import 'board_codec.dart';

/// In-level state for resume (undo history is not persisted).
class SavedGame {
  const SavedGame({required this.levelId, required this.initialBoard, required this.state, this.spent = const {}});

  final int levelId;

  /// Board the level started with.
  final Board initialBoard;
  final GameState state;

  /// Boosters taken from the inventory so far in this level.
  final Map<String, int> spent;

  Map<String, dynamic> toJson() => {
    'v': 1,
    'levelId': levelId,
    'initialBoard': boardToJson(initialBoard),
    'board': boardToJson(state.board),
    'done': state.goalDone,
    'addNumbersLimit': state.addNumbersLimit,
    'addNumbersUsed': state.addNumbersUsed,
    'boostersUsed': state.boostersUsed,
    'moveCount': state.moveCount,
    'spent': spent,
    if (state.endless) 'endless': true,
    if (state.score != 0) 'score': state.score,
  };

  /// Rebuilds a saved game for [level]; null if it belongs to another level
  /// or is malformed.
  static SavedGame? fromJson(Map<String, dynamic> j, Level level) {
    if (j['v'] != 1 || j['levelId'] != level.id) return null;
    final done = (j['done'] as List).cast<int>();
    if (done.length != level.goals.length) return null;
    return SavedGame(
      levelId: level.id,
      initialBoard: boardFromJson(j['initialBoard'] as Map<String, dynamic>),
      spent: (j['spent'] as Map<String, dynamic>? ?? {}).cast<String, int>(),
      state: GameState.restore(
        board: boardFromJson(j['board'] as Map<String, dynamic>),
        goals: level.goals,
        done: done,
        addNumbersLimit: j['addNumbersLimit'] as int,
        addNumbersUsed: j['addNumbersUsed'] as int,
        boostersUsed: j['boostersUsed'] as int,
        moveCount: j['moveCount'] as int? ?? 0,
        endless: j['endless'] as bool? ?? false,
        score: j['score'] as int? ?? 0,
      ),
    );
  }
}

/// Persists the in-progress level (one slot) and the tutorial flag in
/// shared_preferences. Separate from the shell's `progress` key.
class GameSaveStore {
  GameSaveStore({this.slot = key});

  /// Classic mode keeps its own slot so it never clobbers a level in progress.
  GameSaveStore.classic() : slot = classicKey;

  static const String key = 'game_v1';
  static const String classicKey = 'classic_game_v1';

  /// Prefs key of this store's single save slot.
  final String slot;
  static const String tutorialKey = 'tutorial_done_v1';

  Future<SavedGame?> load(Level level) async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(slot);
    if (s == null) return null;
    try {
      return SavedGame.fromJson(jsonDecode(s) as Map<String, dynamic>, level);
    } on Object {
      return null;
    }
  }

  Future<void> save(SavedGame game) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(slot, jsonEncode(game.toJson()));
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(slot);
  }

  Future<bool> tutorialDone() async => (await SharedPreferences.getInstance()).getBool(tutorialKey) ?? false;

  /// Settings → Tutorial → Replay.
  Future<void> resetTutorial() async => (await SharedPreferences.getInstance()).remove(tutorialKey);

  Future<void> setTutorialDone() async => (await SharedPreferences.getInstance()).setBool(tutorialKey, true);
}
