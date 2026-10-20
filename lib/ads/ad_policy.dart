/// Pure-Dart ad placement policy (no SDK, no Flutter imports).
///
/// Interstitials:
/// * never in levels 1–3;
/// * at most one per [levelGap] completed levels AND at least
///   [minInterval] apart;
/// * never in Daily;
/// * only at [AdMoment.winScreenDismissed] – never mid-level, never on
///   "Add numbers", never on undo (both are free).
/// Rewarded: only on explicit user tap, see `RewardedController`.
library;

/// Moments where the game asks whether an interstitial may show.
enum AdMoment { winScreenDismissed, midLevel, addNumbers, undo, levelStart, appStart }

class AdPolicy {
  AdPolicy({
    this.firstEligibleLevel = 4,
    this.levelGap = 3,
    this.minInterval = const Duration(seconds: 180),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final int firstEligibleLevel;
  final int levelGap;
  final Duration minInterval;
  final DateTime Function() _clock;

  int? _lastShownLevel;
  DateTime? _lastShownAt;

  /// May an interstitial be shown after [levelId] at [moment]?
  bool canShowInterstitial({
    required AdMoment moment,
    required int levelId,
    bool isDaily = false,
  }) {
    if (moment != AdMoment.winScreenDismissed) return false;
    if (isDaily) return false;
    if (levelId < firstEligibleLevel) return false;
    final last = _lastShownLevel;
    if (last != null && (levelId - last).abs() < levelGap) return false;
    final at = _lastShownAt;
    if (at != null && _clock().difference(at) < minInterval) return false;
    return true;
  }

  /// Record that an interstitial was actually shown.
  void recordInterstitialShown(int levelId) {
    _lastShownLevel = levelId;
    _lastShownAt = _clock();
  }
}

/// Abstraction over a rewarded ad so the flow is testable without the SDK.
abstract interface class RewardedAdSource {
  bool get isLoaded;

  /// Shows the ad. [onUserEarnedReward] is called ONLY by the SDK callback.
  void show({required void Function() onUserEarnedReward, required void Function() onClosed});
}

enum RewardedOutcome { noAdAvailable, shown }

/// Grants a reward only from the SDK's onUserEarnedReward callback and
/// only after an explicit user tap.
class RewardedController {
  RewardedController(this.source);
  final RewardedAdSource source;

  /// Whether the button should show the "no ad available now" text.
  bool get showNoAdText => !source.isLoaded;

  /// Call ONLY from a user tap handler.
  RewardedOutcome onUserTap({required void Function() grantReward, void Function()? onClosed}) {
    if (!source.isLoaded) return RewardedOutcome.noAdAvailable;
    source.show(onUserEarnedReward: grantReward, onClosed: onClosed ?? () {});
    return RewardedOutcome.shown;
  }
}
