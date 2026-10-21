import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads/ad_policy.dart';
import 'ads/ad_service.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final ads = AdService(
    enabled: AdService.kAdsFlag,
    policy: AdPolicy(store: PrefsAdPolicyStore(prefs)),
  );
  runApp(NumberPuzzleApp(ads: ads));
  // UMP consent first; ads load only once canRequestAds is true.
  await ads.init();
}
