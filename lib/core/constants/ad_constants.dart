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
  /// ⚠️ Production ships with FALSE (real units, real revenue). v1.0/v1.1.0
  /// accidentally shipped with true — zero revenue; flipped 2026-07-05.
  /// (Real ad units on a brand-new account can take a few hours to a day
  /// before they start serving — that delay is normal. Never click real ads
  /// on your own device — AdMob policy.)
  static const bool useTestAds = false;

  /// Banners are shown on the win screen + lobby.
  static const bool bannersEnabled = true;

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
  static const String _realBannerAndroid = 'ca-app-pub-8795917295916240/2514303064';
  static const String _realBannerIos = 'ca-app-pub-8795917295916240/4204044862';
  static const String _realRewardedAndroid = 'ca-app-pub-8795917295916240/5386210117';
  static const String _realRewardedIos = 'ca-app-pub-8795917295916240/6787187623';
  static const String _realInterstitialAndroid = 'ca-app-pub-8795917295916240/7385687498';
  static const String _realInterstitialIos = 'ca-app-pub-8795917295916240/7162326216';

  static String get bannerUnitId {
    if (useTestAds) {
      return Platform.isAndroid ? _testBannerAndroid : _testBannerIos;
    }
    return Platform.isAndroid ? _realBannerAndroid : _realBannerIos;
  }

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
