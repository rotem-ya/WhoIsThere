import 'package:audioplayers/audioplayers.dart';

import 'settings_service.dart';

/// Lightweight one-shot sound effects for UI moments (button taps, tab
/// switches, sheets, economy, notifications, store purchases). Centralises SFX
/// so any screen can add a satisfying sound without spinning up its own player.
///
/// Volume always respects the user's sfx setting, and playback is best-effort:
/// a missing asset or platform hiccup is swallowed silently and never reaches
/// the UI. This means new sounds can be wired in code **before** the audio
/// files exist on disk — they simply stay silent until the assets are dropped
/// into `assets/sounds/ui/` (see the README there for the expected filenames).
class SfxService {
  SfxService._();
  static final SfxService instance = SfxService._();

  // ── Existing game / store players ─────────────────────────────────────────
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

  // ── New UI / economy / social players ─────────────────────────────────────
  // Each sound gets its own player so simultaneous events don't cut each other
  // off. Files live under assets/sounds/ui/ (dropped in separately).
  final AudioPlayer _uiClick = AudioPlayer(playerId: 'sfx-ui-click');
  final AudioPlayer _uiCta = AudioPlayer(playerId: 'sfx-ui-cta');
  final AudioPlayer _uiBack = AudioPlayer(playerId: 'sfx-ui-back');
  final AudioPlayer _uiTab = AudioPlayer(playerId: 'sfx-ui-tab');
  final AudioPlayer _sheetOpen = AudioPlayer(playerId: 'sfx-sheet-open');
  final AudioPlayer _sheetClose = AudioPlayer(playerId: 'sfx-sheet-close');
  final AudioPlayer _coinGain = AudioPlayer(playerId: 'sfx-coin-gain');
  final AudioPlayer _coinSpend = AudioPlayer(playerId: 'sfx-coin-spend');
  final AudioPlayer _denied = AudioPlayer(playerId: 'sfx-denied');
  final AudioPlayer _notify = AudioPlayer(playerId: 'sfx-notify');
  final AudioPlayer _chat = AudioPlayer(playerId: 'sfx-chat');
  final AudioPlayer _rankUp = AudioPlayer(playerId: 'sfx-rank-up');

  // ── Boost sounds (v1.4.x) — drop the files into assets/sounds/ui/ to enable.
  final AudioPlayer _transition = AudioPlayer(playerId: 'sfx-transition');
  final AudioPlayer _streak = AudioPlayer(playerId: 'sfx-streak');
  final AudioPlayer _tileFlip = AudioPlayer(playerId: 'sfx-tile-flip');
  final AudioPlayer _coinShower = AudioPlayer(playerId: 'sfx-coin-shower');
  final AudioPlayer _spinTick = AudioPlayer(playerId: 'sfx-spin-tick');
  final AudioPlayer _spinLand = AudioPlayer(playerId: 'sfx-spin-land');
  final AudioPlayer _questDone = AudioPlayer(playerId: 'sfx-quest-done');
  final AudioPlayer _heartbeat = AudioPlayer(playerId: 'sfx-heartbeat');

  static final AssetSource _uiClickSound = AssetSource('sounds/ui/ui_click.ogg');
  static final AssetSource _uiCtaSound = AssetSource('sounds/ui/ui_cta.ogg');
  static final AssetSource _uiBackSound = AssetSource('sounds/ui/ui_back.ogg');
  static final AssetSource _uiTabSound = AssetSource('sounds/ui/ui_tab.ogg');
  static final AssetSource _sheetOpenSound = AssetSource('sounds/ui/sheet_open.ogg');
  static final AssetSource _sheetCloseSound = AssetSource('sounds/ui/sheet_close.ogg');
  static final AssetSource _coinGainSound = AssetSource('sounds/ui/coin_gain.ogg');
  static final AssetSource _coinSpendSound = AssetSource('sounds/ui/coin_spend.ogg');
  static final AssetSource _deniedSound = AssetSource('sounds/ui/denied.ogg');
  static final AssetSource _notifySound = AssetSource('sounds/ui/notify.ogg');
  static final AssetSource _chatSound = AssetSource('sounds/ui/chat_pop.ogg');
  static final AssetSource _rankUpSound = AssetSource('sounds/ui/rank_up.ogg');

  static final AssetSource _transitionSound = AssetSource('sounds/ui/transition.ogg');
  static final AssetSource _streakSound = AssetSource('sounds/ui/streak.ogg');
  static final AssetSource _tileFlipSound = AssetSource('sounds/ui/tile_flip.ogg');
  static final AssetSource _coinShowerSound = AssetSource('sounds/ui/coin_shower.ogg');
  static final AssetSource _spinTickSound = AssetSource('sounds/ui/spin_tick.ogg');
  static final AssetSource _spinLandSound = AssetSource('sounds/ui/spin_land.ogg');
  static final AssetSource _questDoneSound = AssetSource('sounds/ui/quest_complete.ogg');
  static final AssetSource _heartbeatSound = AssetSource('sounds/ui/heartbeat.ogg');

  Future<void> _play(AudioPlayer player, AssetSource src, {double scale = 1.0}) async {
    try {
      final vol = SettingsService.instance.sfxVolume * scale;
      if (vol <= 0) return;
      await player.stop();
      await player.setVolume(vol.clamp(0.0, 1.0));
      await player.play(src);
    } catch (_) {
      // Audio is non-critical — swallow any platform/asset errors.
    }
  }

  // ── Store / cosmetics ─────────────────────────────────────────────────────
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

  // ── UI interaction (wired through AppFeedback / choke points) ─────────────
  /// A soft click for a regular button tap. Played a touch below full volume so
  /// it stays in the background of the interaction.
  Future<void> uiClick() => _play(_uiClick, _uiClickSound, scale: 0.7);
  /// A richer click for a primary / CTA button.
  Future<void> uiPrimary() => _play(_uiCta, _uiCtaSound, scale: 0.85);
  /// A descending tone for cancel / back.
  Future<void> uiBack() => _play(_uiBack, _uiBackSound, scale: 0.7);
  /// A light tick when switching tabs.
  Future<void> tabChange() => _play(_uiTab, _uiTabSound, scale: 0.6);
  /// Bottom sheet opening (rising tone).
  Future<void> sheetOpen() => _play(_sheetOpen, _sheetOpenSound, scale: 0.7);
  /// Bottom sheet closing.
  Future<void> sheetClose() => _play(_sheetClose, _sheetCloseSound, scale: 0.6);

  // ── Economy ───────────────────────────────────────────────────────────────
  /// Coins received.
  Future<void> coinGain() => _play(_coinGain, _coinGainSound);
  /// Coins spent.
  Future<void> coinSpend() => _play(_coinSpend, _coinSpendSound, scale: 0.8);
  /// Action blocked — not enough coins.
  Future<void> denied() => _play(_denied, _deniedSound, scale: 0.8);

  // ── Social ────────────────────────────────────────────────────────────────
  /// Incoming friend request / game invite / group invite banner.
  Future<void> notify() => _play(_notify, _notifySound, scale: 0.8);
  /// Incoming chat message (only when the chat sheet is closed).
  Future<void> chatPop() => _play(_chat, _chatSound, scale: 0.6);

  /// Player crossed into a new rank tier — a triumphant jingle.
  Future<void> rankUp() => _play(_rankUp, _rankUpSound);

  // ── Boost moments (v1.4.x) — silent until the assets are dropped in ────────
  /// Whoosh between rounds (the round interlude).
  Future<void> transition() => _play(_transition, _transitionSound, scale: 0.8);
  /// Consecutive-hits streak; pitch/energy can be implied by [level] volume.
  Future<void> streak(int level) =>
      _play(_streak, _streakSound, scale: (0.6 + level * 0.08).clamp(0.6, 1.0));
  /// A tile flips open on the board.
  Future<void> tileFlip() => _play(_tileFlip, _tileFlipSound, scale: 0.5);
  /// A cascade of coins flying to the wallet.
  Future<void> coinShower() => _play(_coinShower, _coinShowerSound);
  /// Spin wheel ratchet tick (played repeatedly while spinning).
  Future<void> spinTick() => _play(_spinTick, _spinTickSound, scale: 0.5);
  /// Spin wheel lands on a prize.
  Future<void> spinLand() => _play(_spinLand, _spinLandSound);
  /// A daily quest was completed / claimed.
  Future<void> questComplete() => _play(_questDone, _questDoneSound);
  /// A single heartbeat thump during the final urgent seconds.
  Future<void> heartbeat() => _play(_heartbeat, _heartbeatSound, scale: 0.7);
}
