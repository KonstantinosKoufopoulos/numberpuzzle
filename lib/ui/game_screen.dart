import 'package:flutter/material.dart';

import '../ads/ad_policy.dart';
import '../ads/ad_service.dart';
import '../engine/level.dart';
import '../l10n/app_localizations.dart';

/// Placeholder game screen (board rendering arrives in M1/M3).
/// Shows goals, the first-time intro card, a debug win button and the
/// rewarded button. Interstitial only after the win dialog is dismissed.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.level, required this.ads, this.isDaily = false});

  final Level level;
  final AdService ads;
  final bool isDaily;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final RewardedController _rewarded = RewardedController(widget.ads.rewardedSource);

  @override
  void initState() {
    super.initState();
    // TODO(M2): consult Progress.seenIntros so the card shows only once.
    if (widget.level.introduces != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showIntro());
    }
  }

  (String, String) _introText(AppLocalizations t, String id) => switch (id) {
        'stars' => (t.introStarsTitle, t.introStarsBody),
        'grass' => (t.introGrassTitle, t.introGrassBody),
        'stone' => (t.introStoneTitle, t.introStoneBody),
        'ice' => (t.introIceTitle, t.introIceBody),
        _ => (t.introSlimeTitle, t.introSlimeBody),
      };

  Future<void> _showIntro() async {
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    final (title, body) = _introText(t, widget.level.introduces!);
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(t.gotIt))],
      ),
    );
  }

  Future<void> _win() async {
    final t = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.win),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(t.continueLabel))],
      ),
    );
    // Win screen dismissed: the only allowed interstitial moment.
    await widget.ads.maybeShowInterstitial(levelId: widget.level.id, isDaily: widget.isDaily);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final l = widget.level;
    return Scaffold(
      appBar: AppBar(title: Text(t.level(l.id))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t.goals, style: Theme.of(context).textTheme.titleLarge),
          for (final g in l.goals)
            Text('${g.type.name}${g.value != null ? ' ${g.value}' : ''} × ${g.count}'),
          const SizedBox(height: 16),
          Text('${l.columns}×${l.rows}'),
          const SizedBox(height: 24),
          FilledButton(onPressed: _win, child: Text(t.debugWin)),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _rewarded.showNoAdText
                ? null
                : () => _rewarded.onUserTap(grantReward: () {
                      // TODO(M3): grant booster to Progress.
                    }),
            child: Text(_rewarded.showNoAdText ? t.noAdAvailable : t.watchAdReward),
          ),
        ],
      ),
    );
  }
}
