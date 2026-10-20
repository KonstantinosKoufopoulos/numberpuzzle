import 'package:flutter/material.dart';

import '../engine/level.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';

/// Persisted key for a seen obstacle intro card.
String introKey(String id) => 'intro:$id';

/// Persisted key for a received booster gift.
String giftKey(String id) => 'gift:$id';

/// Boosters granted by a `gift` level (spec: ×2).
const int kGiftAmount = 2;

(String, String, IconData) introContent(AppLocalizations t, String id) => switch (id) {
      'stars' => (t.introStarsTitle, t.introStarsBody, Icons.star_rounded),
      'grass' => (t.introGrassTitle, t.introGrassBody, Icons.grass),
      'stone' => (t.introStoneTitle, t.introStoneBody, Icons.block),
      'ice' => (t.introIceTitle, t.introIceBody, Icons.ac_unit),
      _ => (t.introSlimeTitle, t.introSlimeBody, Icons.bubble_chart),
    };

Color _accent(BuildContext c, String id) {
  final p = Theme.of(c).extension<GamePalette>()!;
  return switch (id) {
    'stars' => p.star,
    'grass' => p.grass,
    'stone' => p.stone,
    'ice' => p.ice,
    'slime' => p.slime,
    _ => p.star,
  };
}

/// First-time obstacle explainer (wireframes 05/14/16/17/19).
Future<void> showIntroCard(BuildContext context, Level level) {
  final id = level.introduces!;
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) {
      final t = AppLocalizations.of(c);
      final (name, body, icon) = introContent(t, id);
      return _Card(
        key: const Key('introCard'),
        icon: icon,
        accent: _accent(c, id),
        title: t.introNew(level.id, name),
        body: body,
        cta: t.introOk,
      );
    },
  );
}

/// Booster gift card (wireframes 15/18).
Future<void> showGiftCard(BuildContext context, String booster) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) {
      final t = AppLocalizations.of(c);
      final isHammer = booster == 'hammer';
      return _Card(
        key: const Key('giftCard'),
        icon: isHammer ? Icons.gavel : Icons.swap_horiz,
        accent: Theme.of(c).colorScheme.secondary,
        title: t.giftTitle(isHammer ? t.boosterHammer : t.boosterSwap, kGiftAmount),
        body: isHammer ? t.giftHammerBody : t.giftSwapBody,
        cta: isHammer ? t.giftTakeHammer : t.giftTakeSwap,
      );
    },
  );
}

class _Card extends StatelessWidget {
  const _Card({super.key, required this.icon, required this.accent, required this.title, required this.body, required this.cta});
  final IconData icon;
  final Color accent;
  final String title, body, cta;

  @override
  Widget build(BuildContext context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(radius: 32, backgroundColor: accent, child: Icon(icon, size: 34, color: Colors.black87)),
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(body, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: () => Navigator.pop(context), child: Text(cta)),
              ),
            ],
          ),
        ),
      );
}
