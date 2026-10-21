import 'package:numberpuzzle/ads/ad_ids.dart';
import 'package:test/test.dart';

const _google = 'ca-app-pub-3940256099942544';
const _real = 'ca-app-pub-1774874652706103';

void main() {
  test('test ids unless release && ADS_REAL (default build: never real)', () {
    for (final release in [false, true]) {
      for (final real in [false, true]) {
        final ids = AdIds.forMode(release: release, adsReal: real);
        final expectReal = AdIds.kAdsReal && release && real;
        for (final id in [ids.appId, ids.interstitial, ids.rewarded]) {
          expect(id, startsWith(expectReal ? _real : _google), reason: 'release=$release adsReal=$real');
        }
      }
    }
  });

  test('ADS_REAL defaults to false; current ids are Google test ids in tests', () {
    expect(const bool.fromEnvironment('ADS_REAL'), AdIds.kAdsReal);
    if (!AdIds.kAdsReal) expect(AdIds.current, same(AdIds.test));
    for (final id in [AdIds.current.appId, AdIds.current.interstitial, AdIds.current.rewarded]) {
      expect(id, startsWith(_google)); // tests are never release builds
    }
  });
}
