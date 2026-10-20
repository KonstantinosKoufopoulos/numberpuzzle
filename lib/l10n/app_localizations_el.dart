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

  @override
  String mapDailyStreak(int n) {
    return 'Ημερήσιο · Σερί $n ημέρες';
  }

  @override
  String get mapClassicContinue => 'Κλασικό · Συνέχεια';

  @override
  String mapWorld(int total, int done) {
    return 'Κόσμος 1 · $total επίπεδα · $done/$total';
  }

  @override
  String mapPlay(int n) {
    return 'Παίξε $n';
  }

  @override
  String get startCta => 'Ξεκίνα';

  @override
  String get startNoTimer => 'Στόχοι · χωρίς χρονόμετρο';

  @override
  String get startStars =>
      '3★ χωρίς εργαλεία · 2★ με ένα · 1★ με 2+ (η Προσθήκη δεν μετράει)';

  @override
  String introNew(int n, String name) {
    return 'Επίπεδο $n · Νέο: $name';
  }

  @override
  String get introOk => 'Κατάλαβα';

  @override
  String giftTitle(String booster, int count) {
    return 'Δώρο: $booster ×$count';
  }

  @override
  String get giftHammerBody =>
      'Σβήνει έναν αριθμό ή το slime, ή σπάει όλο τον πάγο. Δεν δουλεύει σε πέτρα.';

  @override
  String get giftSwapBody =>
      'Άλλαξε θέση σε δύο γειτονικούς αριθμούς για νέο ζευγάρι.';

  @override
  String get giftTakeHammer => 'Πάρε το Σφυρί';

  @override
  String get giftTakeSwap => 'Πάρε την Αλλαγή';

  @override
  String get boosterHammer => 'Σφυρί';

  @override
  String get boosterSwap => 'Αλλαγή';

  @override
  String get boosterHint => 'Βοήθεια';

  @override
  String get winTitle => 'Μπράβο!';

  @override
  String get winStarsRule => '0 εργαλεία → 3★ · 1 → 2★ · 2+ → 1★';

  @override
  String get winNext => 'Επόμενο επίπεδο';

  @override
  String get winMap => 'Χάρτης';

  @override
  String get loseTitle => 'Τέλος κινήσεων';

  @override
  String get loseBody =>
      'Δεν υπάρχουν ζευγάρια και οι Προσθήκες τελείωσαν. Δοκίμασε ξανά — η λογική σου μετράει, όχι η τύχη.';

  @override
  String get loseRetry => 'Ξαναπαίξε';

  @override
  String get loseReward => 'Βίντεο: +1 Προσθήκη αριθμών';

  @override
  String get debugLose => 'Ήττα (debug)';

  @override
  String debugBoosters(int n) {
    return 'Εργαλεία: $n';
  }

  @override
  String goalPairsSame(int count) {
    return 'Σβήσε $count ίδια ζευγάρια';
  }

  @override
  String goalPairsTen(int count) {
    return 'Σβήσε $count ζευγάρια με άθροισμα 10';
  }

  @override
  String goalNumber(int count, int value) {
    return 'Σβήσε $count × $value';
  }

  @override
  String goalStar(int count) {
    return 'Μάζεψε $count ★';
  }

  @override
  String goalGrass(int count) {
    return 'Καθάρισε $count γρασίδι';
  }

  @override
  String goalIce(int count) {
    return 'Σπάσε $count πάγους';
  }

  @override
  String goalSlime(int count) {
    return 'Καθάρισε $count γλίτσα';
  }

  @override
  String goalOther(String name, int count) {
    return '$name × $count';
  }
}
