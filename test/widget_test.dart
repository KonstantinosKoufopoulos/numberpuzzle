import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numberpuzzle/ads/ad_ids.dart';
import 'package:numberpuzzle/ads/ad_service.dart';
import 'package:numberpuzzle/ui/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('home (level map) shows Classic and Daily (el)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.platformDispatcher.localesTestValue = const [Locale('el')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(NumberPuzzleApp(ads: AdService.disabled()));
    for (var i = 0; i < 100 && find.text('Κλασικό').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(find.text('Κλασικό'), findsOneWidget);
    expect(find.text('Ημερήσιο'), findsOneWidget);
  });

  test('tests/debug use only Google test ad ids', () {
    expect(AdIds.current.appId, startsWith('ca-app-pub-3940256099942544'));
    expect(AdIds.current.interstitial, startsWith('ca-app-pub-3940256099942544'));
    expect(AdIds.current.rewarded, startsWith('ca-app-pub-3940256099942544'));
    expect(AdIds.forMode(release: true).appId, 'ca-app-pub-1774874652706103~3439168584');
  });
}
