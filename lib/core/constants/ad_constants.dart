import 'dart:io';

class AdConstants {
  AdConstants._();

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
