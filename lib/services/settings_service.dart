import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One entry in the recent-games strip: which game kind was played, whether it
/// was won, and when (ms since epoch).
class RecentGame {
  final String kind; // matches the home _GameKind name
  final bool won;
  final int ts;
  const RecentGame({required this.kind, required this.won, required this.ts});

  Map<String, dynamic> toJson() => {'k': kind, 'w': won, 't': ts};
  factory RecentGame.fromJson(Map<String, dynamic> j) => RecentGame(
        kind: j['k'] as String? ?? 'places',
        won: j['w'] as bool? ?? false,
        ts: (j['t'] as num? ?? 0).toInt(),
      );
}

class SettingsService {
  static SettingsService? _instance;

  static SettingsService get instance {
    assert(_instance != null, 'Call SettingsService.init() before use');
    return _instance!;
  }

  static Future<SettingsService> init() async {
    final prefs = await SharedPreferences.getInstance();
    _instance = SettingsService._(prefs);
    return _instance!;
  }

  static const _kMusic = 'settings_music_volume';
  static const _kSfx = 'settings_sfx_volume';
  static const _kVibration = 'settings_vibration';
  static const _kBgVariant = 'settings_bg_variant';
  static const _kRecentGames = 'recent_games_v1';

  final SharedPreferences _prefs;
  SettingsService._(this._prefs);

  double get musicVolume => (_prefs.getDouble(_kMusic) ?? 0.4).clamp(0.0, 1.0);
  double get sfxVolume => (_prefs.getDouble(_kSfx) ?? 1.0).clamp(0.0, 1.0);
  bool get vibrationEnabled => _prefs.getBool(_kVibration) ?? true;
  // Selected background mood: 0 grape (default) / 1 night / 2 sea / 3 sunset.
  int get bgVariant => (_prefs.getInt(_kBgVariant) ?? 0).clamp(0, 3);

  Future<void> setMusicVolume(double v) =>
      _prefs.setDouble(_kMusic, v.clamp(0.0, 1.0));
  Future<void> setSfxVolume(double v) =>
      _prefs.setDouble(_kSfx, v.clamp(0.0, 1.0));
  Future<void> setVibrationEnabled(bool v) => _prefs.setBool(_kVibration, v);
  Future<void> setBgVariant(int v) => _prefs.setInt(_kBgVariant, v.clamp(0, 3));

  // ── Recent games ──────────────────────────────────────────────────────────
  /// The last few games played (most recent first), for the home quick-replay
  /// strip. Stored locally only.
  List<RecentGame> get recentGames {
    final raw = _prefs.getString(_kRecentGames);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => RecentGame.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Record a finished game at the front of the list (deduped by kind, capped).
  Future<void> pushRecentGame(String kind, bool won, int ts) async {
    final current = recentGames.where((g) => g.kind != kind).toList();
    current.insert(0, RecentGame(kind: kind, won: won, ts: ts));
    final capped = current.take(4).toList();
    await _prefs.setString(
        _kRecentGames, jsonEncode(capped.map((g) => g.toJson()).toList()));
  }
}
