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

  static final AssetSource _coinSound = AssetSource('sounds/daily_coins.mp3');
  static final AssetSource _popSound = AssetSource('sounds/player_join.wav');

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
}
