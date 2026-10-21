import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../engine/board.dart';
import '../../engine/cell.dart';
import '../../engine/game.dart';
import '../../engine/hint.dart';
import '../../engine/level.dart';
import '../../engine/moves.dart';
import '../../engine/rules.dart' as rules;
import '../../levels/hint_runner.dart';
import '../../storage/game_save_store.dart';
import '../tokens.dart';

/// Booster ids shared with the shell's inventory map.
abstract final class BoosterId {
  static const hammer = 'hammer';
  static const swap = 'swap';
  static const hint = 'hint';
  static const all = [hammer, swap, hint];
}

enum ToolMode { none, hammer, swap }

/// Result of tapping a booster button.
enum BoosterTap { activated, cancelled, noStock, busy }

/// UI state and actions for one level (testable without widgets).
class GameController extends ChangeNotifier {
  GameController({
    required this.level,
    required this.initialBoard,
    required GameState state,
    required Map<String, int> boosters,
    required this.store,
    required this.hints,
    Map<String, int> spent = const {},
    this.onBoosterSpent,
    this.nextStageBoard,
    bool tutorialDone = true,
    this.clearDuration = Tk.clear,
  }) : _state = state,
       _inventory = {for (final id in BoosterId.all) id: boosters[id] ?? 0},
       spent = Map.of(spent) {
    if (level.id == 1 && !tutorialDone && state.moveCount == 0) {
      tutorialStep = 1;
      _pickTutorialPair();
    }
  }

  final Level level;
  final Board initialBoard;

  /// Classic: deals the next board when the current one is cleared.
  final Board Function(GameState cleared)? nextStageBoard;

  /// Inventory snapshot from GameArgs (already reflects earlier spends).
  final Map<String, int> _inventory;

  /// Boosters consumed from the inventory in this level (GameResult.boostersSpent).
  final Map<String, int> spent;
  final GameSaveStore store;
  final HintRunner hints;
  final Duration clearDuration;

  GameState _state;
  GameState get state => _state;

  int? selected;
  ToolMode mode = ToolMode.none;

  /// Cells currently shaking (invalid pair / hammer on stone).
  Set<int> shaking = {};
  int shakeTick = 0;

  /// Stone cell showing ✕ after a hammer attempt.
  int? blockedCell;

  /// Pair being cleared (selection line + clear animation).
  (int, int)? clearing;

  /// Pair highlighted by the hint or tutorial.
  (int, int)? hintPair;

  /// Hint suggested "Add numbers".
  bool hintAdd = false;
  bool hintBusy = false;

  /// 0 = no tutorial; 1..3 = current step (level 1, first time).
  int tutorialStep = 0;

  Timer? _clearTimer, _shakeTimer;
  bool _disposed = false;

  GameStatus get status => _state.status;
  bool get busy => clearing != null;

  /// Persists an inventory decrement immediately (shell callback).
  final Future<void> Function(String id)? onBoosterSpent;

  /// Spent since this screen opened. [_inventory] is the already-persisted
  /// count at open time, so a resumed level doesn't subtract [spent] again.
  final Map<String, int> _sessionSpent = {};

  int boosterCount(String id) => (_inventory[id] ?? 0) - (_sessionSpent[id] ?? 0);

  bool _consume(String id) {
    if (boosterCount(id) <= 0) return false;
    spent[id] = (spent[id] ?? 0) + 1;
    _sessionSpent[id] = (_sessionSpent[id] ?? 0) + 1;
    final cb = onBoosterSpent;
    if (cb != null) unawaited(cb(id));
    return true;
  }

  // ---- cell taps ---------------------------------------------------------

  void tapCell(int i) {
    if (busy || status != GameStatus.playing || i < 0 || i >= _state.board.length) return;
    switch (mode) {
      case ToolMode.hammer:
        _hammer(i);
      case ToolMode.swap:
        _swapTap(i);
      case ToolMode.none:
        _pairTap(i);
    }
  }

  void _pairTap(int i) {
    final cell = _state.board[i];
    if (!cell.isSelectable) {
      if (selected != null || !cell.isEmpty) _shake({i, ?selected});
      selected = null;
      _notify();
      return;
    }
    final s = selected;
    if (s == null) {
      selected = i;
    } else if (s == i) {
      selected = null;
    } else if (_state.canPair(s, i)) {
      selected = null;
      _startClear(s, i);
      return;
    } else {
      selected = null;
      _shake({s, i});
    }
    _notify();
  }

  void _startClear(int a, int b) {
    clearing = (a, b);
    hintPair = null;
    hintAdd = false;
    _notify();
    _clearTimer?.cancel();
    _clearTimer = Timer(clearDuration, () {
      clearing = null;
      _commit(_state.pair(a, b));
      if (tutorialStep > 0) _advanceTutorial();
      _notify();
    });
  }

  void _shake(Set<int> cells) {
    shaking = cells;
    shakeTick++;
    _shakeTimer?.cancel();
    _shakeTimer = Timer(Tk.shake, () {
      shaking = {};
      blockedCell = null;
      _notify();
    });
  }

  void _hammer(int i) {
    final c = _state.board[i];
    if (c.obstacle?.kind == ObstacleKind.stone) {
      // Stone: ✕ + shake, booster NOT consumed, hammer stays armed.
      blockedCell = i;
      _shake({i});
      _notify();
      return;
    }
    if (!const HammerBooster().canApply(_state.board, i)) return;
    if (!_consume(BoosterId.hammer)) return;
    mode = ToolMode.none;
    _commit(_state.hammer(i));
    _notify();
  }

  void _swapTap(int i) {
    if (!_state.board[i].isSelectable) {
      _shake({i});
      _notify();
      return;
    }
    final s = selected;
    if (s == null || s == i) {
      selected = s == i ? null : i;
      _notify();
      return;
    }
    if (!_consume(BoosterId.swap)) return;
    selected = null;
    mode = ToolMode.none;
    _commit(_state.swap(s, i));
    _notify();
  }

  // ---- buttons -------------------------------------------------------------

  /// Arms/disarms hammer or swap.
  BoosterTap toggleTool(ToolMode tool) {
    if (busy || status != GameStatus.playing) return BoosterTap.busy;
    if (mode == tool) {
      mode = ToolMode.none;
      selected = null;
      _notify();
      return BoosterTap.cancelled;
    }
    final id = tool == ToolMode.hammer ? BoosterId.hammer : BoosterId.swap;
    if (boosterCount(id) <= 0) return BoosterTap.noStock;
    mode = tool;
    selected = null;
    hintPair = null;
    _notify();
    return BoosterTap.activated;
  }

  /// Runs the hint off the UI thread. Consumes a hint only when something
  /// useful (a pair or "Add numbers") is found.
  Future<BoosterTap> useHint() async {
    if (busy || hintBusy || status != GameStatus.playing) return BoosterTap.busy;
    if (boosterCount(BoosterId.hint) <= 0) return BoosterTap.noStock;
    mode = ToolMode.none;
    selected = null;
    hintBusy = true;
    _notify();
    final before = _state;
    Hint h;
    try {
      h = await hints(before.board, before.progress, before.addNumbersLeft);
    } on Object {
      final p = rules.allValidPairs(before.board);
      h = p.isNotEmpty ? Hint.pair(p.first.$1, p.first.$2) : const Hint.none();
    }
    hintBusy = false;
    if (_disposed || !identical(before, _state)) {
      _notify();
      return BoosterTap.busy;
    }
    if (h.pair == null && !h.addNumbers) {
      _notify();
      return BoosterTap.cancelled;
    }
    _consume(BoosterId.hint);
    _state = _state.useHint();
    hintPair = h.pair;
    hintAdd = h.addNumbers;
    _save();
    _notify();
    return BoosterTap.activated;
  }

  /// Valid pairs on the board (for the "Add numbers" confirmation).
  int get pairsAvailable => rules.allValidPairs(_state.board).length;

  void addNumbers() {
    if (busy || !_state.canAddNumbers || status != GameStatus.playing) return;
    selected = null;
    mode = ToolMode.none;
    _commit(_state.addNumbers());
    _notify();
  }

  void undo() {
    if (busy || !_state.canUndo || status != GameStatus.playing) return;
    selected = null;
    mode = ToolMode.none;
    hintPair = null;
    hintAdd = false;
    _state = _state.undo();
    _save();
    _notify();
  }

  /// Rewarded continue after a loss: +[extra] Add numbers on the SAME state.
  void continueWithExtraAddNumbers([int extra = 1]) {
    if (status != GameStatus.lost) return;
    _state = _state.withExtraAddNumbers(extra);
    _save();
    _notify();
  }

  void skipTutorial() {
    tutorialStep = 0;
    hintPair = null;
    unawaited(store.setTutorialDone());
    _notify();
  }

  // ---- internals -----------------------------------------------------------

  void _commit(GameState next) {
    final deal = nextStageBoard;
    if (next.endless && deal != null && next.board.isCleared) next = next.nextStage(deal(next));
    _state = next;
    hintPair = tutorialStep > 0 ? hintPair : null;
    hintAdd = false;
    switch (next.status) {
      case GameStatus.won:
        if (tutorialStep > 0) {
          tutorialStep = 0;
          unawaited(store.setTutorialDone());
        }
        unawaited(store.clear());
      case GameStatus.lost:
        // Kept: the lose overlay may continue this state after a reward.
        _save();
      case GameStatus.playing:
        _save();
    }
  }

  void _advanceTutorial() {
    if (status != GameStatus.playing) return;
    if (tutorialStep >= 3) {
      skipTutorial();
      return;
    }
    tutorialStep++;
    _pickTutorialPair();
  }

  void _pickTutorialPair() {
    final pairs = rules.allValidPairs(_state.board);
    if (pairs.isEmpty) {
      hintPair = null;
      return;
    }
    final b = _state.board;
    hintPair = pairs.firstWhere((p) => b[p.$1].value != b[p.$2].value, orElse: () => pairs.first);
  }

  void _save() {
    if (status == GameStatus.won) return;
    unawaited(store.save(SavedGame(levelId: level.id, initialBoard: initialBoard, state: _state, spent: spent)));
  }

  /// Give up / level over: forget the saved in-level state.
  Future<void> clearSave() => store.clear();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _clearTimer?.cancel();
    _shakeTimer?.cancel();
    super.dispose();
  }
}
