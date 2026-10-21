import 'package:numberpuzzle/ads/ad_ids.dart';
import 'package:test/test.dart';

void main() {
  const g = 'ca-app-pub-3940256099942544';
  test('real ids only for release without ADS_TEST', () {
    expect(AdIds.forMode(release: true).rewarded, isNot(startsWith(g)));
    expect(AdIds.forMode(release: true, adsTest: true), same(AdIds.test));
    expect(AdIds.forMode(release: false), same(AdIds.test));
    expect(AdIds.forMode(release: false, adsTest: true), same(AdIds.test));
  });
  test('test builds never use real ids', () {
    expect(AdIds.kAdsTestFlag, isFalse);
    for (final id in [AdIds.current.appId, AdIds.current.interstitial, AdIds.current.rewarded]) {
      expect(id, startsWith(g));
    }
  });
}
