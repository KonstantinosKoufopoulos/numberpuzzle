import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../ads/ad_service.dart';
import '../l10n/app_localizations.dart';
import '../levels/level_repository.dart';
import 'home_screen.dart';
import 'theme.dart';

class NumberPuzzleApp extends StatelessWidget {
  const NumberPuzzleApp({super.key, required this.ads, this.levels});

  final AdService ads;
  final LevelRepository? levels;

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
        home: HomeScreen(ads: ads, levels: levels ?? LevelRepository()),
      );
}
