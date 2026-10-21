/// M2 seam between the shell (map / start / win / lose) and the game screen.
/// See docs/m2-seam.md.
library;

import 'package:flutter/material.dart';

import '../ads/ad_service.dart';
import '../engine/level.dart';
import '../engine/scoring.dart';

/// What a finished (or abandoned) game reports back to the shell.
@immutable
class GameResult {
  const GameResult({
    required this.levelId,
    required this.won,
    required this.boostersUsed,
    required this.starsEarned,
    this.boostersSpent = const {},
  });

  /// A win; stars come from [starsForWin] (Add numbers / undo never count).
  factory GameResult.win({
    required int levelId,
    required int boostersUsed,
    Map<String, int> boostersSpent = const {},
  }) => GameResult(
    levelId: levelId,
    won: true,
    boostersUsed: boostersUsed,
    starsEarned: starsForWin(boostersUsed: boostersUsed),
    boostersSpent: boostersSpent,
  );

  /// A loss (out of moves). Always 0 stars.
  factory GameResult.lose({required int levelId, int boostersUsed = 0, Map<String, int> boostersSpent = const {}}) =>
      GameResult(
        levelId: levelId,
        won: false,
        boostersUsed: boostersUsed,
        starsEarned: 0,
        boostersSpent: boostersSpent,
      );

  final int levelId;
  final bool won;

  /// Number of booster uses (hammer, swap, hint). NOT Add numbers / undo.
  final int boostersUsed;

  /// 1–3 when [won], else 0.
  final int starsEarned;

  /// Per-booster uses ('hammer', 'swap', 'hint') so the shell can decrement
  /// inventory. Sum should equal [boostersUsed].
  final Map<String, int> boostersSpent;

  @override
  String toString() => 'GameResult(levelId: $levelId, won: $won, boostersUsed: $boostersUsed, stars: $starsEarned)';
}

/// Everything the game screen receives.
@immutable
class GameArgs {
  const GameArgs({
    required this.level,
    required this.ads,
    required this.boosters,
    this.isDaily = false,
    this.extraAddNumbers = 0,
    this.onRequestRewarded,
  });

  final Level level;
  final AdService ads;

  /// Booster inventory at level start (read-only snapshot).
  final Map<String, int> boosters;
  final bool isDaily;

  /// Extra "Add numbers" granted by a rewarded ad on the lose screen.
  final int extraAddNumbers;

  /// In-level rewarded request (lose overlay "+1 Add numbers ▶"). Resolves
  /// true only after the SDK reported the reward; null/false = no ad.
  final Future<bool> Function()? onRequestRewarded;
}

/// Builds the game screen. The screen must `Navigator.pop(context, GameResult)`
/// when the level ends; popping with null (back button) = abandoned.
typedef GameScreenBuilder = Widget Function(BuildContext context, GameArgs args);

/// Route the map pushes. Pops with a [GameResult] or null if abandoned.
class GameRoute extends MaterialPageRoute<GameResult> {
  GameRoute({required this.levelId, required GameArgs args, required GameScreenBuilder builder})
    : assert(args.level.id == levelId),
      super(
        settings: RouteSettings(name: '/game/$levelId'),
        builder: (c) => builder(c, args),
      );

  final int levelId;
}
