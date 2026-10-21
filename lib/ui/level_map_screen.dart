import 'dart:async';

import 'package:flutter/material.dart';

import '../ads/ad_policy.dart';
import '../ads/ad_service.dart';
import '../engine/level.dart';
import '../game/game_result.dart';
import '../l10n/app_localizations.dart';
import '../levels/level_repository.dart';
import '../storage/progress_store.dart';
import 'intro_cards.dart';
import 'level_start_sheet.dart';
import 'result_screens.dart';
import 'theme.dart';

enum NodeState { locked, unlocked, current }

/// Level map (wireframe 02) – the app's home. Owns the shell flow:
/// start sheet → gift/intro cards (first time only) → [GameRoute] →
/// win/lose screens → interstitial hook (only after "Next").
class LevelMapScreen extends StatefulWidget {
  const LevelMapScreen({
    super.key,
    required this.ads,
    required this.levels,
    required this.progress,
    required this.gameBuilder,
  });

  final AdService ads;
  final LevelRepository levels;
  final ProgressController progress;
  final GameScreenBuilder gameBuilder;

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends State<LevelMapScreen> {
  late final Future<LevelPack> _pack = widget.levels.load();
  final _currentKey = GlobalKey();
  bool _scrolled = false;

  static const double _nodeExtent = 96;

  @override
  void initState() {
    super.initState();
    widget.progress.addListener(_onProgress);
    if (!widget.progress.isLoaded) widget.progress.load();
  }

  @override
  void dispose() {
    widget.progress.removeListener(_onProgress);
    super.dispose();
  }

  void _onProgress() {
    if (mounted) setState(() {});
  }

  int _current(int total) {
    final u = widget.progress.progress.unlockedLevel;
    return u > total ? total : u;
  }

  void _scrollToCurrent() {
    final ctx = _currentKey.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.5, duration: const Duration(milliseconds: 300));
  }

  /// In-level rewarded (game lose overlay). True only after onUserEarnedReward.
  Future<bool> _requestRewarded() {
    var earned = false;
    final done = Completer<bool>();
    final outcome = RewardedController(widget.ads.rewardedSource).onUserTap(
      grantReward: () => earned = true,
      onClosed: () {
        if (!done.isCompleted) done.complete(earned);
      },
    );
    if (outcome == RewardedOutcome.noAdAvailable) return Future.value(false);
    return done.future;
  }

  Future<void> _play(List<Level> levels, Level level, {bool skipStart = false, int extraAdd = 0}) async {
    final pc = widget.progress;
    if (!skipStart && !await showLevelStartSheet(context, level)) return;
    if (!mounted) return;

    final gift = level.gift;
    if (gift != null && !pc.progress.seenIntros.contains(giftKey(gift))) {
      await showGiftCard(context, gift);
      await pc.addBooster(gift, kGiftAmount);
      await pc.markIntroSeen(giftKey(gift));
      if (!mounted) return;
    }
    final intro = level.introduces;
    if (intro != null && !pc.progress.seenIntros.contains(introKey(intro))) {
      await showIntroCard(context, level);
      await pc.markIntroSeen(introKey(intro));
      if (!mounted) return;
    }

    final result = await Navigator.of(context).push(GameRoute(
      levelId: level.id,
      args: GameArgs(
        level: level,
        ads: widget.ads,
        boosters: Map.unmodifiable(pc.progress.boosters),
        extraAddNumbers: extraAdd,
        onRequestRewarded: _requestRewarded,
      ),
      builder: widget.gameBuilder,
    ));
    if (result == null || !mounted) return; // abandoned
    if (result.boostersSpent.isNotEmpty) await pc.spendBoosters(result.boostersSpent);
    if (!mounted) return;

    final idx = levels.indexWhere((l) => l.id == level.id);
    final next = idx >= 0 && idx + 1 < levels.length ? levels[idx + 1] : null;

    if (result.won) {
      await pc.recordWin(level.id, result.starsEarned);
      if (!mounted) return;
      final action = await Navigator.of(context).push(MaterialPageRoute<WinAction>(
        settings: const RouteSettings(name: '/win'),
        builder: (_) => WinScreen(levelId: level.id, stars: result.starsEarned, hasNext: next != null),
      ));
      if (!mounted) return;
      if (action == WinAction.next && next != null) {
        // The ONLY interstitial moment: win screen left via Next. Policy
        // (no ads L1–3, 1 per 3 levels, ≥3 min, never daily) is in AdPolicy.
        await widget.ads.maybeShowInterstitial(levelId: level.id, isDaily: false);
        if (mounted) await _play(levels, next);
      }
    } else {
      final action = await Navigator.of(context).push(MaterialPageRoute<LoseAction>(
        settings: const RouteSettings(name: '/lose'),
        builder: (_) => LoseScreen(levelId: level.id, rewarded: RewardedController(widget.ads.rewardedSource)),
      ));
      if (!mounted) return;
      switch (action) {
        case LoseAction.retry:
          await _play(levels, level, skipStart: true);
        case LoseAction.rewardedContinue:
          await _play(levels, level, skipStart: true, extraAdd: extraAdd + 1);
        case LoseAction.map || null:
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.appTitle), centerTitle: true),
      body: FutureBuilder<LevelPack>(
        future: _pack,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          if (!snap.hasData || !widget.progress.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final levels = snap.data!.levels;
          final current = _current(levels.length);
          final currentLevel = levels.firstWhere((l) => l.id == current, orElse: () => levels.last);
          final done = widget.progress.progress.stars.keys.where((k) => k <= levels.length).length;
          if (!_scrolled) {
            _scrolled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(children: [
                  Expanded(
                    child: _EntryCard(
                      key: const Key('dailyEntry'),
                      icon: Icons.local_fire_department,
                      label: t.daily,
                      sub: t.mapDailyStreak(0),
                      onTap: () => ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(t.comingSoon))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _EntryCard(
                      key: const Key('classicEntry'),
                      icon: Icons.grid_view_rounded,
                      label: t.classic,
                      sub: t.mapClassicContinue,
                      onTap: () => _play(levels, currentLevel),
                    ),
                  ),
                ]),
              ),
              Expanded(
                child: SingleChildScrollView(
                  key: const Key('mapScroll'),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      for (final (i, l) in levels.indexed)
                        SizedBox(
                          height: _nodeExtent,
                          child: Align(
                            alignment: Alignment([-0.5, 0.0, 0.5, 0.0][i % 4], 0),
                            child: _LevelNode(
                              key: l.id == current ? _currentKey : ValueKey('node-${l.id}'),
                              level: l,
                              state: l.id == current
                                  ? NodeState.current
                                  : l.id < current
                                      ? NodeState.unlocked
                                      : NodeState.locked,
                              stars: widget.progress.progress.starsFor(l.id),
                              label: _nodeLabel(t, l),
                              onTap: () => _play(levels, l),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(children: [
                  Text(t.mapWorld(levels.length, done), key: const Key('worldProgress')),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('playCurrent'),
                      onPressed: () => _play(levels, currentLevel),
                      child: Text(t.mapPlay(current)),
                    ),
                  ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  String? _nodeLabel(AppLocalizations t, Level l) {
    if (l.introduces != null) return introContent(t, l.introduces!).$1;
    return switch (l.gift) {
      'hammer' => t.boosterHammer,
      'swap' => t.boosterSwap,
      _ => null,
    };
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({super.key, required this.icon, required this.label, required this.sub, required this.onTap});
  final IconData icon;
  final String label, sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 20),
                const SizedBox(width: 6),
                Flexible(child: Text(label, style: Theme.of(context).textTheme.titleLarge, overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 4),
              Text(sub, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      );
}

class _LevelNode extends StatelessWidget {
  const _LevelNode({super.key, required this.level, required this.state, required this.stars, required this.onTap, this.label});
  final Level level;
  final NodeState state;
  final int stars;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = Theme.of(context).extension<GamePalette>()!;
    final locked = state == NodeState.locked;
    final current = state == NodeState.current;
    final size = current ? 64.0 : 54.0;
    return Semantics(
      label: 'level-${level.id}-${state.name}-$stars',
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: locked ? null : onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: locked ? p.cleared : (current ? cs.primary : cs.surface),
              border: Border.all(color: locked ? p.cellBorder : cs.primary, width: current ? 4 : 2),
            ),
            alignment: Alignment.center,
            child: locked
                ? Icon(Icons.lock, size: 20, color: p.textMuted, key: Key('lock-${level.id}'))
                : Text('${level.id}',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800, color: current ? cs.onPrimary : cs.onSurface)),
          ),
        ),
        if (!locked && stars > 0)
          Text('★' * stars + '☆' * (3 - stars),
              key: Key('stars-${level.id}'), style: TextStyle(color: p.star, fontSize: 14))
        else if (label != null)
          Text(label!, style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}
