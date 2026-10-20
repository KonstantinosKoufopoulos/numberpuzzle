import 'package:flutter/material.dart';

import '../ads/ad_service.dart';
import '../engine/level.dart';
import '../l10n/app_localizations.dart';
import '../levels/level_repository.dart';
import 'game_screen.dart';

/// Placeholder map: grid of the 30 MVP levels. TODO(M3): real map path.
class LevelMapScreen extends StatelessWidget {
  const LevelMapScreen({super.key, required this.ads, required this.levels});

  final AdService ads;
  final LevelRepository levels;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.classic)),
      body: FutureBuilder<LevelPack>(
        future: levels.load(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!.levels;
          return GridView.count(
            crossAxisCount: 5,
            padding: const EdgeInsets.all(16),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final l in list)
                FilledButton.tonal(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => GameScreen(level: l, ads: ads),
                  )),
                  child: Text('${l.id}'),
                ),
            ],
          );
        },
      ),
    );
  }
}
