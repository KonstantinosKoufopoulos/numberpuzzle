import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'theme.dart';

enum WinAction { next, map }


/// Win screen (wireframe 09). Pops with [WinAction]. No ad is shown here;
/// the interstitial hook runs only after the player taps Next.
class WinScreen extends StatelessWidget {
  const WinScreen({super.key, required this.levelId, required this.stars, required this.hasNext, this.subtitle});
  final int levelId;

  /// Replaces «Level N» (e.g. the daily puzzle).
  final String? subtitle;
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
                  Text(subtitle ?? t.level(levelId)),
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
