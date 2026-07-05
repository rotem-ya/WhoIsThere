import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'qa_logger_service.dart';

/// Asks for a store rating at a GOOD moment (right after the player wins),
/// rarely and politely:
///  • only from the player's 3rd win onwards (they clearly like the game),
///  • at most once every 30 days,
///  • stops forever after 3 prompts (the OS also enforces its own quota —
///    on iOS the sheet simply won't appear more than 3×/year).
/// The native in-app sheet keeps the player inside the game (no store jump),
/// which is the highest-converting way to collect ratings.
class ReviewPromptService {
  ReviewPromptService._();
  static final ReviewPromptService instance = ReviewPromptService._();

  static const _winsKey = 'review_prompt_wins';
  static const _lastAskMsKey = 'review_prompt_last_ask_ms';
  static const _askCountKey = 'review_prompt_ask_count';

  static const int _minWins = 3;
  static const int _maxAsks = 3;
  static const int _cooldownMs = 30 * 24 * 60 * 60 * 1000; // 30 days

  bool _askedThisSession = false;

  /// Call when the local player WINS a game. Increments the win counter and
  /// shows the native review sheet when all conditions pass. Fail-soft: any
  /// error is swallowed (rating must never break the win flow).
  Future<void> onGameWon() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wins = (prefs.getInt(_winsKey) ?? 0) + 1;
      await prefs.setInt(_winsKey, wins);

      if (_askedThisSession) return;
      if (wins < _minWins) return;
      final askCount = prefs.getInt(_askCountKey) ?? 0;
      if (askCount >= _maxAsks) return;
      final lastAsk = prefs.getInt(_lastAskMsKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastAsk < _cooldownMs) return;

      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;

      _askedThisSession = true;
      await prefs.setInt(_lastAskMsKey, now);
      await prefs.setInt(_askCountKey, askCount + 1);
      QaLoggerService.instance
          .log('REVIEW', 'RATING_PROMPT_SHOWN wins=$wins ask=${askCount + 1}');
      await review.requestReview();
    } catch (_) {
      // Non-critical — never let the rating flow break a win celebration.
    }
  }
}
