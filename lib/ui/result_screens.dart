import 'package:flutter/material.dart';

import '../ads/ad_policy.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';

enum WinAction { next, map }

enum LoseAction { retry, map, rewardedContinue }

/// Win screen (wireframe 09). Pops with [WinAction]. No ad is shown here;
/// the interstitial hook runs only after the player taps Next.
class WinScreen extends StatelessWidget {
  const WinScreen({super.key, required this.levelId, required this.stars, required this.hasNext});
  final int levelId;
  final int stars;
  final bool hasNext;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final p = Theme.of(context).extension<GamePalette>()!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (did, _) {
        if (!did) Navigator.pop(context, WinAction.map);
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.winTitle, style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 8),
                  Text(t.level(levelId)),
                  const SizedBox(height: 24),
                  Row(
                    key: const Key('winStars'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                            key: Key('winStar$i'), size: 56, color: p.star),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(t.winStarsRule, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 32),
                  if (hasNext)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('winNext'),
                        onPressed: () => Navigator.pop(context, WinAction.next),
                        child: Text(t.winNext),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      key: const Key('winMap'),
                      onPressed: () => Navigator.pop(context, WinAction.map),
                      child: Text(t.winMap),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lose screen (wireframe 13). Pops with [LoseAction]. The rewarded button
/// only reports success from the SDK's onUserEarnedReward callback.
class LoseScreen extends StatefulWidget {
  const LoseScreen({super.key, required this.levelId, required this.rewarded});
  final int levelId;
  final RewardedController rewarded;

  @override
  State<LoseScreen> createState() => _LoseScreenState();
}

class _LoseScreenState extends State<LoseScreen> {
  bool _noAd = false;

  void _tapReward() {
    var earned = false;
    final outcome = widget.rewarded.onUserTap(
      grantReward: () => earned = true, // ONLY from SDK callback
      onClosed: () {
        if (mounted && earned) Navigator.pop(context, LoseAction.rewardedContinue);
      },
    );
    if (outcome == RewardedOutcome.noAdAvailable) setState(() => _noAd = true);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final noAd = _noAd || widget.rewarded.showNoAdText;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (did, _) {
        if (!did) Navigator.pop(context, LoseAction.map);
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.loseTitle, style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 12),
                  Text(t.loseBody, textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('loseRetry'),
                      onPressed: () => Navigator.pop(context, LoseAction.retry),
                      child: Text(t.loseRetry),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('loseReward'),
                      icon: const Icon(Icons.play_arrow),
                      onPressed: noAd ? null : _tapReward,
                      label: Text(noAd ? t.noAdAvailable : t.loseReward),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    key: const Key('loseMap'),
                    onPressed: () => Navigator.pop(context, LoseAction.map),
                    child: Text(t.winMap),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
