import 'package:flutter/material.dart';

import '../game/game_result.dart';
import '../l10n/app_localizations.dart';
import 'level_start_sheet.dart';

/// STUB game screen so the shell works standalone. Replaced by the
/// `m2-gameplay` board screen via [GameScreenBuilder] (docs/m2-seam.md).
/// Debug buttons pop a [GameResult].
class StubGameScreen extends StatefulWidget {
  const StubGameScreen({super.key, required this.args});
  final GameArgs args;

  static Widget builder(BuildContext context, GameArgs args) => StubGameScreen(args: args);

  @override
  State<StubGameScreen> createState() => _StubGameScreenState();
}

class _StubGameScreenState extends State<StubGameScreen> {
  int _boosters = 0;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final l = widget.args.level;
    return Scaffold(
      appBar: AppBar(title: Text(t.level(l.id))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t.goals, style: Theme.of(context).textTheme.titleLarge),
          for (final g in l.goals) Text(goalText(t, g)),
          const SizedBox(height: 8),
          Text('${l.columns}×${l.rows} · +${widget.args.extraAddNumbers}'),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text(t.debugBoosters(_boosters))),
            IconButton(
              key: const Key('debugBoosterMinus'),
              onPressed: _boosters > 0 ? () => setState(() => _boosters--) : null,
              icon: const Icon(Icons.remove),
            ),
            IconButton(
              key: const Key('debugBoosterPlus'),
              onPressed: () => setState(() => _boosters++),
              icon: const Icon(Icons.add),
            ),
          ]),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('debugWin'),
            onPressed: () => Navigator.pop(context, GameResult.win(levelId: l.id, boostersUsed: _boosters)),
            child: Text(t.debugWin),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('debugLose'),
            onPressed: () => Navigator.pop(context, GameResult.lose(levelId: l.id, boostersUsed: _boosters)),
            child: Text(t.debugLose),
          ),
        ],
      ),
    );
  }
}
