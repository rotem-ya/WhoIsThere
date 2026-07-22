import 'package:audioplayers/audioplayers.dart';

import 'settings_service.dart';

/// Menu-side background music, on a SINGLE looping player. Only one music stream
/// ever exists here — critical because two simultaneous mp3 streams through
/// separate players is a known iOS crash trigger (audioplayers). In-game music
/// stays on the game board's own player; this service is STOPPED on game routes
/// (see MusicRouteObserver), so the two never overlap.
///
/// Fully fail-soft: every track is optional. Until the mp3 files are dropped
/// into assets/sounds/, calls are silent no-ops. Respects the user's music
/// volume live.
enum MenuTrack { none, menu, lobby, win }

class MusicService {
  MusicService._();
  static final MusicService instance = MusicService._();

  final AudioPlayer _player = AudioPlayer(playerId: 'menu-music');

  static const _paths = {
    MenuTrack.menu: 'sounds/music_menu.mp3',
    // MenuTrack.lobby intentionally has no track: the lobby stays silent.
    MenuTrack.win: 'sounds/music_win.mp3',
  };

  MenuTrack _current = MenuTrack.none;
  bool _started = false;

  double get _scale => SettingsService.instance.musicVolume;

  /// Switch to [track] (no-op if already playing it). [MenuTrack.none] stops.
  Future<void> play(MenuTrack track) async {
    if (track == _current && _started) {
      // Already on this track; just refresh volume in case the setting changed.
      await _safe(() => _player.setVolume((_scale * 0.5).clamp(0.0, 1.0)));
      return;
    }
    _current = track;
    if (track == MenuTrack.none) {
      _started = false;
      await _safe(_player.stop);
      return;
    }
    final path = _paths[track];
    if (path == null) return;
    await _safe(() async {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume((_scale * 0.5).clamp(0.0, 1.0));
      await _player.play(AssetSource(path));
      _started = true;
    });
  }

  Future<void> stop() => play(MenuTrack.none);

  /// Live volume update from the settings slider.
  Future<void> applyVolume() async {
    if (!_started) return;
    await _safe(() => _player.setVolume((_scale * 0.5).clamp(0.0, 1.0)));
  }

  Future<void> _safe(Future<void> Function() op) async {
    try {
      if (_scale <= 0 && _current != MenuTrack.none) {
        // Muted — make sure nothing is playing but keep _current so unmuting
        // resumes the right track.
        await _player.stop();
        _started = false;
        return;
      }
      await op();
    } catch (_) {
      // Music is non-critical — swallow platform/asset errors.
    }
  }
}
