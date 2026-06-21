import 'package:audioplayers/audioplayers.dart';

import 'settings_service.dart';

/// Lightweight one-shot sound effects for UI moments (store purchases, equips,
/// rewards). Centralises SFX so any screen can add a satisfying sound without
/// spinning up its own player. Volume always respects the user's sfx setting,
/// and playback is best-effort (never throws into the UI).
class SfxService {
  SfxService._();
  static final SfxService instance = SfxService._();

  final AudioPlayer _coin = AudioPlayer(playerId: 'sfx-coin');
  final AudioPlayer _pop = AudioPlayer(playerId: 'sfx-pop');
  final AudioPlayer _ding = AudioPlayer(playerId: 'sfx-ding');
  final AudioPlayer _buzz = AudioPlayer(playerId: 'sfx-buzz');
  final AudioPlayer _reveal = AudioPlayer(playerId: 'sfx-reveal');
  final AudioPlayer _fanfare = AudioPlayer(playerId: 'sfx-fanfare');

  static final AssetSource _coinSound = AssetSource('sounds/daily_coins.mp3');
  static final AssetSource _popSound = AssetSource('sounds/player_join.wav');
  static final AssetSource _dingSound = AssetSource('sounds/correct_ding.wav');
  static final AssetSource _buzzSound = AssetSource('sounds/wrong_buzz.wav');
  static final AssetSource _revealSound = AssetSource('sounds/aperture_open.wav');
  static final AssetSource _fanfareSound = AssetSource('sounds/victory_fanfare.mp3');

  Future<void> _play(AudioPlayer player, AssetSource src) async {
    try {
      final vol = SettingsService.instance.sfxVolume;
      if (vol <= 0) return;
      await player.stop();
      await player.setVolume(vol);
      await player.play(src);
    } catch (_) {
      // Audio is non-critical — swallow any platform/asset errors.
    }
  }

  /// A coin "cha-ching" for a successful purchase.
  Future<void> purchase() => _play(_coin, _coinSound);

  /// A light pop for equipping/selecting a cosmetic.
  Future<void> equip() => _play(_pop, _popSound);

  // ── Letters game ──────────────────────────────────────────────────────────
  /// Correct letter placed (green).
  Future<void> letterCorrect() => _play(_ding, _dingSound);
  /// Wrong / absent letter (gray).
  Future<void> letterWrong() => _play(_buzz, _buzzSound);
  /// Image tiles revealed.
  Future<void> reveal() => _play(_reveal, _revealSound);
  /// Victory fanfare.
  Future<void> win() => _play(_fanfare, _fanfareSound);
}
