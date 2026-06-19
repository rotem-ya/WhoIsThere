import 'dart:io';

class AdConstants {
  AdConstants._();

  /// Master switch for ad display. Real AdMob unit IDs (rewarded +
  /// interstitial) are now in place, so ads are enabled for production.
  static const bool adsEnabled = true;

  /// Banners are intentionally OFF — no banner ad unit was created in AdMob
  /// (the product uses only rewarded + interstitial). Kept as a separate gate
  /// so banner widgets never render even while [adsEnabled] is true.
  static const bool bannersEnabled = false;

  // ── Real AdMob unit IDs — publisher ca-app-pub-8795917295916240 ──────────
  // App IDs (with '~') live in AndroidManifest.xml and ios/Runner/Info.plist:
  //   Android app: ca-app-pub-8795917295916240~6423959619
  //   iOS app:     ca-app-pub-8795917295916240~3606224584

  /// No real banner unit exists; falls back to Google's test ID. Only ever
  /// consumed when [bannersEnabled] is true (currently never).
  static String get bannerUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // test
    } else {
      return 'ca-app-pub-3940256099942544/2934735716'; // test iOS
    }
  }

  static String get rewardedUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-8795917295916240/5386210117';
    } else {
      return 'ca-app-pub-8795917295916240/6787187623';
    }
  }

  static String get interstitialUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-8795917295916240/7385687498';
    } else {
      return 'ca-app-pub-8795917295916240/7162326216';
    }
  }
}
