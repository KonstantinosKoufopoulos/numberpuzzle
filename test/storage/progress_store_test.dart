import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:numberpuzzle/storage/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('fresh progress: level 1 unlocked, nothing seen', () async {
    final p = await ProgressStore().load();
    expect(p.unlockedLevel, 1);
    expect(p.stars, isEmpty);
    expect(p.seenIntros, isEmpty);
  });

  test('recordWin keeps best stars and never downgrades', () {
    final p = Progress();
    p.recordWin(1, 2);
    expect(p.starsFor(1), 2);
    p.recordWin(1, 1);
    expect(p.starsFor(1), 2);
    p.recordWin(1, 3);
    expect(p.starsFor(1), 3);
    expect(p.unlockedLevel, 2);
  });

  test('replaying an earlier level does not lower unlockedLevel', () {
    final p = Progress()
      ..recordWin(1, 3)
      ..recordWin(2, 3)
      ..recordWin(3, 1);
    p.recordWin(1, 1);
    expect(p.unlockedLevel, 4);
  });

  test('round-trip: stars, unlocked, intros, boosters', () async {
    final store = ProgressStore();
    final p = Progress()
      ..recordWin(1, 3)
      ..recordWin(2, 1)
      ..seenIntros.add('intro:stars')
      ..addBooster('hammer', 2);
    await store.save(p);
    final q = await ProgressStore().load();
    expect(q.stars, {1: 3, 2: 1});
    expect(q.unlockedLevel, 3);
    expect(q.seenIntros, {'intro:stars'});
    expect(q.boosterCount('hammer'), 2);
    final raw = jsonDecode((await SharedPreferences.getInstance()).getString(ProgressStore.key)!);
    expect(raw['v'], Progress.schemaVersion);
  });

  test('migrates legacy v1 key (no unlocked field)', () async {
    SharedPreferences.setMockInitialValues({
      ProgressStore.legacyKeyV1: jsonEncode({
        'v': 1,
        'stars': {'1': 3, '2': 2},
        'seenIntros': ['stars'],
        'boosters': {'swap': 1},
      }),
    });
    final p = await ProgressStore().load();
    expect(p.stars, {1: 3, 2: 2});
    expect(p.unlockedLevel, 3);
    expect(p.boosterCount('swap'), 1);
    await ProgressStore().save(p);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ProgressStore.key), isNotNull);
  });

  test('corrupt or garbage data falls back safely', () async {
    SharedPreferences.setMockInitialValues({ProgressStore.key: '{not json'});
    expect((await ProgressStore().load()).unlockedLevel, 1);
    SharedPreferences.setMockInitialValues({
      ProgressStore.key: jsonEncode({
        'v': 99,
        'stars': {'x': 3, '4': 9, '5': 'a'},
        'boosters': {'hammer': -3},
        'future': 1,
      }),
    });
    final p = await ProgressStore().load();
    expect(p.stars, {4: 3});
    expect(p.boosterCount('hammer'), 0);
  });

  test('boosters never go negative', () {
    final p = Progress()
      ..addBooster('hint', 1)
      ..addBooster('hint', -5);
    expect(p.boosterCount('hint'), 0);
  });

  test('ProgressController persists and notifies', () async {
    final c = ProgressController(ProgressStore());
    await c.load();
    var n = 0;
    c.addListener(() => n++);
    await c.recordWin(5, 2);
    await c.markIntroSeen('intro:grass');
    await c.spendBoosters({'hammer': 1});
    expect(n, 3);
    final q = await ProgressStore().load();
    expect(q.starsFor(5), 2);
    expect(q.seenIntros, contains('intro:grass'));
  });
}
