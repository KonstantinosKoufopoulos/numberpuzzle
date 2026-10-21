import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_el.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('el'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Number Puzzle'**
  String get appTitle;

  /// No description provided for @classic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get classic;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @level.
  ///
  /// In en, this message translates to:
  /// **'Level {n}'**
  String level(int n);

  /// No description provided for @goals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get goals;

  /// No description provided for @addNumbers.
  ///
  /// In en, this message translates to:
  /// **'Add numbers'**
  String get addNumbers;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @win.
  ///
  /// In en, this message translates to:
  /// **'Level complete!'**
  String get win;

  /// No description provided for @debugWin.
  ///
  /// In en, this message translates to:
  /// **'Win (debug)'**
  String get debugWin;

  /// No description provided for @noAdAvailable.
  ///
  /// In en, this message translates to:
  /// **'No ad available right now'**
  String get noAdAvailable;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @introStarsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stars'**
  String get introStarsTitle;

  /// No description provided for @introStarsBody.
  ///
  /// In en, this message translates to:
  /// **'Clear the number on a star to collect it.'**
  String get introStarsBody;

  /// No description provided for @introGrassTitle.
  ///
  /// In en, this message translates to:
  /// **'Grass'**
  String get introGrassTitle;

  /// No description provided for @introGrassBody.
  ///
  /// In en, this message translates to:
  /// **'Clear numbers on grass to collect it.'**
  String get introGrassBody;

  /// No description provided for @introStoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Stone'**
  String get introStoneTitle;

  /// No description provided for @introStoneBody.
  ///
  /// In en, this message translates to:
  /// **'Stones never break and block lines like a number.'**
  String get introStoneBody;

  /// No description provided for @introIceTitle.
  ///
  /// In en, this message translates to:
  /// **'Ice'**
  String get introIceTitle;

  /// No description provided for @introIceBody.
  ///
  /// In en, this message translates to:
  /// **'Frozen numbers can\'t be selected. Clear a neighbour to crack the ice.'**
  String get introIceBody;

  /// No description provided for @introSlimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Slime'**
  String get introSlimeTitle;

  /// No description provided for @introSlimeBody.
  ///
  /// In en, this message translates to:
  /// **'Slime disappears when every cell around it is empty.'**
  String get introSlimeBody;

  /// No description provided for @mapDailyStreak.
  ///
  /// In en, this message translates to:
  /// **'Daily · {n}-day streak'**
  String mapDailyStreak(int n);

  /// No description provided for @mapClassicContinue.
  ///
  /// In en, this message translates to:
  /// **'Classic · Continue'**
  String get mapClassicContinue;

  /// No description provided for @mapWorld.
  ///
  /// In en, this message translates to:
  /// **'World 1 · {total} levels · {done}/{total}'**
  String mapWorld(int total, int done);

  /// No description provided for @mapPlay.
  ///
  /// In en, this message translates to:
  /// **'Play {n}'**
  String mapPlay(int n);

  /// No description provided for @startCta.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startCta;

  /// No description provided for @startNoTimer.
  ///
  /// In en, this message translates to:
  /// **'Goals · no timer'**
  String get startNoTimer;

  /// No description provided for @startStars.
  ///
  /// In en, this message translates to:
  /// **'3★ no boosters · 2★ one · 1★ two or more (Add numbers doesn\'t count)'**
  String get startStars;

  /// No description provided for @introNew.
  ///
  /// In en, this message translates to:
  /// **'Level {n} · New: {name}'**
  String introNew(int n, String name);

  /// No description provided for @introOk.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get introOk;

  /// No description provided for @giftTitle.
  ///
  /// In en, this message translates to:
  /// **'Gift: {booster} ×{count}'**
  String giftTitle(String booster, int count);

  /// No description provided for @giftHammerBody.
  ///
  /// In en, this message translates to:
  /// **'Clears a number or slime, or breaks all the ice. Doesn\'t work on stone.'**
  String get giftHammerBody;

  /// No description provided for @giftSwapBody.
  ///
  /// In en, this message translates to:
  /// **'Swaps any two numbers. Stars and grass stay put.'**
  String get giftSwapBody;

  /// No description provided for @giftTakeHammer.
  ///
  /// In en, this message translates to:
  /// **'Take the Hammer'**
  String get giftTakeHammer;

  /// No description provided for @giftTakeSwap.
  ///
  /// In en, this message translates to:
  /// **'Take the Swap'**
  String get giftTakeSwap;

  /// No description provided for @boosterHammer.
  ///
  /// In en, this message translates to:
  /// **'Hammer'**
  String get boosterHammer;

  /// No description provided for @boosterSwap.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get boosterSwap;

  /// No description provided for @boosterHint.
  ///
  /// In en, this message translates to:
  /// **'Hint'**
  String get boosterHint;

  /// No description provided for @winTitle.
  ///
  /// In en, this message translates to:
  /// **'Well done!'**
  String get winTitle;

  /// No description provided for @winStarsRule.
  ///
  /// In en, this message translates to:
  /// **'0 boosters → 3★ · 1 → 2★ · 2+ → 1★'**
  String get winStarsRule;

  /// No description provided for @winNext.
  ///
  /// In en, this message translates to:
  /// **'Next level'**
  String get winNext;

  /// No description provided for @winMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get winMap;

  /// No description provided for @loseRetry.
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get loseRetry;

  /// No description provided for @loseReward.
  ///
  /// In en, this message translates to:
  /// **'Video: +1 Add numbers'**
  String get loseReward;

  /// No description provided for @debugLose.
  ///
  /// In en, this message translates to:
  /// **'Lose (debug)'**
  String get debugLose;

  /// No description provided for @debugBoosters.
  ///
  /// In en, this message translates to:
  /// **'Boosters used: {n}'**
  String debugBoosters(int n);

  /// No description provided for @goalPairsSame.
  ///
  /// In en, this message translates to:
  /// **'Clear {count} equal pairs'**
  String goalPairsSame(int count);

  /// No description provided for @goalPairsTen.
  ///
  /// In en, this message translates to:
  /// **'Clear {count} pairs summing to 10'**
  String goalPairsTen(int count);

  /// No description provided for @goalNumber.
  ///
  /// In en, this message translates to:
  /// **'Clear {count} × {value}'**
  String goalNumber(int count, int value);

  /// No description provided for @goalStar.
  ///
  /// In en, this message translates to:
  /// **'Collect {count} ★'**
  String goalStar(int count);

  /// No description provided for @goalGrass.
  ///
  /// In en, this message translates to:
  /// **'Clear {count} grass'**
  String goalGrass(int count);

  /// No description provided for @goalIce.
  ///
  /// In en, this message translates to:
  /// **'Break {count} ice'**
  String goalIce(int count);

  /// No description provided for @goalSlime.
  ///
  /// In en, this message translates to:
  /// **'Clear {count} slime'**
  String goalSlime(int count);

  /// No description provided for @goalOther.
  ///
  /// In en, this message translates to:
  /// **'{name} × {count}'**
  String goalOther(String name, int count);

  /// No description provided for @goalChipNumber.
  ///
  /// In en, this message translates to:
  /// **'{value} × {done}/{count}'**
  String goalChipNumber(int value, int done, int count);

  /// No description provided for @goalChipStar.
  ///
  /// In en, this message translates to:
  /// **'★ {done}/{count}'**
  String goalChipStar(int done, int count);

  /// No description provided for @goalChipGrass.
  ///
  /// In en, this message translates to:
  /// **'Grass {done}/{count}'**
  String goalChipGrass(int done, int count);

  /// No description provided for @goalChipIce.
  ///
  /// In en, this message translates to:
  /// **'❄ Ice {done}/{count}'**
  String goalChipIce(int done, int count);

  /// No description provided for @goalChipSlime.
  ///
  /// In en, this message translates to:
  /// **'Slime {done}/{count}'**
  String goalChipSlime(int done, int count);

  /// No description provided for @goalChipPairsSame.
  ///
  /// In en, this message translates to:
  /// **'Equal pairs {done}/{count}'**
  String goalChipPairsSame(int done, int count);

  /// No description provided for @goalChipPairsTen.
  ///
  /// In en, this message translates to:
  /// **'Pairs of 10 {done}/{count}'**
  String goalChipPairsTen(int done, int count);

  /// No description provided for @addButton.
  ///
  /// In en, this message translates to:
  /// **'+ Add numbers (free)'**
  String get addButton;

  /// No description provided for @addLeft.
  ///
  /// In en, this message translates to:
  /// **'{left}/{limit} left'**
  String addLeft(int left, int limit);

  /// No description provided for @addConfirm.
  ///
  /// In en, this message translates to:
  /// **'There are still {n} pairs. Add numbers?'**
  String addConfirm(int n);

  /// No description provided for @addConfirmYes.
  ///
  /// In en, this message translates to:
  /// **'Add numbers'**
  String get addConfirmYes;

  /// No description provided for @addAlt.
  ///
  /// In en, this message translates to:
  /// **'Find pairs (Hint)'**
  String get addAlt;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @hammerMode.
  ///
  /// In en, this message translates to:
  /// **'Tap a number, slime or ice. Stone can\'t be hit.'**
  String get hammerMode;

  /// No description provided for @swapMode.
  ///
  /// In en, this message translates to:
  /// **'Pick two numbers to swap their digits.'**
  String get swapMode;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @hintSearching.
  ///
  /// In en, this message translates to:
  /// **'Looking for a pair…'**
  String get hintSearching;

  /// No description provided for @hintAddNumbers.
  ///
  /// In en, this message translates to:
  /// **'No pairs left: use Add numbers.'**
  String get hintAddNumbers;

  /// No description provided for @stuckTitle.
  ///
  /// In en, this message translates to:
  /// **'No pairs left'**
  String get stuckTitle;

  /// No description provided for @tutStep.
  ///
  /// In en, this message translates to:
  /// **'Step {i} of 3'**
  String tutStep(int i);

  /// No description provided for @tutTen.
  ///
  /// In en, this message translates to:
  /// **'Tap {a} and {b}: they add up to 10.'**
  String tutTen(int a, int b);

  /// No description provided for @tutSame.
  ///
  /// In en, this message translates to:
  /// **'Tap {a} and {b}: they are equal.'**
  String tutSame(int a, int b);

  /// No description provided for @tutLines.
  ///
  /// In en, this message translates to:
  /// **'Pairs connect across, down or diagonally, over empty cells.'**
  String get tutLines;

  /// No description provided for @tutWrap.
  ///
  /// In en, this message translates to:
  /// **'The end of a row connects to the start of the next.'**
  String get tutWrap;

  /// No description provided for @tutSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get tutSkip;

  /// No description provided for @loadingLevel.
  ///
  /// In en, this message translates to:
  /// **'Preparing the level…'**
  String get loadingLevel;

  /// No description provided for @loadError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t prepare this level. Please try again.'**
  String get loadError;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['el', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'el':
      return AppLocalizationsEl();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
