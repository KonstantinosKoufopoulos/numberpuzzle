import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numberpuzzle/ads/ad_service.dart';
import 'package:numberpuzzle/engine/level.dart';
import 'package:numberpuzzle/levels/level_repository.dart';
import 'package:numberpuzzle/settings/settings_controller.dart';
import 'package:numberpuzzle/storage/game_save_store.dart';
import 'package:numberpuzzle/storage/progress_store.dart';
import 'package:numberpuzzle/ui/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Levels extends LevelRepository {
  @override
  Future<LevelPack> load() async =>
      LevelPack.fromJson(jsonDecode(File('assets/levels/levels.json').readAsStringSync()) as Map<String, dynamic>);
}

Future<SettingsController> _pump(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.localesTestValue = const [Locale('en')];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  SharedPreferences.setMockInitialValues(prefs);
  final pc = ProgressController(ProgressStore());
  final sc = SettingsController();
  await tester.runAsync(() async {
    await pc.load();
    await sc.load();
  });
  await tester.pumpWidget(NumberPuzzleApp(ads: AdService.disabled(), progress: pc, levels: _Levels(), settings: sc));
  for (var i = 0; i < 100 && find.byKey(const Key('playCurrent')).evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
  return sc;
}

void main() {
  test('settings persist and reload', () async {
    SharedPreferences.setMockInitialValues({});
    final a = SettingsController()..isLoaded = true;
    await a.setLanguage(AppLanguage.el);
    await a.setThemeMode(ThemeMode.dark);
    await a.setSound(false);
    await a.setHaptics(false);
    final b = SettingsController();
    await b.load();
    expect(b.language, AppLanguage.el);
    expect(b.locale, const Locale('el'));
    expect(b.themeMode, ThemeMode.dark);
    expect(b.sound, isFalse);
    expect(b.haptics, isFalse);
  });

  test('defaults: system language/theme, sound+haptics on', () async {
    SharedPreferences.setMockInitialValues({SettingsController.kLanguage: 'bogus'});
    final s = SettingsController();
    await s.load();
    expect(s.language, AppLanguage.system);
    expect(s.locale, isNull);
    expect(s.themeMode, ThemeMode.system);
    expect(s.sound && s.haptics, isTrue);
  });

  testWidgets('gear opens settings; language switches live and persists', (tester) async {
    await _pump(tester);
    expect(find.text('Classic'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('Ελληνικά'));
    await tester.pumpAndSettle();
    expect(find.text('Ρυθμίσεις'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString(SettingsController.kLanguage), 'el');
    await tester.tap(find.text('Σύστημα').first);
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('theme switches live (dark) and persists', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('Settings'))).brightness, Brightness.dark);
    expect((await SharedPreferences.getInstance()).getString(SettingsController.kTheme), 'dark');
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('Settings'))).brightness, Brightness.light);
  });

  testWidgets('persisted Greek + dark apply at startup; toggles; tutorial replay resets flag', (tester) async {
    final sc = await _pump(
      tester,
      prefs: {SettingsController.kLanguage: 'el', SettingsController.kTheme: 'dark', GameSaveStore.tutorialKey: true},
    );
    expect(find.text('Κλασικό'), findsOneWidget);
    expect(Theme.of(tester.element(find.text('Κλασικό'))).brightness, Brightness.dark);
    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsSound')));
    await tester.tap(find.byKey(const Key('settingsHaptics')));
    await tester.pumpAndSettle();
    expect(sc.sound || sc.haptics, isFalse);
    await tester.tap(find.byKey(const Key('settingsTutorial')));
    await tester.pumpAndSettle();
    expect(await GameSaveStore().tutorialDone(), isFalse);
    expect(find.text('Ο οδηγός θα εμφανιστεί ξανά στο επίπεδο 1.'), findsOneWidget);
  });
}
