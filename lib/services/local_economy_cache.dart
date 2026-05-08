import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around SharedPreferences for economy data that must survive
/// app restarts but doesn't warrant a Firestore round-trip on every frame.
class LocalEconomyCache {
  static const _keyCoins = 'eco_coins';
  static const _keyLastDailyRewardDate = 'eco_last_daily_reward_date'; // ISO date yyyy-MM-dd UTC

  final SharedPreferences _prefs;

  LocalEconomyCache(this._prefs);

  // ── Coin balance ──────────────────────────────────────────────

  int get cachedCoins => _prefs.getInt(_keyCoins) ?? 0;

  Future<void> setCoins(int value) => _prefs.setInt(_keyCoins, value);

  // ── Daily reward ──────────────────────────────────────────────

  /// Returns the UTC date string (yyyy-MM-dd) when the last daily reward was claimed.
  String? get lastDailyRewardDate => _prefs.getString(_keyLastDailyRewardDate);

  Future<void> setLastDailyRewardDate(DateTime utcDate) =>
      _prefs.setString(_keyLastDailyRewardDate, _toDateString(utcDate));

  /// True if the daily reward has NOT been claimed today (UTC).
  bool get isDailyRewardAvailable {
    final last = lastDailyRewardDate;
    if (last == null) return true;
    return last != _toDateString(DateTime.now().toUtc());
  }

  static String _toDateString(DateTime utc) =>
      '${utc.year.toString().padLeft(4, '0')}-'
      '${utc.month.toString().padLeft(2, '0')}-'
      '${utc.day.toString().padLeft(2, '0')}';

  // ── Factory ───────────────────────────────────────────────────

  static Future<LocalEconomyCache> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalEconomyCache(prefs);
  }
}
