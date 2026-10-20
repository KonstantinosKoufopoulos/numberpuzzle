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

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @debugWin.
  ///
  /// In en, this message translates to:
  /// **'Win (debug)'**
  String get debugWin;

  /// No description provided for @watchAdReward.
  ///
  /// In en, this message translates to:
  /// **'Watch ad for a booster'**
  String get watchAdReward;

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

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;
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
