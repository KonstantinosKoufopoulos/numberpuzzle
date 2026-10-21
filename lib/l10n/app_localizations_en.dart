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
  String get debugWin => 'Win (debug)';

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
  String mapDailyStreak(int n) {
    return 'Daily · $n-day streak';
  }

  @override
  String get mapClassicContinue => 'Classic · Continue';

  @override
  String mapWorld(int total, int done) {
    return 'World 1 · $total levels · $done/$total';
  }

  @override
  String mapPlay(int n) {
    return 'Play $n';
  }

  @override
  String get startCta => 'Start';

  @override
  String get startNoTimer => 'Goals · no timer';

  @override
  String get startStars =>
      '3★ no boosters · 2★ one · 1★ two or more (Add numbers doesn\'t count)';

  @override
  String introNew(int n, String name) {
    return 'Level $n · New: $name';
  }

  @override
  String get introOk => 'Got it';

  @override
  String giftTitle(String booster, int count) {
    return 'Gift: $booster ×$count';
  }

  @override
  String get giftHammerBody =>
      'Clears a number or slime, or breaks all the ice. Doesn\'t work on stone.';

  @override
  String get giftSwapBody => 'Swaps any two numbers. Stars and grass stay put.';

  @override
  String get giftTakeHammer => 'Take the Hammer';

  @override
  String get giftTakeSwap => 'Take the Swap';

  @override
  String get boosterHammer => 'Hammer';

  @override
  String get boosterSwap => 'Swap';

  @override
  String get boosterHint => 'Hint';

  @override
  String get winTitle => 'Well done!';

  @override
  String get winStarsRule => '0 boosters → 3★ · 1 → 2★ · 2+ → 1★';

  @override
  String get winNext => 'Next level';

  @override
  String get winMap => 'Map';

  @override
  String get loseRetry => 'Play again';

  @override
  String get loseReward => 'Video: +1 Add numbers';

  @override
  String get debugLose => 'Lose (debug)';

  @override
  String debugBoosters(int n) {
    return 'Boosters used: $n';
  }

  @override
  String goalPairsSame(int count) {
    return 'Clear $count equal pairs';
  }

  @override
  String goalPairsTen(int count) {
    return 'Clear $count pairs summing to 10';
  }

  @override
  String goalNumber(int count, int value) {
    return 'Clear $count × $value';
  }

  @override
  String goalStar(int count) {
    return 'Collect $count ★';
  }

  @override
  String goalGrass(int count) {
    return 'Clear $count grass';
  }

  @override
  String goalIce(int count) {
    return 'Break $count ice';
  }

  @override
  String goalSlime(int count) {
    return 'Clear $count slime';
  }

  @override
  String goalOther(String name, int count) {
    return '$name × $count';
  }

  @override
  String goalChipNumber(int value, int done, int count) {
    return '$value × $done/$count';
  }

  @override
  String goalChipStar(int done, int count) {
    return '★ $done/$count';
  }

  @override
  String goalChipGrass(int done, int count) {
    return 'Grass $done/$count';
  }

  @override
  String goalChipIce(int done, int count) {
    return '❄ Ice $done/$count';
  }

  @override
  String goalChipSlime(int done, int count) {
    return 'Slime $done/$count';
  }

  @override
  String goalChipPairsSame(int done, int count) {
    return 'Equal pairs $done/$count';
  }

  @override
  String goalChipPairsTen(int done, int count) {
    return 'Pairs of 10 $done/$count';
  }

  @override
  String get addButton => '+ Add numbers (free)';

  @override
  String addLeft(int left, int limit) {
    return '$left/$limit left';
  }

  @override
  String addConfirm(int n) {
    return 'There are still $n pairs. Add numbers?';
  }

  @override
  String get addConfirmYes => 'Add numbers';

  @override
  String get addAlt => 'Find pairs (Hint)';

  @override
  String get notNow => 'Not now';

  @override
  String get hammerMode => 'Tap a number, slime or ice. Stone can\'t be hit.';

  @override
  String get swapMode => 'Pick two numbers to swap their digits.';

  @override
  String get cancel => 'Cancel';

  @override
  String get hintSearching => 'Looking for a pair…';

  @override
  String get hintAddNumbers => 'No pairs left: use Add numbers.';

  @override
  String get stuckTitle => 'No pairs left';

  @override
  String tutStep(int i) {
    return 'Step $i of 3';
  }

  @override
  String tutTen(int a, int b) {
    return 'Tap $a and $b: they add up to 10.';
  }

  @override
  String tutSame(int a, int b) {
    return 'Tap $a and $b: they are equal.';
  }

  @override
  String get tutLines =>
      'Pairs connect across, down or diagonally, over empty cells.';

  @override
  String get tutWrap => 'The end of a row connects to the start of the next.';

  @override
  String get tutSkip => 'Skip';

  @override
  String get loadingLevel => 'Preparing the level…';

  @override
  String get loadError => 'We couldn\'t prepare this level. Please try again.';

  @override
  String get retry => 'Retry';
}
