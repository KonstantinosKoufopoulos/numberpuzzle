/// Pure-Dart ad placement policy (no SDK, no Flutter imports).
///
/// Interstitials:
/// * never in levels 1–3;
/// * at most one per [AdPolicy.levelGap] COMPLETED levels (wins counted via
///   [AdPolicy.recordLevelCompleted]) AND at least [AdPolicy.minInterval]
///   since the last one;
/// * never in Daily;
/// * only at [AdMoment.winScreenDismissed] – never mid-level, never before
///   the win screen, never on "Add numbers" / undo.
/// State (completed-since-last, last-shown time) is persisted through an
/// injectable [AdPolicyStore]; the clock is injectable too.
/// Rewarded: only on explicit user tap, see [RewardedController].
library;

import 'dart:async';
import 'dart:convert';

/// Moments where the game asks whether an interstitial may show.
enum AdMoment { winScreenDismissed, midLevel, addNumbers, undo, levelStart, appStart }

/// Key/value persistence for [AdPolicy] (SharedPreferences in the app,
/// in-memory in tests).
abstract interface class AdPolicyStore {
  String? read();
  Future<void> write(String value);
}

class MemoryAdPolicyStore implements AdPolicyStore {
  MemoryAdPolicyStore([this.value]);
  String? value;
  @override
  String? read() => value;
  @override
  Future<void> write(String v) async => value = v;
}

class AdPolicy {
  AdPolicy({
    this.firstEligibleLevel = 4,
    this.levelGap = 3,
    this.minInterval = const Duration(minutes: 3),
    DateTime Function()? clock,
    AdPolicyStore? store,
  })  : _clock = clock ?? DateTime.now,
        _store = store ?? MemoryAdPolicyStore() {
    _load();
  }

  final int firstEligibleLevel;
  final int levelGap;
  final Duration minInterval;
  final DateTime Function() _clock;
  final AdPolicyStore _store;

  /// Non-daily levels completed since the last interstitial. Starts at
  /// [levelGap] so the first eligible win (L4+) may show one.
  late int _completedSinceLast;
  DateTime? _lastShownAt;

  int get completedSinceLast => _completedSinceLast;
  DateTime? get lastShownAt => _lastShownAt;

  void _load() {
    _completedSinceLast = levelGap;
    _lastShownAt = null;
    final raw = _store.read();
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final c = m['completed'];
      if (c is int && c >= 0) _completedSinceLast = c;
      final at = m['lastShownMs'];
      if (at is int) _lastShownAt = DateTime.fromMillisecondsSinceEpoch(at);
    } catch (_) {
      // Corrupt state: fall back to defaults.
    }
  }

  Future<void> _save() => _store.write(jsonEncode({
        'v': 1,
        'completed': _completedSinceLast,
        if (_lastShownAt != null) 'lastShownMs': _lastShownAt!.millisecondsSinceEpoch,
      }));

  /// Call once per WON level (before the win screen). Daily wins don't count.
  Future<void> recordLevelCompleted({bool isDaily = false}) async {
    if (isDaily) return;
    _completedSinceLast++;
    await _save();
  }

  /// May an interstitial be shown after [levelId] at [moment]?
  bool canShowInterstitial({
    required AdMoment moment,
    required int levelId,
    bool isDaily = false,
  }) {
    if (moment != AdMoment.winScreenDismissed) return false;
    if (isDaily) return false;
    if (levelId < firstEligibleLevel) return false;
    if (_completedSinceLast < levelGap) return false;
    final at = _lastShownAt;
    if (at != null) {
      final elapsed = _clock().difference(at);
      // A clock moved backwards counts as "not enough time passed".
      if (elapsed.isNegative || elapsed < minInterval) return false;
    }
    return true;
  }

  /// Record that an interstitial was actually shown.
  Future<void> recordInterstitialShown() async {
    _completedSinceLast = 0;
    _lastShownAt = _clock();
    await _save();
  }
}

/// Abstraction over a rewarded ad so the flow is testable without the SDK.
abstract interface class RewardedAdSource {
  bool get isLoaded;

  /// Shows the ad. [onUserEarnedReward] is called ONLY by the SDK's
  /// onUserEarnedReward callback; [onClosed] on dismiss or show failure.
  void show({required void Function() onUserEarnedReward, required void Function() onClosed});
}

enum RewardedOutcome { noAdAvailable, shown }

/// Grants a reward only from the SDK's onUserEarnedReward callback and
/// only after an explicit user tap.
class RewardedController {
  RewardedController(this.source, {this.closeGrace = const Duration(milliseconds: 600)});
  final RewardedAdSource source;

  /// On some devices onUserEarnedReward arrives just AFTER the dismiss
  /// callback; wait this long after close before resolving `false`.
  final Duration closeGrace;

  bool _busy = false;

  /// Whether the button should show the "no ad available now" text.
  bool get showNoAdText => !source.isLoaded;

  /// Call ONLY from a user tap handler.
  RewardedOutcome onUserTap({required void Function() grantReward, void Function()? onClosed}) {
    if (!source.isLoaded) return RewardedOutcome.noAdAvailable;
    source.show(onUserEarnedReward: grantReward, onClosed: onClosed ?? () {});
    return RewardedOutcome.shown;
  }

  /// Shows the ad; resolves `true` exactly once and ONLY if
  /// onUserEarnedReward fired. Close without reward, no ad, a second tap
  /// while one is in flight, or duplicate callbacks never grant twice.
  Future<bool> requestReward() {
    if (_busy || !source.isLoaded) return Future.value(false);
    _busy = true;
    final done = Completer<bool>();
    void finish(bool v) {
      if (done.isCompleted) return;
      _busy = false;
      done.complete(v);
    }

    onUserTap(
      grantReward: () => finish(true),
      onClosed: () {
        if (done.isCompleted) return;
        if (closeGrace == Duration.zero) {
          finish(false);
        } else {
          Timer(closeGrace, () => finish(false));
        }
      },
    );
    return done.future;
  }
}
