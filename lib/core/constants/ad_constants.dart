import 'dart:io';

class AdConstants {
  AdConstants._();

  /// Master switch for ad display. Kept OFF for launch because the unit IDs
  /// below are still Google's test IDs — showing test ads in production yields
  /// no revenue and risks policy issues. Flip to true once real AdMob unit IDs
  /// replace the test values below.
  static const bool adsEnabled = false;

  // Replace these with real unit IDs from AdMob console before release.
  // Current values are Google's official test IDs.
  static String get bannerUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // test
    } else {
      return 'ca-app-pub-3940256099942544/2934735716'; // test iOS
    }
  }

  static String get rewardedUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917'; // test
    } else {
      return 'ca-app-pub-3940256099942544/1712485313'; // test iOS
    }
  }
}
