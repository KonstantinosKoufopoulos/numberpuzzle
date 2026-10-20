// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Number Puzzle';

  @override
  String get classic => 'Classic';

  @override
  String get daily => 'Daily';

  @override
  String level(int n) {
    return 'Level $n';
  }

  @override
  String get goals => 'Goals';

  @override
  String get addNumbers => 'Add numbers';

  @override
  String get undo => 'Undo';

  @override
  String get win => 'Level complete!';

  @override
  String get continueLabel => 'Continue';

  @override
  String get debugWin => 'Win (debug)';

  @override
  String get watchAdReward => 'Watch ad for a booster';

  @override
  String get noAdAvailable => 'No ad available right now';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get introStarsTitle => 'Stars';

  @override
  String get introStarsBody => 'Clear the number on a star to collect it.';

  @override
  String get introGrassTitle => 'Grass';

  @override
  String get introGrassBody => 'Clear numbers on grass to collect it.';

  @override
  String get introStoneTitle => 'Stone';

  @override
  String get introStoneBody =>
      'Stones never break and block lines like a number.';

  @override
  String get introIceTitle => 'Ice';

  @override
  String get introIceBody =>
      'Frozen numbers can\'t be selected. Clear a neighbour to crack the ice.';

  @override
  String get introSlimeTitle => 'Slime';

  @override
  String get introSlimeBody =>
      'Slime disappears when every cell around it is empty.';

  @override
  String get gotIt => 'Got it';
}
