import 'dart:async';

import 'package:flutter/material.dart';

import '../../engine/board.dart';
import '../../engine/game.dart';
import '../../engine/goals.dart';
import '../../game/game_result.dart';
import '../../l10n/app_localizations.dart';
import '../../levels/board_source.dart';
import '../../levels/hint_runner.dart';
import '../../storage/game_save_store.dart';
import '../theme.dart';
import '../tokens.dart';
import 'board_view.dart';
import 'game_controller.dart';

/// The real M2 game screen (plugs into the shell via [GameScreenBuilder]).
///
/// Loads (or resumes) the board, runs the level and pops a [GameResult]:
/// `win` as soon as all goals are met, `lose` only when the player gives up
/// on the lose overlay. Back button = abandoned (null); the in-level state
/// stays saved for resume.
/// How long the «no ad available» message stays up (also hidden on the next action).
const Duration kNoAdMessageDuration = Duration(seconds: 3);

class BoardGameScreen extends StatefulWidget {
  const BoardGameScreen({
    super.key,
    required this.args,
    this.boards,
    this.hints = computeHintOffThread,
    this.saves,
    this.clearDuration = Tk.clear,
  });

  final GameArgs args;
  final LevelBoardSource? boards;
  final HintRunner hints;
  final GameSaveStore? saves;
  final Duration clearDuration;

  /// App-wide board source. Swap this ONE line for the prebaked
  /// `assets/levels/boards.json` source when it lands.
  static LevelBoardSource defaultBoards = GeneratedBoardSource();

  static Widget builder(BuildContext context, GameArgs args) => BoardGameScreen(args: args);

  @override
  State<BoardGameScreen> createState() => _BoardGameScreenState();
}

class _BoardGameScreenState extends State<BoardGameScreen> {
  late final GameSaveStore _saves = widget.saves ?? GameSaveStore();
  GameController? _c;
  bool _error = false;
  bool _popped = false;
  bool _noAd = false;
  Timer? _noAdTimer;
  bool _rewardBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    final level = widget.args.level;
    try {
      final tutorialDone = await _saves.tutorialDone();
      final saved = await _saves.load(level);
      final GameController c;
      if (saved != null) {
        c = _controller(saved.initialBoard, saved.state, saved.spent, tutorialDone);
      } else {
        final board = await (widget.boards ?? BoardGameScreen.defaultBoards).boardFor(level);
        final s = GameState.forLevel(level, board);
        c = _controller(board, s, const {}, tutorialDone);
      }
      if (!mounted) return c.dispose();
      c.addListener(_onChange);
      setState(() => _c = c);
    } on BoardLoadException {
      if (mounted) setState(() => _error = true);
    }
  }

  GameController _controller(Board board, GameState s, Map<String, int> spent, bool tutorialDone) => GameController(
    level: widget.args.level,
    initialBoard: board,
    state: s,
    boosters: widget.args.boosters,
    spent: spent,
    onBoosterSpent: widget.args.onBoosterSpent,
    tutorialDone: tutorialDone,
    store: _saves,
    hints: widget.hints,
    clearDuration: widget.clearDuration,
  );

  void _onChange() {
    final c = _c!;
    if (c.status == GameStatus.won && !_popped) {
      _popped = true;
      Timer(Tk.collapse, () {
        if (mounted) {
          Navigator.of(context).pop(
            GameResult.win(levelId: c.level.id, boostersUsed: c.state.boostersUsed, boostersSpent: Map.of(c.spent)),
          );
        }
      });
    }
    setState(() {});
  }

  @override
  void dispose() {
    _noAdTimer?.cancel();
    _c?.dispose();
    super.dispose();
  }

  void _noAdSnack() {
    final t = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t.noAdAvailable), duration: kNoAdMessageDuration));
  }

  void _hideMessages() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _noAdTimer?.cancel();
    if (_noAd) setState(() => _noAd = false);
  }

  Future<void> _tool(ToolMode m) async {
    _hideMessages();
    if (_c!.toggleTool(m) == BoosterTap.noStock) _noAdSnack();
  }

  Future<void> _hint() async {
    _hideMessages();
    final t = AppLocalizations.of(context);
    final r = await _c!.useHint();
    if (!mounted) return;
    if (r == BoosterTap.noStock) _noAdSnack();
    if (r == BoosterTap.activated && _c!.hintAdd) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.hintAddNumbers)));
    }
  }

  Future<void> _add() async {
    final c = _c!;
    final t = AppLocalizations.of(context);
    final n = c.pairsAvailable;
    if (n > 0) {
      final choice = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
          content: Text(t.addConfirm(n)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: Text(t.notNow)),
            TextButton(onPressed: () => Navigator.pop(d, 'hint'), child: Text(t.addAlt)),
            FilledButton(
              key: const Key('add-confirm'),
              onPressed: () => Navigator.pop(d, 'add'),
              child: Text(t.addConfirmYes),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (choice == 'hint') return _hint();
      if (choice != 'add') return;
    }
    c.addNumbers();
  }

  Future<void> _reward() async {
    final cb = widget.args.onRequestRewarded;
    _hideMessages();
    setState(() => _rewardBusy = true);
    final ok = cb == null ? false : await cb().catchError((Object _) => false);
    if (!mounted) return;
    setState(() {
      _rewardBusy = false;
      _noAd = !ok;
    });
    if (!ok) _noAdTimer = Timer(kNoAdMessageDuration, () => mounted ? setState(() => _noAd = false) : null);
    if (ok) _c!.continueWithExtraAddNumbers();
  }

  Future<void> _exit({required bool retry}) async {
    _hideMessages();
    final c = _c!;
    await c.clearSave();
    if (!mounted || _popped) return;
    _popped = true;
    Navigator.of(context).pop(
      GameResult.lose(
        levelId: c.level.id,
        boostersUsed: c.state.boostersUsed,
        boostersSpent: Map.of(c.spent),
        retry: retry,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = _c;
    return Scaffold(
      appBar: AppBar(title: Text(t.level(widget.args.level.id)), centerTitle: true),
      body: SafeArea(
        child: c == null
            ? (_error ? _errorView(t) : _loadingView(t))
            : Stack(children: [_game(t, c), if (c.status == GameStatus.lost) _loseOverlay(t)]),
      ),
    );
  }

  Widget _loadingView(AppLocalizations t) => Center(
    key: const Key('board-loading'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: Tk.l),
        Text(t.loadingLevel),
      ],
    ),
  );

  Widget _errorView(AppLocalizations t) => Center(
    key: const Key('board-error'),
    child: Padding(
      padding: const EdgeInsets.all(Tk.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t.loadError, textAlign: TextAlign.center),
          const SizedBox(height: Tk.l),
          FilledButton(onPressed: _load, child: Text(t.retry)),
        ],
      ),
    ),
  );

  Widget _game(AppLocalizations t, GameController c) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tk.s),
      child: Column(
        children: [
          _Hud(state: c.state),
          if (c.tutorialStep > 0) _tutorial(t, c),
          if (c.mode != ToolMode.none) _modeBanner(t, c),
          if (c.hintBusy) Padding(padding: const EdgeInsets.all(Tk.xs), child: Text(t.hintSearching)),
          const SizedBox(height: Tk.s),
          Expanded(
            child: Listener(
              onPointerDown: (_) => _hideMessages(),
              child: SingleChildScrollView(child: BoardView(controller: c)),
            ),
          ),
          const SizedBox(height: Tk.s),
          _addButton(t, c, theme),
          const SizedBox(height: Tk.s),
          _boosterBar(t, c),
          const SizedBox(height: Tk.s),
        ],
      ),
    );
  }

  Widget _tutorial(AppLocalizations t, GameController c) {
    final p = c.hintPair;
    final b = c.state.board;
    final text = switch (c.tutorialStep) {
      1 when p != null =>
        b[p.$1].value == b[p.$2].value
            ? t.tutSame(b[p.$1].value!, b[p.$2].value!)
            : t.tutTen(b[p.$1].value!, b[p.$2].value!),
      2 => t.tutLines,
      _ => t.tutWrap,
    };
    return Card(
      key: const Key('tutorial'),
      margin: const EdgeInsets.only(top: Tk.s),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tk.m, vertical: Tk.xs),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.tutStep(c.tutorialStep), style: Theme.of(context).textTheme.bodySmall),
                  Text(text),
                ],
              ),
            ),
            TextButton(key: const Key('tutorial-skip'), onPressed: c.skipTutorial, child: Text(t.tutSkip)),
          ],
        ),
      ),
    );
  }

  Widget _modeBanner(AppLocalizations t, GameController c) => Padding(
    padding: const EdgeInsets.only(top: Tk.s),
    child: Row(
      children: [
        Expanded(child: Text(c.mode == ToolMode.hammer ? t.hammerMode : t.swapMode)),
        TextButton(onPressed: () => c.toggleTool(c.mode), child: Text(t.cancel)),
      ],
    ),
  );

  Widget _addButton(AppLocalizations t, GameController c, ThemeData theme) {
    final s = c.state;
    final ink = theme.extension<GamePalette>()!;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: Tk.button + Tk.s,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: OutlinedButton(
                  key: const Key('add-numbers'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tk.rCard)),
                    side: BorderSide(color: theme.colorScheme.onSurface, width: 2),
                  ),
                  onPressed: s.canAddNumbers && !c.busy && s.status == GameStatus.playing ? _add : null,
                  child: Text(t.addButton),
                ),
              ),
              Positioned(
                right: -Tk.xs,
                top: -Tk.xs,
                child: _Badge(text: '${s.addNumbersLeft}', highlight: c.hintAdd),
              ),
            ],
          ),
        ),
        const SizedBox(height: Tk.xs),
        Text(
          t.addLeft(s.addNumbersLeft, s.addNumbersLimit),
          key: const Key('add-left'),
          style: theme.textTheme.bodySmall?.copyWith(color: ink.textMuted),
        ),
      ],
    );
  }

  Widget _boosterBar(AppLocalizations t, GameController c) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _BoosterButton(
        id: BoosterId.hammer,
        icon: Icons.gavel,
        label: t.boosterHammer,
        count: c.boosterCount(BoosterId.hammer),
        active: c.mode == ToolMode.hammer,
        onTap: () => _tool(ToolMode.hammer),
      ),
      _BoosterButton(
        id: BoosterId.swap,
        icon: Icons.swap_horiz,
        label: t.boosterSwap,
        count: c.boosterCount(BoosterId.swap),
        active: c.mode == ToolMode.swap,
        onTap: () => _tool(ToolMode.swap),
      ),
      _BoosterButton(
        id: BoosterId.hint,
        icon: Icons.auto_awesome,
        label: t.boosterHint,
        count: c.boosterCount(BoosterId.hint),
        onTap: _hint,
      ),
      _BoosterButton(id: 'undo', icon: Icons.undo, label: t.undo, onTap: c.state.canUndo ? c.undo : null),
    ],
  );

  Widget _loseOverlay(AppLocalizations t) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: ColoredBox(
        color: theme.scaffoldBackgroundColor.withValues(alpha: .85),
        child: Center(
          child: Card(
            key: const Key('lose-overlay'),
            margin: const EdgeInsets.all(Tk.xl),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tk.rSheet)),
            child: Padding(
              padding: const EdgeInsets.all(Tk.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.loseTitle, style: theme.textTheme.titleLarge),
                  const SizedBox(height: Tk.s),
                  Text(t.stuckTitle, textAlign: TextAlign.center),
                  const SizedBox(height: Tk.xl),
                  SizedBox(
                    width: double.infinity,
                    height: Tk.button,
                    child: FilledButton.icon(
                      key: const Key('lose-reward'),
                      onPressed: _rewardBusy ? null : _reward,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(t.loseReward),
                    ),
                  ),
                  if (_noAd) ...[
                    const SizedBox(height: Tk.s),
                    Text(t.noAdAvailable, key: const Key('lose-no-ad'), textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: Tk.m),
                  SizedBox(
                    width: double.infinity,
                    height: Tk.button,
                    child: OutlinedButton(
                      key: const Key('lose-retry'),
                      onPressed: () => _exit(retry: true),
                      child: Text(t.loseRetry),
                    ),
                  ),
                  const SizedBox(height: Tk.s),
                  TextButton(key: const Key('lose-map'), onPressed: () => _exit(retry: false), child: Text(t.winMap)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// HUD: up to 3 goal chips with live progress (no timer).
class _Hud extends StatelessWidget {
  const _Hud({required this.state});
  final GameState state;

  static String chip(AppLocalizations t, Goal g, int d) => switch (g.type) {
    GoalType.number => t.goalChipNumber(g.value ?? 0, d, g.count),
    GoalType.star => t.goalChipStar(d, g.count),
    GoalType.grass => t.goalChipGrass(d, g.count),
    GoalType.breakIce => t.goalChipIce(d, g.count),
    GoalType.slime => t.goalChipSlime(d, g.count),
    GoalType.pairsSame => t.goalChipPairsSame(d, g.count),
    GoalType.pairsTen => t.goalChipPairsTen(d, g.count),
  };

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ink = theme.extension<GamePalette>()!;
    final goals = state.goals.take(3).toList();
    final done = state.goalDone;
    return Container(
      key: const Key('hud'),
      padding: const EdgeInsets.all(Tk.s),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(Tk.rCard),
        border: Border.all(color: ink.cellBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.startNoTimer, style: theme.textTheme.bodySmall?.copyWith(color: ink.textMuted)),
          const SizedBox(height: Tk.xs),
          Row(
            children: [
              for (var i = 0; i < goals.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Tk.xs / 2),
                    child: Container(
                      key: Key('goal-chip-$i'),
                      padding: const EdgeInsets.symmetric(vertical: Tk.s, horizontal: Tk.xs),
                      decoration: BoxDecoration(
                        color: done[i] >= goals[i].count ? ink.hint : ink.cleared,
                        borderRadius: BorderRadius.circular(Tk.rPill),
                        border: Border.all(color: done[i] >= goals[i].count ? ink.hintBorder : ink.cellBorder),
                      ),
                      child: Text(
                        chip(t, goals[i], done[i]),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({this.text, this.icon, this.highlight = false});
  final String? text;
  final IconData? icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.extension<GamePalette>()!;
    final bg = icon != null ? ink.star : (highlight ? ink.hintBorder : theme.colorScheme.primary);
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: Tk.xs),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Tk.rPill)),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, size: 14, color: theme.colorScheme.onPrimary)
          : Text(text!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimary)),
    );
  }
}

class _BoosterButton extends StatelessWidget {
  const _BoosterButton({
    required this.id,
    required this.icon,
    required this.label,
    required this.onTap,
    this.count,
    this.active = false,
  });

  final String id;
  final IconData icon;
  final String label;

  /// Null = no counter (undo).
  final int? count;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.extension<GamePalette>()!;
    final n = count;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: Tk.booster + Tk.s,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                bottom: 0,
                width: Tk.booster,
                height: Tk.booster,
                child: Material(
                  color: active ? ink.hint : theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Tk.rButton),
                    side: BorderSide(color: active ? ink.hintBorder : ink.cellBorder, width: active ? 2 : 1),
                  ),
                  child: InkWell(
                    key: Key('booster-$id'),
                    borderRadius: BorderRadius.circular(Tk.rButton),
                    onTap: onTap,
                    child: Icon(icon, color: onTap == null ? ink.textMuted : theme.colorScheme.onSurface),
                  ),
                ),
              ),
              if (n != null)
                Positioned(
                  right: 0,
                  top: 0,
                  child: KeyedSubtree(
                    key: Key('booster-$id-badge'),
                    child: n > 0 ? _Badge(text: '$n') : const _Badge(icon: Icons.play_arrow),
                  ),
                ),
            ],
          ),
        ),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
