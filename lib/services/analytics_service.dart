import 'package:firebase_analytics/firebase_analytics.dart';

import 'qa_logger_service.dart';

/// Thin, fail-soft wrapper around Firebase Analytics. Every call is
/// fire-and-forget and swallows errors — analytics must never affect
/// gameplay. Event names/params are the project's stable analytics contract;
/// add here, never inline elsewhere, so the taxonomy stays in one place.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics get _fa => FirebaseAnalytics.instance;

  void _log(String name, [Map<String, Object>? params]) {
    try {
      _fa.logEvent(name: name, parameters: params);
    } catch (e) {
      QaLoggerService.instance.log('ANALYTICS', 'LOG_FAILED name=$name e=$e');
    }
  }

  /// mode: 'places' | 'heat' | 'letters'. solo = vs bots only.
  void gameStart({required String mode, required bool solo}) =>
      _log('game_start', {'mode': mode, 'solo': solo ? 1 : 0});

  void gameWin({required String mode, required bool solo}) =>
      _log('game_win', {'mode': mode, 'solo': solo ? 1 : 0});

  /// kind: 'friend_code' | 'room'.
  void inviteSent({required String kind}) =>
      _log('invite_sent', {'kind': kind});

  void rewardedAdWatched({required String placement}) =>
      _log('ad_rewarded_watched', {'placement': placement});

  void feedbackSent() => _log('feedback_sent');

  void storeView() => _log('store_view');
}
