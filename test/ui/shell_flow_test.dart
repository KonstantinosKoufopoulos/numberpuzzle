import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numberpuzzle/ui/game_screen.dart';
import 'package:numberpuzzle/ads/ad_policy.dart';
import 'package:numberpuzzle/ads/ad_service.dart';
import 'package:numberpuzzle/engine/level.dart';
import 'package:numberpuzzle/game/game_result.dart';
import 'package:numberpuzzle/levels/level_repository.dart';
import 'package:numberpuzzle/storage/progress_store.dart';
import 'package:numberpuzzle/ui/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeRewarded implements RewardedAdSource {
  FakeRewarded({this.loaded = true, this.earn = true});
  bool loaded;
  bool earn;
  @override
  bool get isLoaded => loaded;
  @override
  void show({required void Function() onUserEarnedReward, required void Function() onClosed}) {
    if (earn) onUserEarnedReward();
    onClosed();
  }
}

/// Reads the real bundled pack from disk; avoids rootBundle caching across tests.
class FileLevels extends LevelRepository {
  static final LevelPack pack = LevelPack.fromJson(
      jsonDecode(File(LevelRepository.assetPath).readAsStringSync()) as Map<String, dynamic>);
  @override
  Future<LevelPack> load() => SynchronousFuture(pack);
}

class FakeAds extends AdService {
  FakeAds({this.rewarded}) : super(enabled: false);
  final RewardedAdSource? rewarded;
  final calls = <int>[];
  @override
  Future<void> maybeShowInterstitial({required int levelId, required bool isDaily}) async => calls.add(levelId);
  @override
  RewardedAdSource get rewardedSource => rewarded ?? super.rewardedSource;
}

Future<ProgressController> pumpApp(WidgetTester tester, AdService ads,
    {Map<String, Object> prefs = const {}, String locale = 'en'}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.localesTestValue = [Locale(locale)];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  SharedPreferences.setMockInitialValues(prefs);
  final pc = ProgressController(ProgressStore());
  await tester.runAsync(pc.load);
  await tester.pumpWidget(NumberPuzzleApp(ads: ads, progress: pc, levels: FileLevels(), gameBuilder: StubGameScreen.builder));
  await settleMap(tester);
  return pc;
}

Future<void> settleMap(WidgetTester tester) async {
  for (var i = 0; i < 100 && find.byKey(const Key('playCurrent')).evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

bool locked(WidgetTester t, int id) => find.byKey(Key('lock-$id')).evaluate().isNotEmpty;

Future<void> startLevel(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('playCurrent')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('startButton')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('map: fresh install → L1 current, rest locked; Greek strings', (tester) async {
    await pumpApp(tester, FakeAds(), locale: 'el');
    expect(find.text('Παίξε 1'), findsOneWidget);
    expect(find.text('Ημερήσιο'), findsOneWidget);
    expect(find.text('Κλασικό'), findsOneWidget);
    expect(locked(tester, 1), isFalse);
    expect(locked(tester, 2), isTrue);
  });

  testWidgets('map: shows best stars, unlock up to current, scrolls to current', (tester) async {
    await pumpApp(tester, FakeAds(), prefs: {
      ProgressStore.key: '{"v":2,"stars":{"1":3,"2":2,"3":1},"unlocked":4,"seenIntros":[],"boosters":{}}',
    });
    expect(find.text('Play 4'), findsOneWidget);
    expect(find.text('★★★'), findsOneWidget);
    expect(find.text('★★☆'), findsOneWidget);
    expect(find.text('★☆☆'), findsOneWidget);
    expect(locked(tester, 3), isFalse);
    expect(locked(tester, 5), isTrue);
  });

  testWidgets('map: deep progress auto-scrolls so current node 25 is on screen', (tester) async {
    await pumpApp(tester, FakeAds(), prefs: {
      ProgressStore.key: '{"v":2,"stars":{},"unlocked":25,"seenIntros":[],"boosters":{}}',
    });
    expect(find.text('25'), findsOneWidget);
    expect(tester.getCenter(find.text('25')).dy, lessThan(2340 / 3));
  });

  testWidgets('win flow via stub: 1 booster → 2★, unlocks next, Map returns w/o ad', (tester) async {
    final ads = FakeAds();
    final pc = await pumpApp(tester, ads);
    await startLevel(tester);
    await tester.tap(find.byKey(const Key('debugBoosterPlus')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('debugWin')));
    await tester.pumpAndSettle();
    expect(find.text('Well done!'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
    expect(ads.calls, isEmpty, reason: 'no ad on the win screen');
    await tester.tap(find.byKey(const Key('winMap')));
    await tester.pumpAndSettle();
    expect(ads.calls, isEmpty, reason: 'no ad when leaving via Map');
    expect(pc.progress.starsFor(1), 2);
    expect(find.text('Play 2'), findsOneWidget);
    expect(find.text('★★☆'), findsOneWidget);
  });

  testWidgets('win → Next calls interstitial hook and opens next level start', (tester) async {
    final ads = FakeAds();
    await pumpApp(tester, ads);
    await startLevel(tester);
    await tester.tap(find.byKey(const Key('debugWin')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    await tester.tap(find.byKey(const Key('winNext')));
    await tester.pumpAndSettle();
    expect(ads.calls, [1]);
    expect(find.byKey(const Key('levelStartSheet')), findsOneWidget);
    expect(find.text('Level 2'), findsWidgets);
  });

  testWidgets('lose → retry restarts; map returns', (tester) async {
    final pc = await pumpApp(tester, FakeAds(rewarded: FakeRewarded(loaded: false)), locale: 'el');
    await startLevel(tester);
    await tester.tap(find.byKey(const Key('debugLose')));
    await tester.pumpAndSettle();
    expect(find.text('Τέλος κινήσεων'), findsOneWidget);
    await tester.tap(find.byKey(const Key('loseRetry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('debugWin')), findsOneWidget);
    await tester.tap(find.byKey(const Key('debugLose')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('loseMap')));
    await tester.pumpAndSettle();
    expect(find.text('Παίξε 1'), findsOneWidget);
    expect(pc.progress.stars, isEmpty);
  });

  testWidgets('shell lose screen has no rewarded button (continue lives in the game overlay)', (tester) async {
    await pumpApp(tester, FakeAds(rewarded: FakeRewarded()));
    await startLevel(tester);
    await tester.tap(find.byKey(const Key('debugLose')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('loseRetry')), findsOneWidget);
    expect(find.byKey(const Key('loseReward')), findsNothing);
  });

  testWidgets('onRequestRewarded resolves true only when the reward callback fires', (tester) async {
    final src = FakeRewarded(earn: false);
    GameArgs? args;
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = [const Locale('en')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    SharedPreferences.setMockInitialValues({});
    final pc = ProgressController(ProgressStore());
    await tester.runAsync(pc.load);
    await tester.pumpWidget(NumberPuzzleApp(
      ads: FakeAds(rewarded: src),
      progress: pc,
      levels: FileLevels(),
      gameBuilder: (c, a) {
        args = a;
        return StubGameScreen.builder(c, a);
      },
    ));
    await settleMap(tester);
    await startLevel(tester);
    expect(args!.onRequestRewarded, isNotNull);
    expect(await args!.onRequestRewarded!(), isFalse, reason: 'closed without reward');
    src.earn = true;
    expect(await args!.onRequestRewarded!(), isTrue);
    src.loaded = false;
    expect(await args!.onRequestRewarded!(), isFalse, reason: 'no ad loaded');
  });

  testWidgets('intro card shows only the first time (persisted)', (tester) async {
    final pc = await pumpApp(tester, FakeAds(), prefs: {
      ProgressStore.key: '{"v":2,"stars":{},"unlocked":7,"seenIntros":[],"boosters":{}}',
    });
    await startLevel(tester);
    expect(find.byKey(const Key('introCard')), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(pc.progress.seenIntros, contains('intro:stars'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await startLevel(tester);
    expect(find.byKey(const Key('introCard')), findsNothing);
    expect(find.byKey(const Key('debugWin')), findsOneWidget);
  });

  testWidgets('gift level grants boosters once', (tester) async {
    final pc = await pumpApp(tester, FakeAds(), prefs: {
      ProgressStore.key: '{"v":2,"stars":{},"unlocked":10,"seenIntros":[],"boosters":{}}',
    });
    await startLevel(tester);
    expect(find.byKey(const Key('giftCard')), findsOneWidget);
    await tester.tap(find.text('Take the Hammer'));
    await tester.pumpAndSettle();
    expect(pc.progress.boosterCount('hammer'), 2);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await startLevel(tester);
    expect(find.byKey(const Key('giftCard')), findsNothing);
    expect(pc.progress.boosterCount('hammer'), 2);
  });
}
