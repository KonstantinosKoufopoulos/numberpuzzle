/// Full engine state for one level play-through (pure Dart, M1).
///
/// [GameState] is immutable; every move returns a new state that keeps a
/// pointer to its predecessor, so undo is a free, unlimited snapshot restore.
library;

import 'board.dart';
import 'goals.dart';
import 'level.dart';
import 'moves.dart';
import 'rules.dart' as rules;

enum GameStatus { playing, won, lost }

class GameState {
  GameState._({
    required this.board,
    required GoalProgress progress,
    required this.addNumbersLimit,
    required this.addNumbersUsed,
    required this.boostersUsed,
    required this.moveCount,
    this.previous,
  }) : _progress = progress;

  /// Starting state for [board] with [goals].
  factory GameState.start(Board board, List<Goal> goals, {int addNumbersLimit = kDefaultAddNumbersLimit}) =>
      GameState._(
        board: board,
        progress: GoalProgress(goals),
        addNumbersLimit: addNumbersLimit,
        addNumbersUsed: 0,
        boostersUsed: 0,
        moveCount: 0,
      );

  /// Starting state for a level using an already generated [board].
  factory GameState.forLevel(Level level, Board board) =>
      GameState.start(board, level.goals, addNumbersLimit: level.addNumbersLimit);

  /// Rebuilds a saved state (resume). Undo history is not restored.
  factory GameState.restore({
    required Board board,
    required List<Goal> goals,
    required List<int> done,
    required int addNumbersLimit,
    required int addNumbersUsed,
    required int boostersUsed,
    int moveCount = 0,
  }) => GameState._(
    board: board,
    progress: GoalProgress.withDone(goals, done),
    addNumbersLimit: addNumbersLimit,
    addNumbersUsed: addNumbersUsed,
    boostersUsed: boostersUsed,
    moveCount: moveCount,
  );

  /// Same position with [extra] more "Add numbers" (rewarded continue after
  /// a loss). Board, goals, undo history and booster count are kept.
  GameState withExtraAddNumbers(int extra) => GameState._(
    board: board,
    progress: _progress.copy(),
    addNumbersLimit: addNumbersLimit + extra,
    addNumbersUsed: addNumbersUsed,
    boostersUsed: boostersUsed,
    moveCount: moveCount,
    previous: previous,
  );

  final Board board;
  final GoalProgress _progress;
  final int addNumbersLimit;
  final int addNumbersUsed;

  /// Boosters used (hammer, swap, hint). Never decreases, even on undo, so
  /// undo cannot be used to recover a 3-star rating.
  final int boostersUsed;
  final int moveCount;
  final GameState? previous;

  /// Copy of the goal progress (state stays immutable).
  GoalProgress get progress => _progress.copy();
  List<Goal> get goals => _progress.goals;
  List<int> get goalDone => List.unmodifiable(_progress.done);

  int get addNumbersLeft => addNumbersLimit - addNumbersUsed;
  bool get canAddNumbers => addNumbersLeft > 0 && board.cells.any((c) => c.value != null);
  bool get canUndo => previous != null;
  bool get isWon => _progress.isComplete;

  /// Lost: goals unmet, no valid pair and no "Add numbers" left.
  bool get isLost => !isWon && !canAddNumbers && rules.allValidPairs(board).isEmpty;

  GameStatus get status => isWon ? GameStatus.won : (isLost ? GameStatus.lost : GameStatus.playing);

  GameState _next(Board b, GoalProgress p, {int adds = 0, int boosters = 0}) => GameState._(
    board: b,
    progress: p,
    addNumbersLimit: addNumbersLimit,
    addNumbersUsed: addNumbersUsed + adds,
    boostersUsed: boostersUsed + boosters,
    moveCount: moveCount + 1,
    previous: this,
  );

  void _requirePlaying() {
    if (status != GameStatus.playing) throw StateError('Game is over (${status.name})');
  }

  bool canPair(int a, int b) => status == GameStatus.playing && rules.canPair(board, a, b);

  GameState pair(int a, int b) {
    _requirePlaying();
    final r = rules.applyPair(board, a, b);
    return _next(r.board, _progress.copy()..onPair(r));
  }

  GameState addNumbers() {
    _requirePlaying();
    if (!canAddNumbers) throw StateError('No "Add numbers" left');
    return _next(rules.addNumbers(board), _progress.copy(), adds: 1);
  }

  GameState hammer(int cell) {
    _requirePlaying();
    final r = const HammerBooster().hit(board, cell);
    final p = _progress.copy()
      ..onClear(
        values: [if (r.value != null) r.value!],
        stars: r.stars,
        grass: r.grass,
        iceBroken: r.iceBroken,
        slimeRemoved: r.slimeRemoved,
      );
    return _next(r.board, p, boosters: 1);
  }

  GameState swap(int a, int b) {
    _requirePlaying();
    return _next(const SwapBooster().apply(board, (a, b)), _progress.copy(), boosters: 1);
  }

  /// Records a hint usage (board unchanged, counts as a booster).
  GameState useHint() {
    _requirePlaying();
    return _next(board, _progress.copy(), boosters: 1);
  }

  /// Restores the previous snapshot. [boostersUsed] is kept.
  GameState undo() {
    final p = previous;
    if (p == null) throw StateError('Nothing to undo');
    return GameState._(
      board: p.board,
      progress: p._progress.copy(),
      addNumbersLimit: p.addNumbersLimit,
      addNumbersUsed: p.addNumbersUsed,
      boostersUsed: boostersUsed,
      moveCount: p.moveCount,
      previous: p.previous,
    );
  }

  /// Applies any [Move] (dispatcher for UI / replays).
  GameState apply(Move m) => switch (m) {
    PairMove(:final a, :final b) => pair(a, b),
    AddNumbersMove() => addNumbers(),
    HammerMove(:final cell) => hammer(cell),
    SwapMove(:final a, :final b) => swap(a, b),
    HintMove() => useHint(),
    UndoMove() => undo(),
  };
}
