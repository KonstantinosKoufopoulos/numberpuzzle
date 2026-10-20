import 'package:flutter/material.dart';

import '../engine/goals.dart';
import '../engine/level.dart';
import '../l10n/app_localizations.dart';

String goalText(AppLocalizations t, Goal g) => switch (g.type) {
      GoalType.pairsSame => t.goalPairsSame(g.count),
      GoalType.pairsTen => t.goalPairsTen(g.count),
      GoalType.number => t.goalNumber(g.count, g.value ?? 0),
      GoalType.star => t.goalStar(g.count),
      GoalType.grass => t.goalGrass(g.count),
      _ when g.type.name == 'ice' => t.goalIce(g.count),
      _ when g.type.name == 'slime' => t.goalSlime(g.count),
      _ => t.goalOther(g.type.name, g.count),
    };

/// Level start card (wireframe 04). Resolves true when the player taps Start.
Future<bool> showLevelStartSheet(BuildContext context, Level level) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (c) {
      final t = AppLocalizations.of(c);
      final tt = Theme.of(c).textTheme;
      return SafeArea(
        child: Padding(
          key: const Key('levelStartSheet'),
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.level(level.id), style: tt.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(t.startNoTimer, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              for (final g in level.goals)
                ListTile(dense: true, leading: const Icon(Icons.flag_outlined), title: Text(goalText(t, g))),
              const SizedBox(height: 8),
              Text(t.startStars, textAlign: TextAlign.center, style: tt.bodySmall),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('startButton'),
                onPressed: () => Navigator.pop(c, true),
                child: Text(t.startCta),
              ),
            ],
          ),
        ),
      );
    },
  );
  return r ?? false;
}
