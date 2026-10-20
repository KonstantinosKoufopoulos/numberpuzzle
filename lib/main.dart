import 'package:flutter/material.dart';

import 'ads/ad_service.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ads = AdService(enabled: AdService.kAdsFlag);
  runApp(NumberPuzzleApp(ads: ads));
  // UMP consent + SDK init at startup (non-blocking for first frame).
  await ads.init();
}
