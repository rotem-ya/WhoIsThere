import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/constants/ad_constants.dart';

/// Loads and shows AdMob rewarded + interstitial ads. A single instance lives
/// for the app's lifetime (see `adServiceProvider`). Each ad is preloaded so
/// the next show is instant, and the next one is preloaded again on dismiss.
class AdService {
  AdService();

  RewardedAd? _rewarded;
  bool _loadingRewarded = false;

  InterstitialAd? _interstitial;
  bool _loadingInterstitial = false;

  /// Minimum gap between interstitials so players aren't spammed between games.
  static const Duration _interstitialMinGap = Duration(minutes: 2);
  DateTime? _lastInterstitialShown;

  bool get isRewardedReady => _rewarded != null;

  // ── Rewarded ──────────────────────────────────────────────────────────────

  void preloadRewarded() {
    if (!AdConstants.adsEnabled || _rewarded != null || _loadingRewarded) {
      return;
    }
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: AdConstants.rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _loadingRewarded = false;
        },
        onAdFailedToLoad: (_) {
          _rewarded = null;
          _loadingRewarded = false;
        },
      ),
    );
  }

  /// Shows a rewarded ad. Returns true only if the user watched long enough to
  /// earn the reward. If no ad is ready, returns false immediately (and starts
  /// preloading one for next time) so the caller can fall back gracefully.
  Future<bool> showRewarded() async {
    if (!AdConstants.adsEnabled) return false;
    final ad = _rewarded;
    if (ad == null) {
      preloadRewarded();
      return false;
    }
    _rewarded = null; // consume

    var earned = false;
    final completer = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preloadRewarded();
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        preloadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    ad.show(onUserEarnedReward: (_, __) => earned = true);
    return completer.future;
  }

  // ── Interstitial ────────────────────────────────────────────────────────

  void preloadInterstitial() {
    if (!AdConstants.adsEnabled || _interstitial != null || _loadingInterstitial) {
      return;
    }
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: AdConstants.interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _loadingInterstitial = false;
        },
        onAdFailedToLoad: (_) {
          _interstitial = null;
          _loadingInterstitial = false;
        },
      ),
    );
  }

  /// Shows an interstitial if one is ready and the min-gap has elapsed.
  /// Never blocks game flow — returns immediately when not ready, and awaits
  /// dismissal when shown so the caller can navigate afterwards.
  Future<void> maybeShowInterstitial() async {
    if (!AdConstants.adsEnabled) return;
    final now = DateTime.now();
    if (_lastInterstitialShown != null &&
        now.difference(_lastInterstitialShown!) < _interstitialMinGap) {
      return;
    }
    final ad = _interstitial;
    if (ad == null) {
      preloadInterstitial();
      return;
    }
    _interstitial = null; // consume
    _lastInterstitialShown = now;

    final completer = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preloadInterstitial();
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        preloadInterstitial();
        if (!completer.isCompleted) completer.complete();
      },
    );
    await ad.show();
    return completer.future;
  }

  void dispose() {
    _rewarded?.dispose();
    _interstitial?.dispose();
  }
}
