import 'package:flutter/material.dart';

import '../ads/ad_service.dart';
import '../l10n/app_localizations.dart';
import '../levels/level_repository.dart';
import 'level_map_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.ads, required this.levels});

  final AdService ads;
  final LevelRepository levels;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.appTitle, style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => LevelMapScreen(ads: ads, levels: levels),
              )),
              child: Text(t.classic),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(t.comingSoon))),
              child: Text(t.daily),
            ),
          ],
        ),
      ),
    );
  }
}
