import 'package:flutter/foundation.dart' show kReleaseMode;

/// AdMob ids. Debug, profile and tests use ONLY Google's official test ids;
/// the real ids are used exclusively in release builds.
/// The App ID is injected into AndroidManifest via `manifestPlaceholders`
/// per buildType in android/app/build.gradle.kts (keep both in sync).
/// No banner ads in this game.
class AdIds {
  const AdIds._(this.appId, this.interstitial, this.rewarded);

  final String appId;
  final String interstitial;
  final String rewarded;

  /// Google's public Android test ids.
  static const AdIds test = AdIds._(
    'ca-app-pub-3940256099942544~3347511713',
    'ca-app-pub-3940256099942544/1033173712',
    'ca-app-pub-3940256099942544/5224354917',
  );

  /// Production ids (release only).
  static const AdIds production = AdIds._(
    'ca-app-pub-1774874652706103~3439168584',
    'ca-app-pub-1774874652706103/1663052482',
    'ca-app-pub-1774874652706103/7060964803',
  );

  static AdIds forMode({required bool release}) => release ? production : test;

  static const AdIds current = kReleaseMode ? production : test;
}
