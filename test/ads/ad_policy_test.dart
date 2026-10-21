import 'dart:convert';

import 'package:numberpuzzle/ads/ad_policy.dart';
import 'package:test/test.dart';

void main() {
  late DateTime now;
  late MemoryAdPolicyStore store;
  late AdPolicy p;
  AdPolicy make() => AdPolicy(clock: () => now, store: store);
  setUp(() {
    now = DateTime(2026, 1, 1, 12);
    store = MemoryAdPolicyStore();
    p = make();
  });

  bool can(int level, {AdMoment m = AdMoment.winScreenDismissed, bool daily = false}) =>
      p.canShowInterstitial(moment: m, levelId: level, isDaily: daily);

  Future<void> win([int n = 1]) async {
    for (var i = 0; i < n; i++) {
      await p.recordLevelCompleted();
    }
  }

  test('never in levels 1-3, first eligible at L4', () async {
    for (final l in [1, 2, 3]) {
      await win();
      expect(can(l), isFalse, reason: 'L$l');
    }
    await win();
    expect(can(4), isTrue);
  });

  test('only after win screen dismissed (never mid-level / before win)', () {
    for (final m in AdMoment.values.where((m) => m != AdMoment.winScreenDismissed)) {
      expect(can(10, m: m), isFalse, reason: m.name);
    }
    expect(can(10), isTrue);
  });

  test('never in daily, and daily wins do not count', () async {
    expect(can(10, daily: true), isFalse);
    await p.recordInterstitialShown();
    now = now.add(const Duration(hours: 1));
    for (var i = 0; i < 5; i++) {
      await p.recordLevelCompleted(isDaily: true);
    }
    expect(p.completedSinceLast, 0);
    expect(can(10), isFalse);
  });

  test('max one per 3 completed levels', () async {
    await p.recordInterstitialShown();
    now = now.add(const Duration(hours: 1));
    await win();
    expect(can(5), isFalse);
    await win();
    expect(can(6), isFalse);
    await win();
    expect(can(7), isTrue);
  });

  test('replays of the same level count as completed levels', () async {
    await p.recordInterstitialShown();
    now = now.add(const Duration(hours: 1));
    await win(3);
    expect(can(5), isTrue);
  });

  test('>= 3 minutes apart (injectable clock), both rules required', () async {
    await p.recordInterstitialShown();
    await win(3);
    now = now.add(const Duration(minutes: 2, seconds: 59));
    expect(can(7), isFalse);
    now = now.add(const Duration(seconds: 1));
    expect(can(7), isTrue);
    // Time alone is not enough.
    await p.recordInterstitialShown();
    now = now.add(const Duration(hours: 5));
    await win(2);
    expect(can(9), isFalse);
  });

  test('clock moved backwards does not allow an ad', () async {
    await p.recordInterstitialShown();
    await win(3);
    now = now.subtract(const Duration(hours: 1));
    expect(can(10), isFalse);
  });

  test('state persists across instances (restart)', () async {
    await p.recordInterstitialShown();
    await win(2);
    final json = jsonDecode(store.value!) as Map<String, dynamic>;
    expect(json['completed'], 2);
    expect(json['lastShownMs'], now.millisecondsSinceEpoch);

    now = now.add(const Duration(minutes: 1));
    p = make(); // "app restart"
    expect(p.completedSinceLast, 2);
    expect(p.lastShownAt, DateTime(2026, 1, 1, 12));
    await win();
    expect(can(10), isFalse, reason: 'only 1 min since last');
    now = now.add(const Duration(minutes: 2));
    expect(can(10), isTrue);
  });

  test('corrupt or missing state falls back to defaults', () {
    store.value = 'not json';
    p = make();
    expect(p.completedSinceLast, 3);
    expect(p.lastShownAt, isNull);
    expect(can(4), isTrue);
  });

  group('rewarded', () {
    test('no ad loaded -> no-ad text, no reward', () async {
      final src = _FakeSource(loaded: false);
      final c = RewardedController(src, closeGrace: Duration.zero);
      expect(c.showNoAdText, isTrue);
      var granted = 0;
      expect(c.onUserTap(grantReward: () => granted++), RewardedOutcome.noAdAvailable);
      expect(granted, 0);
      expect(await c.requestReward(), isFalse);
    });

    test('close without reward resolves false', () async {
      final src = _FakeSource(loaded: true);
      final c = RewardedController(src, closeGrace: Duration.zero);
      final f = c.requestReward();
      src.close();
      expect(await f, isFalse);
    });

    test('resolves true only on onUserEarnedReward, exactly once', () async {
      final src = _FakeSource(loaded: true);
      final c = RewardedController(src, closeGrace: Duration.zero);
      var results = <bool>[];
      final f = c.requestReward()..then(results.add);
      src.earn();
      src.earn(); // duplicate SDK callback
      src.close();
      expect(await f, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(results, [true]);
    });

    test('reward arriving shortly after dismiss still counts (grace)', () async {
      final src = _FakeSource(loaded: true);
      final c = RewardedController(src, closeGrace: const Duration(milliseconds: 50));
      final f = c.requestReward();
      src.close();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      src.earn();
      expect(await f, isTrue);
    });

    test('reward after the grace window is ignored', () async {
      final src = _FakeSource(loaded: true);
      final c = RewardedController(src, closeGrace: const Duration(milliseconds: 10));
      final f = c.requestReward();
      src.close();
      expect(await f, isFalse);
      src.earn();
    });

    test('second tap while one is in flight grants nothing', () async {
      final src = _FakeSource(loaded: true);
      final c = RewardedController(src, closeGrace: Duration.zero);
      final f1 = c.requestReward();
      expect(await c.requestReward(), isFalse);
      expect(src.shows, 1);
      src.earn();
      expect(await f1, isTrue);
      // Next request works again.
      final f2 = c.requestReward();
      src.close();
      expect(await f2, isFalse);
      expect(src.shows, 2);
    });
  });
}

class _FakeSource implements RewardedAdSource {
  _FakeSource({required bool loaded}) : isLoaded = loaded;
  @override
  bool isLoaded;
  int shows = 0;
  void Function()? _earn, _closed;

  @override
  void show({required void Function() onUserEarnedReward, required void Function() onClosed}) {
    shows++;
    _earn = onUserEarnedReward;
    _closed = onClosed;
  }

  void earn() => _earn?.call();
  void close() => _closed?.call();
}
