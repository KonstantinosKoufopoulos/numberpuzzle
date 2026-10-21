import 'package:flutter/foundation.dart' show kReleaseMode;

/// AdMob ids. Every build uses Google's official test ids EXCEPT a release
/// build with `--dart-define=ADS_REAL=true` (the Play upload). The real ids
/// are only reachable behind the compile-time [kAdsReal] constant, so builds
/// without it don't even contain them (tree-shaken).
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

  /// Production ids: release && ADS_REAL only. Keep private and reference
  /// them ONLY behind [kAdsReal] so other builds tree-shake them out.
  static const AdIds _production = AdIds._(
    'ca-app-pub-1774874652706103~3439168584',
    'ca-app-pub-1774874652706103/1663052482',
    'ca-app-pub-1774874652706103/7060964803',
  );

  /// `--dart-define=ADS_REAL=true`: opt in to the real ids (release only).
  static const bool kAdsReal = bool.fromEnvironment('ADS_REAL');

  /// Real ids only when [release] && [adsReal] AND the build was compiled
  /// with ADS_REAL=true; otherwise test ids.
  static AdIds forMode({required bool release, required bool adsReal}) =>
      kAdsReal && release && adsReal ? _production : test;

  static const AdIds current = kAdsReal && kReleaseMode ? _production : test;
}
