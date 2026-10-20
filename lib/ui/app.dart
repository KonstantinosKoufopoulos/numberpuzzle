import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../ads/ad_service.dart';
import '../game/game_result.dart';
import '../l10n/app_localizations.dart';
import '../levels/level_repository.dart';
import '../storage/progress_store.dart';
import 'game_screen.dart';
import 'level_map_screen.dart';
import 'theme.dart';

/// Default game screen. m2-gameplay replaces this ONE line (docs/m2-seam.md).
const GameScreenBuilder kDefaultGameScreen = StubGameScreen.builder;

class NumberPuzzleApp extends StatefulWidget {
  const NumberPuzzleApp({super.key, required this.ads, this.levels, this.progress, this.gameBuilder});

  final AdService ads;
  final LevelRepository? levels;
  final ProgressController? progress;
  final GameScreenBuilder? gameBuilder;

  @override
  State<NumberPuzzleApp> createState() => _NumberPuzzleAppState();
}

class _NumberPuzzleAppState extends State<NumberPuzzleApp> {
  late final ProgressController _progress = widget.progress ?? ProgressController(ProgressStore());
  late final LevelRepository _levels = widget.levels ?? LevelRepository();

  @override
  Widget build(BuildContext context) => MaterialApp(
        onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
        theme: lightTheme,
        darkTheme: darkTheme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('el'), Locale('en')],
        home: LevelMapScreen(
          ads: widget.ads,
          levels: _levels,
          progress: _progress,
          gameBuilder: widget.gameBuilder ?? kDefaultGameScreen,
        ),
      );
}
