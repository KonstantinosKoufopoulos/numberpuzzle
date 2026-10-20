// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Modern Greek (`el`).
class AppLocalizationsEl extends AppLocalizations {
  AppLocalizationsEl([String locale = 'el']) : super(locale);

  @override
  String get appTitle => 'Number Puzzle';

  @override
  String get classic => 'Κλασικό';

  @override
  String get daily => 'Ημερήσιο';

  @override
  String level(int n) {
    return 'Επίπεδο $n';
  }

  @override
  String get goals => 'Στόχοι';

  @override
  String get addNumbers => 'Πρόσθεσε αριθμούς';

  @override
  String get undo => 'Αναίρεση';

  @override
  String get win => 'Ολοκληρώθηκε!';

  @override
  String get continueLabel => 'Συνέχεια';

  @override
  String get debugWin => 'Νίκη (debug)';

  @override
  String get watchAdReward => 'Δες διαφήμιση για βοήθεια';

  @override
  String get noAdAvailable => 'Δεν υπάρχει διαθέσιμη διαφήμιση τώρα';

  @override
  String get comingSoon => 'Έρχεται σύντομα';

  @override
  String get introStarsTitle => 'Αστέρια';

  @override
  String get introStarsBody =>
      'Καθάρισε τον αριθμό πάνω σε αστέρι για να το μαζέψεις.';

  @override
  String get introGrassTitle => 'Γρασίδι';

  @override
  String get introGrassBody =>
      'Καθάρισε αριθμούς πάνω σε γρασίδι για να το μαζέψεις.';

  @override
  String get introStoneTitle => 'Πέτρα';

  @override
  String get introStoneBody =>
      'Οι πέτρες δεν σπάνε και εμποδίζουν τις γραμμές όπως ένας αριθμός.';

  @override
  String get introIceTitle => 'Πάγος';

  @override
  String get introIceBody =>
      'Οι παγωμένοι αριθμοί δεν επιλέγονται. Καθάρισε γειτονικό κελί για να σπάσει ο πάγος.';

  @override
  String get introSlimeTitle => 'Γλίτσα';

  @override
  String get introSlimeBody =>
      'Η γλίτσα εξαφανίζεται όταν όλα τα γύρω κελιά είναι άδεια.';

  @override
  String get gotIt => 'Εντάξει';
}
