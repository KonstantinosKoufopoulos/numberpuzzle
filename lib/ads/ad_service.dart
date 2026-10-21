import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_ids.dart';
import 'ad_policy.dart';

/// [AdPolicyStore] over SharedPreferences (key [key]).
class PrefsAdPolicyStore implements AdPolicyStore {
  PrefsAdPolicyStore(this.prefs);
  static const key = 'ad_policy';
  final SharedPreferences prefs;
  @override
  String? read() => prefs.getString(key);
  @override
  Future<void> write(String value) => prefs.setString(key, value);
}

/// Thin wrapper over google_mobile_ads. When [enabled] is false (tests,
/// `--dart-define=ADS=false`) the SDK is never touched.
///
/// Consent gate: [init] runs the UMP flow first; NO ad request (and no
/// MobileAds.initialize) happens until `ConsentInformation.canRequestAds()`
/// is true. Every load path re-checks [canRequestAds].
class AdService {
  AdService({required this.enabled, AdPolicy? policy, this.ids = AdIds.current})
      : policy = policy ?? AdPolicy();

  /// Disabled instance for tests / widget tests.
  AdService.disabled() : this(enabled: false);

  /// Compile-time flag: `--dart-define=ADS=false` disables ads.
  static const bool kAdsFlag = bool.fromEnvironment('ADS', defaultValue: true);

  /// `--dart-define=UMP_DEBUG_EEA=true` forces EEA geography (non-release
  /// only; ignored in release builds).
  static const bool _kDebugEeaDefine = bool.fromEnvironment('UMP_DEBUG_EEA');

  /// Test device hashed ids for UMP debug geography (from logcat:
  /// "Use new ConsentDebugSettings.Builder().addTestDeviceHashedId(...)").
  static const String _kDebugDeviceIds = String.fromEnvironment('UMP_TEST_DEVICE_IDS');

  bool _debugGeographyEea = _kDebugEeaDefine;

  /// Debug EEA geography. Always false in release; the setter is a no-op
  /// there. Changing it takes effect on the next [init] /
  /// [resetConsentForDebug].
  bool get debugGeographyEea => !kReleaseMode && _debugGeographyEea;
  set debugGeographyEea(bool v) {
    if (kReleaseMode) return;
    _debugGeographyEea = v;
  }

  final bool enabled;
  final AdPolicy policy;
  final AdIds ids;

  /// Grace for onUserEarnedReward arriving after dismiss (0 when disabled
  /// so widget tests need no timers).
  Duration get rewardedCloseGrace => enabled ? const Duration(milliseconds: 600) : Duration.zero;

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  bool _canRequestAds = false;
  bool _sdkStarted = false;
  bool _interstitialLoading = false;
  bool _rewardedLoading = false;

  bool get canRequestAds => _canRequestAds;

  /// True when UMP says a privacy-options entry point must be shown
  /// (settings screen should show a "Privacy options" row when true).
  final ValueNotifier<bool> privacyOptionsRequired = ValueNotifier(false);

  ConsentRequestParameters _params() {
    if (!debugGeographyEea) return ConsentRequestParameters();
    final ids = _kDebugDeviceIds.isEmpty ? null : _kDebugDeviceIds.split(',');
    return ConsentRequestParameters(
      consentDebugSettings: ConsentDebugSettings(
        debugGeography: DebugGeography.debugGeographyEea,
        testIdentifiers: ids,
      ),
    );
  }

  /// UMP consent at startup, then SDK init and preloading.
  Future<void> init() async {
    if (!enabled) return;
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      _params(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((FormError? e) {
          if (e != null) debugPrint('UMP form error: ${e.message}');
          if (!done.isCompleted) done.complete();
        });
        // loadAndShow… resolves its listener; guard in case it doesn't.
        if (!done.isCompleted) done.complete();
      },
      (FormError e) {
        debugPrint('UMP info error: ${e.message}');
        // Fall through: consent from a previous session may still allow ads.
        if (!done.isCompleted) done.complete();
      },
    );
    await done.future;
    await _afterConsent();
  }

  Future<void> _afterConsent() async {
    _canRequestAds = await ConsentInformation.instance.canRequestAds();
    privacyOptionsRequired.value = await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
    if (!_canRequestAds) return;
    if (!_sdkStarted) {
      _sdkStarted = true;
      await MobileAds.instance.initialize();
    }
    _loadInterstitial();
    _loadRewarded();
  }

  /// Privacy-options entry point (settings screen row). Shows the UMP
  /// privacy options form, then re-evaluates [canRequestAds].
  Future<void> showPrivacyOptions() async {
    if (!enabled) return;
    final done = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((FormError? e) {
      if (e != null) debugPrint('UMP privacy form error: ${e.message}');
      if (!done.isCompleted) done.complete();
    });
    await done.future;
    await _afterConsent();
    if (!_canRequestAds) {
      _interstitial?.dispose();
      _interstitial = null;
      _rewarded?.dispose();
      _rewarded = null;
    }
  }

  /// Non-release only: wipe consent and re-run the flow (e.g. after toggling
  /// [debugGeographyEea]).
  Future<void> resetConsentForDebug() async {
    if (!enabled || kReleaseMode) return;
    await ConsentInformation.instance.reset();
    await init();
  }

  void _loadInterstitial() {
    if (!_canRequestAds || _interstitial != null || _interstitialLoading) return;
    _interstitialLoading = true;
    InterstitialAd.load(
      adUnitId: ids.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialLoading = false;
          _interstitial = ad;
        },
        onAdFailedToLoad: (_) {
          _interstitialLoading = false;
          _interstitial = null;
        },
      ),
    );
  }

  void _loadRewarded() {
    if (!_canRequestAds || _rewarded != null || _rewardedLoading) return;
    _rewardedLoading = true;
    RewardedAd.load(
      adUnitId: ids.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedLoading = false;
          _rewarded = ad;
        },
        onAdFailedToLoad: (_) {
          _rewardedLoading = false;
          _rewarded = null;
        },
      ),
    );
  }

  /// Call once per won level, before the win screen.
  Future<void> recordLevelCompleted({required bool isDaily}) =>
      policy.recordLevelCompleted(isDaily: isDaily);

  /// Call ONLY after the win screen's Next. Respects [AdPolicy]; silently
  /// does nothing if no ad is loaded (and kicks a load for next time).
  Future<void> maybeShowInterstitial({required int levelId, required bool isDaily}) async {
    if (!enabled || !_canRequestAds) return;
    if (!policy.canShowInterstitial(
        moment: AdMoment.winScreenDismissed, levelId: levelId, isDaily: isDaily)) {
      return;
    }
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => unawaited(policy.recordInterstitialShown()),
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadInterstitial(); // preload the next one
        if (!closed.isCompleted) closed.complete();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _loadInterstitial();
        if (!closed.isCompleted) closed.complete();
      },
    );
    try {
      await ad.show();
      await closed.future;
    } catch (e) {
      debugPrint('interstitial show failed: $e');
    }
  }

  /// Rewarded source for [RewardedController].
  RewardedAdSource get rewardedSource => _SdkRewardedSource(this);
}

class _SdkRewardedSource implements RewardedAdSource {
  _SdkRewardedSource(this.s);
  final AdService s;

  @override
  bool get isLoaded => s.enabled && s._canRequestAds && s._rewarded != null;

  @override
  void show({required void Function() onUserEarnedReward, required void Function() onClosed}) {
    final ad = s._rewarded;
    if (ad == null) {
      onClosed();
      return;
    }
    s._rewarded = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        onClosed();
        s._loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        onClosed();
        s._loadRewarded();
      },
    );
    ad.show(onUserEarnedReward: (_, _) => onUserEarnedReward());
  }
}
