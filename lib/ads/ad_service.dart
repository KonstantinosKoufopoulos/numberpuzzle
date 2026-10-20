import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';
import 'ad_policy.dart';

/// Thin wrapper over google_mobile_ads. When [enabled] is false (tests,
/// `--dart-define=ADS=false`) the SDK is never touched.
class AdService {
  AdService({required this.enabled, AdPolicy? policy, this.ids = AdIds.current})
      : policy = policy ?? AdPolicy();

  /// Disabled instance for tests / widget tests.
  AdService.disabled() : this(enabled: false);

  /// Compile-time flag: `--dart-define=ADS=false` disables ads.
  static const bool kAdsFlag = bool.fromEnvironment('ADS', defaultValue: true);

  final bool enabled;
  final AdPolicy policy;
  final AdIds ids;

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  bool _canRequestAds = false;

  /// UMP consent at startup, then SDK init and preloading.
  Future<void> init() async {
    if (!enabled) return;
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((FormError? e) {
          if (e != null) debugPrint('UMP form error: ${e.message}');
        });
        if (!done.isCompleted) done.complete();
      },
      (FormError e) {
        debugPrint('UMP info error: ${e.message}');
        if (!done.isCompleted) done.complete();
      },
    );
    await done.future;
    _canRequestAds = await ConsentInformation.instance.canRequestAds();
    if (!_canRequestAds) return;
    await MobileAds.instance.initialize();
    _loadInterstitial();
    _loadRewarded();
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: ids.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: ids.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (_) => _rewarded = null,
      ),
    );
  }

  /// Call after the win screen is dismissed. Respects [AdPolicy].
  Future<void> maybeShowInterstitial({required int levelId, required bool isDaily}) async {
    if (!enabled || !_canRequestAds) return;
    if (!policy.canShowInterstitial(
        moment: AdMoment.winScreenDismissed, levelId: levelId, isDaily: isDaily)) {
      return;
    }
    final ad = _interstitial;
    if (ad == null) return;
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _loadInterstitial();
      },
    );
    policy.recordInterstitialShown(levelId);
    await ad.show();
  }

  /// Rewarded source for [RewardedController].
  RewardedAdSource get rewardedSource => _SdkRewardedSource(this);
}

class _SdkRewardedSource implements RewardedAdSource {
  _SdkRewardedSource(this.s);
  final AdService s;

  @override
  bool get isLoaded => s.enabled && s._rewarded != null;

  @override
  void show({required void Function() onUserEarnedReward, required void Function() onClosed}) {
    final ad = s._rewarded;
    if (ad == null) return;
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
