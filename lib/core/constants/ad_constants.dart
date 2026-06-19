import 'dart:io';

class AdConstants {
  AdConstants._();

  /// Master switch for ad display. Real AdMob unit IDs (rewarded +
  /// interstitial) are in place, so ads are enabled for production.
  static const bool adsEnabled = true;

  /// When true, ALL ad units use Google's official TEST ids. Test ads always
  /// fill instantly and are safe to click — use this to VERIFY the integration
  /// on a real device.
  ///
  /// ⚠️ MUST be set back to false for the production / Play Store build:
  /// test ads earn no money, and showing them to real users violates AdMob
  /// policy. (Real ad units on a brand-new account can take a few hours to a
  /// day before they start serving — that delay is normal.)
  static const bool useTestAds = true;

  /// Banners are intentionally OFF — no banner ad unit was created in AdMob
  /// (the product uses only rewarded + interstitial). Kept as a separate gate
  /// so banner widgets never render even while [adsEnabled] is true.
  static const bool bannersEnabled = false;

  // ── Google official TEST unit IDs (always fill) ──────────────────────────
  static const String _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedIos = 'ca-app-pub-3940256099942544/1712485313';
  static const String _testInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialIos = 'ca-app-pub-3940256099942544/4411468910';

  // ── Real AdMob unit IDs — publisher ca-app-pub-8795917295916240 ──────────
  // App IDs (with '~') live in AndroidManifest.xml and ios/Runner/Info.plist:
  //   Android app: ca-app-pub-8795917295916240~6423959619
  //   iOS app:     ca-app-pub-8795917295916240~3606224584
  static const String _realRewardedAndroid = 'ca-app-pub-8795917295916240/5386210117';
  static const String _realRewardedIos = 'ca-app-pub-8795917295916240/6787187623';
  static const String _realInterstitialAndroid = 'ca-app-pub-8795917295916240/7385687498';
  static const String _realInterstitialIos = 'ca-app-pub-8795917295916240/7162326216';

  /// No real banner unit exists; always uses the test banner. Only ever
  /// consumed when [bannersEnabled] is true (currently never).
  static String get bannerUnitId =>
      Platform.isAndroid ? _testBannerAndroid : _testBannerIos;

  static String get rewardedUnitId {
    if (useTestAds) {
      return Platform.isAndroid ? _testRewardedAndroid : _testRewardedIos;
    }
    return Platform.isAndroid ? _realRewardedAndroid : _realRewardedIos;
  }

  static String get interstitialUnitId {
    if (useTestAds) {
      return Platform.isAndroid ? _testInterstitialAndroid : _testInterstitialIos;
    }
    return Platform.isAndroid ? _realInterstitialAndroid : _realInterstitialIos;
  }
}
