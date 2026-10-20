import 'package:numberpuzzle/ads/ad_policy.dart';
import 'package:test/test.dart';

void main() {
  late DateTime now;
  late AdPolicy p;
  setUp(() {
    now = DateTime(2026, 1, 1);
    p = AdPolicy(clock: () => now);
  });

  bool can(int level, {AdMoment m = AdMoment.winScreenDismissed, bool daily = false}) =>
      p.canShowInterstitial(moment: m, levelId: level, isDaily: daily);

  test('none in levels 1-3', () {
    for (final l in [1, 2, 3]) {
      expect(can(l), isFalse);
    }
    expect(can(4), isTrue);
  });

  test('only after win screen dismissed', () {
    for (final m in AdMoment.values.where((m) => m != AdMoment.winScreenDismissed)) {
      expect(can(10, m: m), isFalse, reason: m.name);
    }
  });

  test('never in daily', () => expect(can(10, daily: true), isFalse));

  test('max one per 3 levels', () {
    p.recordInterstitialShown(4);
    now = now.add(const Duration(minutes: 30));
    expect(can(5), isFalse);
    expect(can(6), isFalse);
    expect(can(7), isTrue);
  });

  test('>= 180 s apart', () {
    p.recordInterstitialShown(4);
    now = now.add(const Duration(seconds: 179));
    expect(can(7), isFalse);
    now = now.add(const Duration(seconds: 1));
    expect(can(7), isTrue);
  });

  group('rewarded', () {
    test('no ad loaded -> no-ad text, no reward', () {
      final src = _FakeSource(loaded: false);
      final c = RewardedController(src);
      var granted = 0;
      expect(c.showNoAdText, isTrue);
      expect(c.onUserTap(grantReward: () => granted++), RewardedOutcome.noAdAvailable);
      expect(granted, 0);
    });
    test('reward only from onUserEarnedReward callback', () {
      final src = _FakeSource(loaded: true);
      final c = RewardedController(src);
      var granted = 0;
      expect(c.onUserTap(grantReward: () => granted++), RewardedOutcome.shown);
      expect(granted, 0, reason: 'showing alone grants nothing');
      src.closeWithoutReward();
      expect(granted, 0);
      c.onUserTap(grantReward: () => granted++);
      src.earn();
      expect(granted, 1);
    });
  });
}

class _FakeSource implements RewardedAdSource {
  _FakeSource({required bool loaded}) : isLoaded = loaded;
  @override
  bool isLoaded;
  void Function()? _earn, _closed;

  @override
  void show({required void Function() onUserEarnedReward, required void Function() onClosed}) {
    _earn = onUserEarnedReward;
    _closed = onClosed;
  }

  void earn() => _earn?.call();
  void closeWithoutReward() => _closed?.call();
}
