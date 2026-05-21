import 'widgets/answer_slots.dart';
import 'widgets/game_layout.dart';
import 'widgets/game_winner_view.dart';
import 'dart:async';
import 'dart:math' show Random, min, pi;

import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';

import '../../core/theme/app_styles.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/game_constants.dart';
import '../../models/game_image_model.dart';
import '../../models/player_model.dart';
import '../../models/room_model.dart';
import '../../models/economy/match_reward_breakdown.dart';
import '../../providers/providers.dart';
import '../../services/hint_economy_guard.dart';
import '../../services/reward_calculator.dart';
import '../../services/qa_logger_service.dart';
import '../../widgets/game/animated_reward.dart';
import '../../widgets/game/letter_bank_input.dart';
import 'widgets/game_top_hud.dart';
import 'widgets/game_board_view.dart';

class GameBoardScreen extends ConsumerStatefulWidget {
  final String roomId;

  const GameBoardScreen({super.key, required this.roomId});

  @override
  ConsumerState<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends ConsumerState<GameBoardScreen>
    with WidgetsBindingObserver {
  final _random = Random();
  final _guessController = TextEditingController();

  GameImageModel? _image;
  String _loadedImageId = '';
  String _lastBotTurnKey = '';
  bool _isBusy = false;

  // Turn-reveal tracking for human guess gate
  bool _hasRevealedThisTurn = false;
  int _revealedAtTurnIndex = -1;
  bool _hasGuessedThisTurn = false;

  // Hint fact cycling
  int _nextFactIndex = 0;

  // Guess-event banner
  int _lastShownGuessCount = -1;
  Map<String, dynamic>? _currentBanner;
  bool _showBanner = false;

  // Dynamic music volume — escalates with board fill
  double _lastMusicVolume = 0.44;

  // Bot typing simulation
  bool _showBotTyping = false;
  String _botTypingName = '';
  String _botTypingText = '';

  // Background music
  static final AudioPlayer _bgPlayer = AudioPlayer(playerId: 'studio-bg');
  static final AssetSource _bgMusic = AssetSource('sounds/background_studio.mp3');

  // Reveal sound — owned here, not by ApertureTile
  static final AudioPlayer _revealSoundPlayer = AudioPlayer(playerId: 'reveal-aperture');
  static final AssetSource _revealSound = AssetSource('sounds/aperture_open.wav');

  static Future<void> _primeRevealSound() async {
    try {
      await _revealSoundPlayer.setPlayerMode(PlayerMode.lowLatency);
    } catch (_) {}
    try {
      await _revealSoundPlayer.setSource(_revealSound);
    } catch (_) {}
  }

  static Future<void> _playRevealSound() async {
    try {
      await _revealSoundPlayer.stop();
      await _revealSoundPlayer.play(_revealSound);
    } catch (_) {}
  }

  static Future<void> _primeGuessSounds() async {
    try {
      await _wrongBuzzPlayer.setPlayerMode(PlayerMode.lowLatency);
      await _wrongBuzzPlayer.setSource(_wrongBuzzSound);
    } catch (_) {}
    try {
      await _correctDingPlayer.setPlayerMode(PlayerMode.lowLatency);
      await _correctDingPlayer.setSource(_correctDingSound);
    } catch (_) {}
  }

  static Future<void> _playWrongBuzz() async {
    try {
      await _wrongBuzzPlayer.stop();
      await _wrongBuzzPlayer.play(_wrongBuzzSound);
    } catch (_) {}
  }

  static Future<void> _playCorrectDing() async {
    try {
      await _correctDingPlayer.stop();
      await _correctDingPlayer.play(_correctDingSound);
    } catch (_) {}
  }

  static Future<void> _startBackgroundMusic() async {
    try {
      await _bgPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgPlayer.setVolume(0.44);
      await _bgPlayer.play(_bgMusic);
    } catch (_) {}
  }

  void _syncMusicVolume(RoomModel room) {
    final totalTiles = room.gridSize * room.gridSize;
    final ratio = totalTiles > 0 ? room.placedPieces.length / totalTiles : 0.0;
    final double target = ratio >= 0.75 ? 0.72 : ratio >= 0.50 ? 0.58 : 0.44;
    if (target != _lastMusicVolume) {
      _lastMusicVolume = target;
      _bgPlayer.setVolume(target).ignore();
    }
  }

  // QA logging flags
  bool _gameScreenLogged = false;
  bool _gameDataLogged = false;
  GamePhase? _lastKnownPhase;
  TurnPhase? _lastKnownTurnPhase;
  int? _lastKnownRevealDeadlineMs; // detect first revealDeadlineMs (game start)

  // Cycle integrity
  int? _lastKnownCycleId;

  // Deadline tracking for timer lifecycle logs
  int? _lastKnownGuessOpportunityDeadlineMs;
  int? _lastKnownGuessModeDeadlineMs;

  // Snapshot freshness
  int? _lastSnapshotMs;
  int? _lastSnapshotLogCycleId;

  // Watchdog state (issue keys active right now)
  int _watchdogTickCount = 0;
  final Set<String> _watchdogActiveIssues = {};

  // Session summary counters
  int _sessionRevealCount = 0;
  // Unique timeout events keyed by phase_deadline — retry attempts do not inflate this
  final Set<String> _sessionTimeoutKeys = {};
  int _sessionGuessModeCount = 0;
  int _sessionWrongGuessCount = 0;
  int _sessionWatchdogEventCount = 0;
  bool? _lastGuessEventCorrect;

  // Passive expiry detection — updated each build, read by _expiryTimer
  RoomModel? _latestRoom;
  String? _currentUserIdForTimer;
  Timer? _expiryTimer;

  // Expiry deduplication — permanent marker set ONLY after confirmed commit
  int? _lastExpiredRevealDeadline;
  int? _lastExpiredGuessOpportunityDeadline;
  int? _lastExpiredGuessModeDeadline;
  // Per-phase retry cooldowns (2s) — prevents tick-spam on failed attempts
  int? _revealTimeoutLastAttemptMs;
  int? _guessOppTimeoutLastAttemptMs;
  int? _guessModeTimeoutLastAttemptMs;
  // Non-owner observation dedup — log once per expired deadline
  int? _lastObservedNotOwnerRevealDeadline;
  // EXPIRY_DEDUP_SKIP spam suppression — log first, then at most once per 30s
  int _dedupSkipCount_reveal = 0;
  int? _lastDedupSkipLogMs_reveal;
  int _dedupSkipCount_guessOpp = 0;
  int? _lastDedupSkipLogMs_guessOpp;
  int _dedupSkipCount_guessMode = 0;
  int? _lastDedupSkipLogMs_guessMode;
  // Snapshot stale escalation — log each level once per stale period
  String? _snapshotStaleLevelLogged;
  // Watchdog stuck confirmation — log once when issue persists >10s
  final Map<String, int> _watchdogFirstSeenMs = {};
  final Set<String> _watchdogConfirmedIssues = {};
  // Audio recovery — only attempt when app is in foreground
  bool _appIsInForeground = true;
  // Offline UX — local-only UI state, never written to Firestore
  bool _isOffline = false;
  bool _showRecoveredBanner = false;
  // Snapshot state at offline-detection time — recovery requires advance beyond these
  int? _offlineSinceCycleId;
  TurnPhase? _offlineSinceTurnPhase;

  // Economy
  bool _rewardApplied = false;
  DateTime? _gameStartTime;
  MatchRewardBreakdown? _rewardBreakdown;

  // Wrong / correct guess sounds
  static final AudioPlayer _wrongBuzzPlayer = AudioPlayer(playerId: 'wrong-buzz');
  static final AssetSource _wrongBuzzSound = AssetSource('sounds/wrong_buzz.wav');
  static final AudioPlayer _correctDingPlayer = AudioPlayer(playerId: 'correct-ding');
  static final AssetSource _correctDingSound = AssetSource('sounds/correct_ding.wav');

  // Correct-guess victory overlay
  bool _showCorrectGuess = false;
  late final ConfettiController _confettiLeft;
  late final ConfettiController _confettiRight;
  static final AudioPlayer _victoryPlayer = AudioPlayer(playerId: 'victory-fanfare');
  static final AssetSource _victorySound = AssetSource('sounds/victory_fanfare.mp3');

  // Tick sounds — reuse correct_ding at low volume; swap file when dedicated tick.wav is added
  static final AudioPlayer _revealTickPlayer = AudioPlayer(playerId: 'reveal-tick');
  static final AudioPlayer _guessModeTickPlayer = AudioPlayer(playerId: 'guess-tick');
  static final AssetSource _tickSound = AssetSource('sounds/correct_ding.wav');

  // Endgame pressure tracking
  bool _endgamePressureLogged = false;
  int _lastHapticAvailableCount = -1;

  // B8: Prize potential / pressure state logging
  int _lastRevealedCountForLog = -1;
  String? _lastPressureStateForLog;

  // B9: One-shot QA log flags
  bool _finalTileDramaLogged = false;
  bool _spectatorGuessClockLogged = false;
  bool _scoreCliffSignalLogged = false;
  String? _lastDreadStateForLog;

  static Future<void> _primeTickSounds() async {
    try {
      await _revealTickPlayer.setPlayerMode(PlayerMode.lowLatency);
      await _revealTickPlayer.setSource(_tickSound);
      await _guessModeTickPlayer.setPlayerMode(PlayerMode.lowLatency);
      await _guessModeTickPlayer.setSource(_tickSound);
    } catch (_) {}
  }

  static String? _pressureStateKey(double ratio) {
    if (ratio >= 0.92) return 'critical';
    if (ratio >= 0.85) return 'last_chance';
    if (ratio >= 0.75) return 'risk_rising';
    return null;
  }

  static Future<void> _playRevealTick({double volume = 0.07}) async {
    try {
      await _revealTickPlayer.stop();
      await _revealTickPlayer.setVolume(volume);
      await _revealTickPlayer.play(_tickSound);
    } catch (_) {}
  }

  static Future<void> _playGuessModeTick({double volume = 0.17}) async {
    try {
      await _guessModeTickPlayer.stop();
      await _guessModeTickPlayer.setVolume(volume);
      await _guessModeTickPlayer.play(_tickSound);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _confettiLeft = ConfettiController(duration: const Duration(seconds: 2));
    _confettiRight = ConfettiController(duration: const Duration(seconds: 2));
    WidgetsBinding.instance.addObserver(this);
    unawaited(_startBackgroundMusic());
    unawaited(_primeRevealSound());
    unawaited(_primeGuessSounds());
    unawaited(_primeTickSounds());
    final shortId = widget.roomId.substring(0, widget.roomId.length.clamp(0, 6));
    QaLoggerService.instance.log('GAME', 'GAME_INIT roomId=$shortId');
    _startExpiryTimer();
  }

  void _startExpiryTimer() {
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      final room = _latestRoom;
      final uid = _currentUserIdForTimer;
      if (room == null || room.phase != GamePhase.playing) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final totalTiles = room.gridSize * room.gridSize;
      final ratio = totalTiles > 0 ? room.placedPieces.length / totalTiles : 0.0;
      final isEndgame = ratio >= 0.75;

      // Log endgame pressure once per game when threshold crossed
      if (isEndgame && !_endgamePressureLogged) {
        _endgamePressureLogged = true;
        QaLoggerService.instance.log('GAME',
            'ENDGAME_PRESSURE_ACTIVE ratio=${ratio.toStringAsFixed(2)}');
      }

      // Reveal soft tick — last 3s; volume escalates at endgame (+40%)
      if (room.turnPhase == TurnPhase.revealTurn && room.revealDeadlineMs != null) {
        final tickRemaining = room.revealDeadlineMs! - now;
        if (tickRemaining > 0 && tickRemaining <= 3500) {
          unawaited(_playRevealTick(volume: isEndgame ? 0.10 : 0.07));
        }
      }

      // GuessMode stronger tick — last 5s, only for the active guesser; volume +35% at endgame
      if (room.turnPhase == TurnPhase.guessMode &&
          room.guessModeDeadlineMs != null &&
          uid != null &&
          room.guessModePlayerId == uid) {
        final tickRemaining = room.guessModeDeadlineMs! - now;
        if (tickRemaining > 0 && tickRemaining <= 5500) {
          unawaited(_playGuessModeTick(volume: isEndgame ? 0.23 : 0.17));
        }
      }

      // B9: Opponent guess dread state — log transitions during opponent's guessOpportunity
      if (room.turnPhase == TurnPhase.guessOpportunity &&
          uid != null &&
          room.guessOpportunityPlayerId != uid &&
          room.guessOpportunityDeadlineMs != null) {
        final dreadRemaining = room.guessOpportunityDeadlineMs! - now;
        final dreadState = dreadRemaining <= 2000 ? 'final' : dreadRemaining <= 3500 ? 'thinking' : 'normal';
        if (dreadState != _lastDreadStateForLog) {
          _lastDreadStateForLog = dreadState;
          QaLoggerService.instance.log('GAME', 'OPPONENT_GUESS_DREAD_STATE state=$dreadState');
        }
      }

      // Haptic on last 3 reveal tiles remaining — once per count value, revealTurn only
      if (room.turnPhase == TurnPhase.revealTurn) {
        final remaining = room.availablePieceIndices.length;
        if (remaining <= 3 && remaining > 0 && remaining != _lastHapticAvailableCount) {
          _lastHapticAvailableCount = remaining;
          HapticFeedback.lightImpact().ignore();
        }
      }

      // ── Reveal turn timeout ──────────────────────────────────────────────────
      // Owner OR any client when the current turn is virtual/bot may advance.
      // Dedup stamp set ONLY after confirmed commit; 2s cooldown allows retry.
      if (room.turnPhase == TurnPhase.revealTurn &&
          room.revealDeadlineMs != null &&
          now >= room.revealDeadlineMs! &&
          uid != null) {
        final _currentOwner = room.currentTurnUserId;
        final _ownerIsVirtual = _currentOwner != null && _currentOwner.startsWith('virtual_');
        if (_currentOwner == uid || _ownerIsVirtual) {
          if (_lastExpiredRevealDeadline == room.revealDeadlineMs) {
            _dedupSkipCount_reveal++;
            if (_dedupSkipCount_reveal == 1 ||
                (_lastDedupSkipLogMs_reveal != null &&
                    now - _lastDedupSkipLogMs_reveal! >= 30000)) {
              if (_dedupSkipCount_reveal > 1) {
                QaLoggerService.instance.log('TURN',
                    'EXPIRY_DEDUP_SKIP_SUPPRESSED phase=revealTurn deadline=${room.revealDeadlineMs} count=$_dedupSkipCount_reveal');
              } else {
                QaLoggerService.instance.log('TURN',
                    'EXPIRY_DEDUP_SKIP phase=revealTurn deadline=${room.revealDeadlineMs}');
                QaLoggerService.instance.log('TIMER',
                    'TIMER_IGNORED_STALE type=revealTurn deadline=${room.revealDeadlineMs}');
              }
              _lastDedupSkipLogMs_reveal = now;
              _dedupSkipCount_reveal = 0;
            }
          } else {
            final lastAttempt = _revealTimeoutLastAttemptMs;
            if (lastAttempt != null && now - lastAttempt < 2000) {
              // within cooldown — wait for retry window
            } else {
              _revealTimeoutLastAttemptMs = now;
              _sessionTimeoutKeys.add('revealTurn_${room.revealDeadlineMs}');
              if (_ownerIsVirtual) {
                QaLoggerService.instance.log('TURN',
                    'EXPIRE_HANDLER_FIRED phase=revealTurn virtualGuardian=true owner=$_currentOwner');
              } else {
                QaLoggerService.instance.log('TURN', 'EXPIRE_HANDLER_FIRED phase=revealTurn');
              }
              QaLoggerService.instance.log('TIMER', 'TIMER_FIRED type=revealTurn deadline=${room.revealDeadlineMs}');
              QaLoggerService.instance.log('TURN', 'ADVANCE_TURN_REASON reason=reveal_timeout');
              QaLoggerService.instance.log('TURN', 'REVEAL_TIMER_EXPIRED');
              final committed = await ref.read(roomServiceProvider).advanceTurnOnTimeout(
                roomId: room.id,
                userId: uid,
              );
              if (!mounted) return;
              if (committed) {
                _lastExpiredRevealDeadline = room.revealDeadlineMs;
                _dedupSkipCount_reveal = 0;
                _lastDedupSkipLogMs_reveal = null;
              } else {
                QaLoggerService.instance.log('TURN',
                    'EXPIRY_RETRY_ALLOWED phase=revealTurn deadline=${room.revealDeadlineMs}');
              }
            }
          }
        } else if (_lastObservedNotOwnerRevealDeadline != room.revealDeadlineMs) {
          _lastObservedNotOwnerRevealDeadline = room.revealDeadlineMs;
          QaLoggerService.instance.log('TURN',
              'REVEAL_TIMEOUT_OBSERVED_NOT_OWNER deadline=${room.revealDeadlineMs} owner=$_currentOwner observer=$uid');
        }
      }

      // ── Guess opportunity timeout ─────────────────────────────────────────────
      // Any client may call; transaction guards prevent double-execution.
      // Dedup stamp set ONLY after confirmed commit; 2s cooldown allows retry.
      if (room.turnPhase == TurnPhase.guessOpportunity &&
          room.guessOpportunityDeadlineMs != null &&
          now >= room.guessOpportunityDeadlineMs!) {
        if (_lastExpiredGuessOpportunityDeadline == room.guessOpportunityDeadlineMs) {
          _dedupSkipCount_guessOpp++;
          if (_dedupSkipCount_guessOpp == 1 ||
              (_lastDedupSkipLogMs_guessOpp != null &&
                  now - _lastDedupSkipLogMs_guessOpp! >= 30000)) {
            if (_dedupSkipCount_guessOpp > 1) {
              QaLoggerService.instance.log('TURN',
                  'EXPIRY_DEDUP_SKIP_SUPPRESSED phase=guessOpportunity deadline=${room.guessOpportunityDeadlineMs} count=$_dedupSkipCount_guessOpp');
            } else {
              QaLoggerService.instance.log('TURN',
                  'EXPIRY_DEDUP_SKIP phase=guessOpportunity deadline=${room.guessOpportunityDeadlineMs}');
            }
            _lastDedupSkipLogMs_guessOpp = now;
            _dedupSkipCount_guessOpp = 0;
          }
        } else {
          final lastAttempt = _guessOppTimeoutLastAttemptMs;
          if (lastAttempt != null && now - lastAttempt < 2000) {
            // within cooldown — wait for retry window
          } else {
            _guessOppTimeoutLastAttemptMs = now;
            _sessionTimeoutKeys.add('guessOpportunity_${room.guessOpportunityDeadlineMs}');
            QaLoggerService.instance.log('TURN', 'EXPIRE_HANDLER_FIRED phase=guessOpportunity');
            QaLoggerService.instance.log('TIMER', 'TIMER_FIRED type=guessOpportunity deadline=${room.guessOpportunityDeadlineMs}');
            QaLoggerService.instance.log('TURN', 'ADVANCE_TURN_REASON reason=guess_opp_timeout');
            QaLoggerService.instance.log('TURN', 'GUESS_OPPORTUNITY_TIMER_EXPIRED');
            final committed = await ref.read(roomServiceProvider).expireGuessOpportunity(
              roomId: room.id,
            );
            if (!mounted) return;
            if (committed) {
              _lastExpiredGuessOpportunityDeadline = room.guessOpportunityDeadlineMs;
              _dedupSkipCount_guessOpp = 0;
              _lastDedupSkipLogMs_guessOpp = null;
            } else {
              QaLoggerService.instance.log('TURN',
                  'EXPIRY_RETRY_ALLOWED phase=guessOpportunity deadline=${room.guessOpportunityDeadlineMs}');
            }
          }
        }
      }

      // ── Guess mode timeout ────────────────────────────────────────────────────
      // Any client may call; transaction guards prevent double-execution.
      // Dedup stamp set ONLY after confirmed commit; 2s cooldown allows retry.
      if (room.turnPhase == TurnPhase.guessMode &&
          room.guessModeDeadlineMs != null &&
          now >= room.guessModeDeadlineMs!) {
        if (_lastExpiredGuessModeDeadline == room.guessModeDeadlineMs) {
          _dedupSkipCount_guessMode++;
          if (_dedupSkipCount_guessMode == 1 ||
              (_lastDedupSkipLogMs_guessMode != null &&
                  now - _lastDedupSkipLogMs_guessMode! >= 30000)) {
            if (_dedupSkipCount_guessMode > 1) {
              QaLoggerService.instance.log('TURN',
                  'EXPIRY_DEDUP_SKIP_SUPPRESSED phase=guessMode deadline=${room.guessModeDeadlineMs} count=$_dedupSkipCount_guessMode');
            } else {
              QaLoggerService.instance.log('TURN',
                  'EXPIRY_DEDUP_SKIP phase=guessMode deadline=${room.guessModeDeadlineMs}');
            }
            _lastDedupSkipLogMs_guessMode = now;
            _dedupSkipCount_guessMode = 0;
          }
        } else {
          final lastAttempt = _guessModeTimeoutLastAttemptMs;
          if (lastAttempt != null && now - lastAttempt < 2000) {
            // within cooldown — wait for retry window
          } else {
            _guessModeTimeoutLastAttemptMs = now;
            _sessionTimeoutKeys.add('guessMode_${room.guessModeDeadlineMs}');
            QaLoggerService.instance.log('TURN', 'EXPIRE_HANDLER_FIRED phase=guessMode');
            QaLoggerService.instance.log('TIMER', 'TIMER_FIRED type=guessMode deadline=${room.guessModeDeadlineMs}');
            QaLoggerService.instance.log('TURN', 'ADVANCE_TURN_REASON reason=guess_mode_timeout');
            QaLoggerService.instance.log('TURN', 'GUESS_MODE_TIMER_EXPIRED');
            final committed = await ref.read(roomServiceProvider).expireGuessMode(
              roomId: room.id,
            );
            if (!mounted) return;
            if (committed) {
              _lastExpiredGuessModeDeadline = room.guessModeDeadlineMs;
              _dedupSkipCount_guessMode = 0;
              _lastDedupSkipLogMs_guessMode = null;
            } else {
              QaLoggerService.instance.log('TURN',
                  'EXPIRY_RETRY_ALLOWED phase=guessMode deadline=${room.guessModeDeadlineMs}');
            }
          }
        }
      }

      // Snapshot staleness — escalating levels, each logged once per stale period
      final lastSnap = _lastSnapshotMs;
      if (lastSnap != null) {
        final ageMs = now - lastSnap;
        final String? level = ageMs >= 300000
            ? 'severe'
            : ageMs >= 60000
                ? 'critical'
                : ageMs >= 15000
                    ? 'warning'
                    : null;
        if (level == null) {
          _snapshotStaleLevelLogged = null; // fresh — reset for next stale period
        } else {
          const _levels = ['warning', 'critical', 'severe'];
          final prevIdx = _snapshotStaleLevelLogged == null
              ? -1
              : _levels.indexOf(_snapshotStaleLevelLogged!);
          final currIdx = _levels.indexOf(level);
          if (currIdx > prevIdx) {
            QaLoggerService.instance.log('SNAPSHOT',
                'SNAPSHOT_STALE level=$level ageMs=$ageMs');
            _snapshotStaleLevelLogged = level;
            if (level == 'warning' || level == 'critical') {
              _markOffline('snapshot_stale_$level');
            }
          }
        }
      }

      // Watchdog — run every 3 ticks (~3 seconds)
      _watchdogTickCount++;
      if (_watchdogTickCount % 3 == 0) {
        _runWatchdog(room, now);
      }
    });
  }

  void _runWatchdog(RoomModel room, int now) {
    void _clear(bool Function(String) predicate) {
      final toRemove = _watchdogActiveIssues.where(predicate).toList();
      for (final k in toRemove) {
        _watchdogActiveIssues.remove(k);
        _watchdogFirstSeenMs.remove(k);
        _watchdogConfirmedIssues.remove(k);
        QaLoggerService.instance.log('WATCHDOG', 'WATCHDOG_RECOVERED key=$k');
      }
      if (toRemove.isNotEmpty) {
        _attemptAudioRecovery(room);
      }
    }

    void _flag(String key, String log, {String? stuckLog}) {
      if (!_watchdogActiveIssues.contains(key)) {
        _watchdogActiveIssues.add(key);
        _watchdogFirstSeenMs[key] = now;
        _sessionWatchdogEventCount++;
        QaLoggerService.instance.log('WATCHDOG', log);
      } else if (stuckLog != null && !_watchdogConfirmedIssues.contains(key)) {
        final firstSeen = _watchdogFirstSeenMs[key] ?? now;
        if (now - firstSeen >= 10000) {
          _watchdogConfirmedIssues.add(key);
          QaLoggerService.instance.log('WATCHDOG', stuckLog);
        }
      }
    }

    // revealTurn expired deadline
    if (room.turnPhase == TurnPhase.revealTurn && room.revealDeadlineMs != null) {
      final overdue = now - room.revealDeadlineMs!;
      if (overdue > 3000) {
        final key = 'expired_reveal_${room.revealDeadlineMs}';
        _flag(key,
            'WATCHDOG_EXPIRED_DEADLINE phase=revealTurn overdueMs=$overdue',
            stuckLog: 'WATCHDOG_STUCK_CONFIRMED phase=revealTurn overdueMs=$overdue');
      } else {
        _clear((k) => k.startsWith('expired_reveal_'));
      }
    } else {
      _clear((k) => k.startsWith('expired_reveal_'));
    }

    // guessOpportunity expired deadline
    if (room.turnPhase == TurnPhase.guessOpportunity &&
        room.guessOpportunityDeadlineMs != null) {
      final overdue = now - room.guessOpportunityDeadlineMs!;
      if (overdue > 3000) {
        final key = 'expired_guessOpp_${room.guessOpportunityDeadlineMs}';
        _flag(key,
            'WATCHDOG_EXPIRED_DEADLINE phase=guessOpportunity overdueMs=$overdue',
            stuckLog: 'WATCHDOG_STUCK_CONFIRMED phase=guessOpportunity overdueMs=$overdue');
      } else {
        _clear((k) => k.startsWith('expired_guessOpp_'));
      }
    } else {
      _clear((k) => k.startsWith('expired_guessOpp_'));
    }

    // guessMode expired deadline
    if (room.turnPhase == TurnPhase.guessMode && room.guessModeDeadlineMs != null) {
      final overdue = now - room.guessModeDeadlineMs!;
      if (overdue > 3000) {
        final key = 'expired_guessMode_${room.guessModeDeadlineMs}';
        _flag(key,
            'WATCHDOG_EXPIRED_DEADLINE phase=guessMode overdueMs=$overdue',
            stuckLog: 'WATCHDOG_STUCK_CONFIRMED phase=guessMode overdueMs=$overdue');
      } else {
        _clear((k) => k.startsWith('expired_guessMode_'));
      }
    } else {
      _clear((k) => k.startsWith('expired_guessMode_'));
    }

    // playing phase but turnPhase is roundOver (stuck end state)
    if (room.phase == GamePhase.playing && room.turnPhase == TurnPhase.roundOver) {
      _flag('phase_mismatch_playing_roundOver',
          'WATCHDOG_PHASE_MISMATCH phase=playing turnPhase=roundOver',
          stuckLog: 'WATCHDOG_STUCK_CONFIRMED phase=playing turnPhase=roundOver overdueMs=0');
    } else {
      _clear((k) => k == 'phase_mismatch_playing_roundOver');
    }

    // null deadline while phase requires one
    if (room.turnPhase == TurnPhase.revealTurn && room.revealDeadlineMs == null) {
      _flag('null_deadline_revealTurn', 'WATCHDOG_NULL_DEADLINE phase=revealTurn');
    } else {
      _clear((k) => k == 'null_deadline_revealTurn');
    }

    if (room.turnPhase == TurnPhase.guessOpportunity &&
        room.guessOpportunityDeadlineMs == null) {
      _flag('null_deadline_guessOpportunity',
          'WATCHDOG_NULL_DEADLINE phase=guessOpportunity');
    } else {
      _clear((k) => k == 'null_deadline_guessOpportunity');
    }

    if (room.turnPhase == TurnPhase.guessMode && room.guessModeDeadlineMs == null) {
      _flag('null_deadline_guessMode', 'WATCHDOG_NULL_DEADLINE phase=guessMode');
    } else {
      _clear((k) => k == 'null_deadline_guessMode');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _appIsInForeground = false;
      _bgPlayer.stop().ignore();
      _revealSoundPlayer.stop().ignore();
      _wrongBuzzPlayer.stop().ignore();
      _correctDingPlayer.stop().ignore();
      _victoryPlayer.stop().ignore();
      _revealTickPlayer.stop().ignore();
      _guessModeTickPlayer.stop().ignore();
    } else if (state == AppLifecycleState.resumed) {
      _appIsInForeground = true;
    }
  }

  Future<void> _attemptAudioRecovery(RoomModel room) async {
    if (!mounted) {
      QaLoggerService.instance.log('AUDIO', 'AUDIO_RECOVERY_SKIPPED reason=not_mounted');
      return;
    }
    if (room.phase != GamePhase.playing) {
      QaLoggerService.instance.log('AUDIO',
          'AUDIO_RECOVERY_SKIPPED reason=phase_not_playing');
      return;
    }
    if (!_appIsInForeground) {
      QaLoggerService.instance.log('AUDIO',
          'AUDIO_RECOVERY_SKIPPED reason=app_in_background');
      return;
    }
    QaLoggerService.instance.log('AUDIO',
        'AUDIO_RECOVERY_ATTEMPT reason=watchdog_recovered phase=${room.phase.name}');
    try {
      if (_bgPlayer.state == PlayerState.playing) {
        QaLoggerService.instance.log('AUDIO',
            'AUDIO_RECOVERY_SKIPPED reason=already_playing');
        return;
      }
      await _startBackgroundMusic();
      QaLoggerService.instance.log('AUDIO', 'AUDIO_RECOVERY_SUCCESS');
    } catch (e) {
      QaLoggerService.instance.log('AUDIO', 'AUDIO_RECOVERY_SKIPPED reason=error');
    }
  }

  void _markOffline(String reason) {
    if (_isOffline) return;
    _isOffline = true;
    _offlineSinceCycleId = _lastKnownCycleId;
    _offlineSinceTurnPhase = _lastKnownTurnPhase;
    QaLoggerService.instance.log('NETWORK', 'NETWORK_OFFLINE_DETECTED reason=$reason');
    if (mounted) {
      setState(() {});
      QaLoggerService.instance.log('NETWORK', 'OFFLINE_BANNER_SHOWN');
    }
  }

  static bool _isFirestoreUnavailable(Object e) =>
      e.toString().contains('[cloud_firestore/unavailable]');

  @override
  Future<bool> didPopRoute() async {
    if (_lastKnownPhase == GamePhase.playing && mounted) {
      QaLoggerService.instance.log('GAME', 'GAME_SYSTEM_BACK_ATTEMPT');
      _showSystemBackConfirmation(context);
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    final shortId = widget.roomId.substring(0, widget.roomId.length.clamp(0, 6));
    QaLoggerService.instance.log('GAME', 'GAME_DISPOSE roomId=$shortId lastPhase=${_lastKnownPhase?.name ?? 'unknown'}');
    final durationSec = _gameStartTime != null
        ? DateTime.now().difference(_gameStartTime!).inSeconds
        : 0;
    QaLoggerService.instance.log('SESSION',
        'SESSION_SUMMARY'
        ' durationSec=$durationSec'
        ' reveals=$_sessionRevealCount'
        ' timeouts=${_sessionTimeoutKeys.length}'
        ' guessModes=$_sessionGuessModeCount'
        ' wrongGuesses=$_sessionWrongGuessCount'
        ' txErrors=see_service_logs'
        ' watchdogEvents=$_sessionWatchdogEventCount'
        ' unresolvedWatchdogIssues=${_watchdogActiveIssues.length}'
        ' finalPhase=${_lastKnownPhase?.name ?? 'unknown'}'
        ' finalTurnPhase=${_lastKnownTurnPhase?.name ?? 'unknown'}');
    _expiryTimer?.cancel();
    _guessController.dispose();
    _confettiLeft.dispose();
    _confettiRight.dispose();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_bgPlayer.stop());
    super.dispose();
  }

  static Future<void> _playVictorySound() async {
    try {
      await _victoryPlayer.stop();
      await _victoryPlayer.play(_victorySound);
    } catch (_) {}
  }

  Future<void> _loadImage(String imageId) async {
    if (imageId.isEmpty || imageId == _loadedImageId) return;
    _loadedImageId = imageId;
    _nextFactIndex = 0;
    try {
      final image = await ref.read(roomServiceProvider).getImage(imageId);
      if (mounted) setState(() => _image = image);
    } catch (e) {
      debugPrint('Failed to load image: $e');
    }
  }

  Future<void> _humanRevealTile({
    required RoomModel room,
    required String userId,
    required int index,
  }) async {
    if (_isBusy) return;
    if (!room.availablePieceIndices.contains(index)) return;

    final difficulty = room.selectedDifficulty ?? Difficulty.easy;
    final isLastTile = room.availablePieceIndices.length == 1;

    setState(() => _isBusy = true);
    try {
      await ref.read(roomServiceProvider).revealPiece(
            roomId: room.id,
            userId: userId,
            pieceIndex: index,
            difficulty: difficulty,
          );
      unawaited(_playRevealSound());
      if (isLastTile) {
        await ref.read(roomServiceProvider).endGameNoWinner(room.id);
      } else {
        if (mounted) {
          setState(() {
            _hasRevealedThisTurn = true;
            _revealedAtTurnIndex = room.currentTurnIndex;
          });
        }
      }
    } catch (e) {
      if (_isFirestoreUnavailable(e)) _markOffline('firestore_unavailable');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _skipTurn(RoomModel room) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await ref.read(roomServiceProvider).skipPiecePlacement(roomId: room.id);
      if (mounted) setState(() => _hasRevealedThisTurn = false);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _scheduleBotTurn(RoomModel room) {
    // Phase A: handle bot's guess opportunity.
    // After a tile reveal, guessOpportunityPlayerId may point to a bot.
    // Bot may enter guessMode with probability based on reveal ratio, or skip.
    final guessOppId = room.guessOpportunityPlayerId;
    if (room.turnPhase == TurnPhase.guessOpportunity && guessOppId != null) {
      final guessOppPlayer = room.players[guessOppId];
      if (guessOppPlayer != null && guessOppPlayer.isBot) {
        final guessKey = '${room.id}-guess-opp-${room.currentTurnIndex}';
        if (_lastBotTurnKey != guessKey) {
          _lastBotTurnKey = guessKey;
          _scheduleBotGuessOpportunityDecision(room, guessOppId);
        }
      }
      // Human owns guessOpportunity — do not interfere, let timer or human decide.
      return;
    }

    // Phase B: bot reveal turn.
    // Guard: only act during revealTurn to avoid scheduling reveals in guessMode.
    if (room.turnPhase != TurnPhase.revealTurn) return;

    final currentId = room.currentTurnUserId;
    if (currentId == null) return;

    final player = room.players[currentId];
    if (player == null || !player.isBot) return;

    if (room.availablePieceIndices.isEmpty) return;

    final key = '${room.id}-${room.currentTurnIndex}';
    if (_lastBotTurnKey == key) return;
    _lastBotTurnKey = key;

    final botName = player.name.isNotEmpty ? player.name : 'בוט';
    final totalTiles = room.gridSize * room.gridSize;
    final ratio = totalTiles > 0 ? room.placedPieces.length / totalTiles : 0.0;
    final int baseDelayMs;
    if (ratio >= 0.75) {
      baseDelayMs = 400 + _random.nextInt(301);  // 400–700ms — endgame: racing
    } else if (ratio >= 0.50) {
      baseDelayMs = 650 + _random.nextInt(351);  // 650–1000ms — midgame: pressure
    } else {
      baseDelayMs = 1000 + _random.nextInt(601); // 1000–1600ms — early: realistic
    }
    // B8/B9: Reveal hesitation — bot simulates prize-potential anxiety; B9 shows tell text
    int delayMs = baseDelayMs;
    final double hesitationChance = ratio >= 0.75 ? 0.50 : ratio >= 0.50 ? 0.30 : 0.0;
    bool isHesitating = false;
    if (hesitationChance > 0 && _random.nextDouble() < hesitationChance) {
      final extraMs = ratio >= 0.75
          ? 2000 + _random.nextInt(2001)
          : 1500 + _random.nextInt(1001);
      delayMs += extraMs;
      isHesitating = true;
      QaLoggerService.instance.log('BOT',
          'BOT_HESITATION_ACTIVE ratio=${ratio.toStringAsFixed(2)} delay=$delayMs');
    }
    final hesitationText = isHesitating ? (_random.nextBool() ? '...לא בטוח' : '...חושב') : '';
    // Show "opponent thinking" banner — with hesitation text when hesitating
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _showBotTyping = true;
        _botTypingName = botName;
        _botTypingText = hesitationText;
      });
      if (isHesitating) {
        QaLoggerService.instance.log('BOT', 'BOT_HESITATION_TELL_VISIBLE text=$hesitationText');
      }
    });
    Future.delayed(Duration(milliseconds: delayMs), () async {
      if (!mounted) return;
      final snapshot = await ref.read(roomServiceProvider).watchRoom(room.id).first;
      if (snapshot == null) return;
      if (snapshot.phase == GamePhase.finished) return;
      if (snapshot.currentTurnUserId != currentId) return;
      if (snapshot.availablePieceIndices.isEmpty) return;

      final idx = snapshot.availablePieceIndices[
          _random.nextInt(snapshot.availablePieceIndices.length)];
      final isLastTile = snapshot.availablePieceIndices.length == 1;
      final difficulty = snapshot.selectedDifficulty ?? Difficulty.easy;

      await ref.read(roomServiceProvider).revealPiece(
            roomId: snapshot.id,
            userId: currentId,
            pieceIndex: idx,
            difficulty: difficulty,
          );
      unawaited(_playRevealSound());

      if (mounted) setState(() => _showBotTyping = false);

      if (isLastTile) {
        if (mounted) {
          await ref.read(roomServiceProvider).endGameNoWinner(snapshot.id);
        }
        return;
      }

      // After bot reveals, guessOpportunity goes to the next player.
      // _scheduleBotTurn handles the next state from the Firestore stream.
    });
  }

  void _scheduleBotGuessOpportunityDecision(RoomModel room, String botId) {
    final totalTiles = room.gridSize * room.gridSize;
    final revealedCount = room.placedPieces.length;
    final ratio = totalTiles > 0 ? revealedCount / totalTiles : 0.0;

    // Probability that bot attempts to guess based on how much is revealed
    final double guessChance;
    if (ratio <= 0.20) {
      guessChance = 0.05;
    } else if (ratio <= 0.40) {
      guessChance = 0.12;
    } else if (ratio <= 0.60) {
      guessChance = 0.22;
    } else if (ratio <= 0.80) {
      guessChance = 0.35;
    } else {
      guessChance = 0.50;
    }

    // B7: endgame escalation at ratio≥0.75; B8: super-endgame aggression at ratio≥0.85
    final isEndgameBotMode = ratio >= 0.75;
    final isSuperEndgame = ratio >= 0.85;

    final double effectiveGuessChance;
    if (isSuperEndgame) {
      effectiveGuessChance = (guessChance * 2.0).clamp(0.0, 0.90);
    } else if (isEndgameBotMode) {
      effectiveGuessChance = 1.0 - (1.0 - guessChance) * 0.5;
    } else {
      effectiveGuessChance = guessChance;
    }

    final double delayMultiplier;
    if (isSuperEndgame) {
      delayMultiplier = 0.60; // B7 ×0.75 then B8 ×0.80
    } else if (isEndgameBotMode) {
      delayMultiplier = 0.75;
    } else {
      delayMultiplier = 1.0;
    }

    if (isSuperEndgame) {
      QaLoggerService.instance.log('BOT',
          'BOT_ENDGAME_AGGRESSION ratio=${ratio.toStringAsFixed(2)}');
    }

    final decides = _random.nextDouble() < effectiveGuessChance;
    QaLoggerService.instance.log('BOT',
        'BOT_GUESS_DECISION ratio=${ratio.toStringAsFixed(2)} chance=${effectiveGuessChance.toStringAsFixed(2)} decided=$decides endgame=$isEndgameBotMode super=$isSuperEndgame');

    if (!decides) {
      // Bot skips — human-like pause before yielding opportunity
      final skipDelayMs = ((1800 + _random.nextInt(1801)) * delayMultiplier).round();
      QaLoggerService.instance.log('BOT',
          'BOT_DELAY_SCHEDULED action=skip_guess_opportunity ms=$skipDelayMs');
      Future.delayed(Duration(milliseconds: skipDelayMs), () async {
        if (!mounted) return;
        QaLoggerService.instance.log('BOT', 'BOT_SKIP_GUESS_OPPORTUNITY');
        QaLoggerService.instance.log('TURN',
            'ADVANCE_TURN_REASON reason=bot_skip phase=guessOpportunity');
        await ref.read(roomServiceProvider).skipPiecePlacement(roomId: room.id);
      });
      return;
    }

    // Bot decided to enter guessMode — pause first, then enter
    final enterDelayMs = ((1800 + _random.nextInt(1801)) * delayMultiplier).round();
    QaLoggerService.instance.log('BOT',
        'BOT_DELAY_SCHEDULED action=enter_guess_mode ms=$enterDelayMs');

    Future.delayed(Duration(milliseconds: enterDelayMs), () async {
      if (!mounted) return;
      // Re-read before entering to confirm opportunity is still ours
      final snap = await ref.read(roomServiceProvider).watchRoom(room.id).first;
      if (snap == null) return;
      if (snap.phase == GamePhase.finished) return;
      if (snap.turnPhase != TurnPhase.guessOpportunity) return;
      if (snap.guessOpportunityPlayerId != botId) return;

      final entered = await ref.read(roomServiceProvider).enterGuessMode(
            roomId: room.id, userId: botId);
      if (!entered) return;

      QaLoggerService.instance.log('BOT', 'BOT_ENTER_GUESS_MODE');

      // Wait human-like time before submitting
      final submitDelayMs = ((3000 + _random.nextInt(5001)) * delayMultiplier).round();
      QaLoggerService.instance.log('BOT',
          'BOT_DELAY_SCHEDULED action=submit_guess ms=$submitDelayMs');

      await Future.delayed(Duration(milliseconds: submitDelayMs));
      if (!mounted) return;

      // Confirm guessMode is still ours before submitting
      final snap2 = await ref.read(roomServiceProvider).watchRoom(room.id).first;
      if (snap2 == null) return;
      if (snap2.phase == GamePhase.finished) return;
      if (snap2.turnPhase != TurnPhase.guessMode) return;
      if (snap2.guessModePlayerId != botId) return;

      // Correct guess: ≥60% revealed → 20% base; 75%+ → 35%; 85%+ → 45%
      final double correctChance = ratio >= 0.60
          ? (isSuperEndgame ? 0.45 : isEndgameBotMode ? 0.35 : 0.20)
          : 0.0;
      await _performBotGuess(snap2, botId, correctChance);
    });
  }

  Future<void> _simulateBotTyping(String botName, String word) async {
    if (!mounted) return;
    setState(() {
      _showBotTyping = true;
      _botTypingName = botName;
      _botTypingText = '';
    });

    await Future.delayed(Duration(milliseconds: 1200 + _random.nextInt(801)));

    for (int i = 1; i <= word.length; i++) {
      if (!mounted) return;
      setState(() => _botTypingText = word.substring(0, i));
      await Future.delayed(Duration(milliseconds: 220 + _random.nextInt(121)));
    }

    await Future.delayed(const Duration(milliseconds: 350));
  }

  Future<void> _performBotGuess(RoomModel room, String botId, double correctChance) async {
    final image = _image;
    if (image == null) return;

    final isCorrect = _random.nextDouble() < correctChance;
    final guess = isCorrect ? image.answer : _realisticWrongGuess(image.answer);

    QaLoggerService.instance.log('BOT', 'BOT_SUBMIT_GUESS correct=$isCorrect');

    final botName = room.players[botId]?.name ?? 'בוט';
    await _simulateBotTyping(botName, guess);

    if (!mounted) return;
    setState(() => _showBotTyping = false);

    await ref.read(roomServiceProvider).submitAnswer(
          roomId: room.id,
          userId: botId,
          guess: guess,
          image: image,
          difficulty: room.selectedDifficulty ?? Difficulty.easy,
        );
  }

  static const _realisticGuessPool = [
    'מצדה',
    'הכותל',
    'ים המלח',
    'אילת',
    'החרמון',
    'קיסריה',
    'עכו',
    'יפו',
    'מכתש רמון',
    'הגנים הבהאיים',
    'נהריה',
    'בית שאן',
    'ראש הנקרה',
    'חיפה',
    'הכנרת',
  ];

  String _realisticWrongGuess(String correctAnswer) {
    final norm = normalizeHebrewFinals(correctAnswer.trim());
    final candidates = _realisticGuessPool
        .where((g) => normalizeHebrewFinals(g) != norm)
        .toList();
    if (candidates.isEmpty) return 'מצדה';
    return candidates[_random.nextInt(candidates.length)];
  }

  Future<void> _triggerMatchReward(RoomModel room, String? uid) async {
    if (_rewardApplied || uid == null) return;
    _rewardApplied = true;

    final isWin = room.winnerId == uid;
    final isSolo = room.players.values.where((p) => !p.isBot).length == 1;
    final timeTaken = _gameStartTime != null
        ? DateTime.now().difference(_gameStartTime!)
        : const Duration(seconds: 999);
    final totalTilesCount = room.gridSize * room.gridSize;

    try {
      final breakdown = await ref.read(economyServiceProvider).applyMatchReward(
            uid: uid,
            isWin: isWin,
            isSolo: isSolo,
            tilesRevealedCount: room.placedPieces.length,
            totalTilesCount: totalTilesCount,
            wrongGuessCount: 0,
            timeTaken: timeTaken,
            roomId: room.id,
            imageId: _image?.id,
          );
      if (mounted) setState(() => _rewardBreakdown = breakdown);
    } catch (e) {
      debugPrint('Economy reward error: $e');
    }
  }

  Future<void> _useRevealHint(RoomModel room, String userId) async {
    final isSolo = room.players.values.where((p) => !p.isBot).length == 1;
    if (!isSolo) return; // multiplayer: blocked

    final wallet = ref.read(walletProvider).valueOrNull;
    if (wallet == null) return;

    final guard = ref.read(hintEconomyGuardProvider);
    if (!guard.canAfford(wallet, HintType.revealTile)) return;

    final granted = await guard.useHint(
      uid: userId,
      hint: HintType.revealTile,
      wallet: wallet,
      roomId: room.id,
    );

    if (!granted || !mounted) return;

    final facts = _image?.facts ?? const [];
    if (facts.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => const _FactDialog(fact: null),
      );
      return;
    }

    final fact = facts[_nextFactIndex % facts.length];
    _nextFactIndex++;

    showDialog(
      context: context,
      builder: (_) => _FactDialog(fact: fact),
    );
  }

  Future<bool> _submitGuess(RoomModel room, String userId, String value) async {
    final image = _image;
    if (image == null || value.trim().isEmpty) return false;

    // Stop tick sounds immediately on submission
    _revealTickPlayer.stop().ignore();
    _guessModeTickPlayer.stop().ignore();

    setState(() => _hasGuessedThisTurn = true);

    final bool correct;
    try {
      correct = await ref.read(roomServiceProvider).submitAnswer(
            roomId: room.id,
            userId: userId,
            guess: value.trim(),
            image: image,
            difficulty: room.selectedDifficulty ?? Difficulty.easy,
          );
    } catch (e) {
      if (_isFirestoreUnavailable(e)) _markOffline('firestore_unavailable');
      return false;
    }

    if (!mounted) return correct;
    if (correct) {
      setState(() => _showCorrectGuess = true);
      _confettiLeft.play();
      _confettiRight.play();
      unawaited(_playVictorySound());
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _showCorrectGuess = false);
      });
    }
    // Wrong guess: LetterBankInput shows its own inline error feedback
    return correct;
  }

  Future<void> _enterGuessMode(RoomModel room, String userId) async {
    QaLoggerService.instance.log('GUESS', 'GUESS_BUTTON_TAPPED phase=${room.turnPhase.name}');

    final alreadyInGuessMode = room.turnPhase == TurnPhase.guessMode &&
        room.guessModePlayerId == userId;
    if (alreadyInGuessMode) return;

    try {
      final entered = await ref.read(roomServiceProvider).enterGuessMode(
        roomId: room.id,
        userId: userId,
      );
      if (!entered) {
        QaLoggerService.instance.log('GUESS', 'ENTER_GUESS_MODE_REJECTED phase=${room.turnPhase.name}');
        return;
      }
      QaLoggerService.instance.log('GUESS', 'ENTER_GUESS_MODE_SUCCESS');
    } catch (e) {
      if (_isFirestoreUnavailable(e)) _markOffline('firestore_unavailable');
    }
    // Inline UI shows automatically via Firestore state stream
  }

  Future<void> _showExitConfirmation(BuildContext context) async {
    QaLoggerService.instance.log('GAME', 'GAME_BACK_CONFIRM_SHOWN');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF07101F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.12)),
          ),
          title: const Text(
            'לעזוב את המשחק?',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'המשחק עדיין פעיל. אם תצא עכשיו, תחזור למסך הבית.',
            style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                QaLoggerService.instance.log('GAME', 'GAME_BACK_CONFIRM_CANCELLED');
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'המשך משחק',
                style: TextStyle(color: Color(0xFF8B6FFF), fontWeight: FontWeight.w900),
              ),
            ),
            TextButton(
              onPressed: () {
                QaLoggerService.instance.log('GAME', 'GAME_BACK_CONFIRM_ACCEPTED');
                QaLoggerService.instance.log('GAME', 'GAME_NAV_HOME reason=back_confirmed phase=playing');
                Navigator.pop(dialogContext);
                context.go('/home');
              },
              child: const Text(
                'עזוב משחק',
                style: TextStyle(color: Color(0xFFFF6B35), fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSystemBackConfirmation(BuildContext context) async {
    QaLoggerService.instance.log('GAME', 'GAME_SYSTEM_BACK_CONFIRM_SHOWN');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF07101F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.12)),
          ),
          title: const Text(
            'לעזוב את המשחק?',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'המשחק עדיין פעיל. אם תצא עכשיו, תחזור למסך הבית.',
            style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                QaLoggerService.instance.log('GAME', 'GAME_SYSTEM_BACK_CONFIRM_CANCELLED');
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'המשך משחק',
                style: TextStyle(color: Color(0xFF8B6FFF), fontWeight: FontWeight.w900),
              ),
            ),
            TextButton(
              onPressed: () {
                QaLoggerService.instance.log('GAME', 'GAME_SYSTEM_BACK_CONFIRM_ACCEPTED');
                QaLoggerService.instance.log('GAME', 'GAME_NAV_HOME reason=system_back_confirmed phase=playing');
                Navigator.pop(dialogContext);
                context.go('/home');
              },
              child: const Text(
                'עזוב משחק',
                style: TextStyle(color: Color(0xFFFF6B35), fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));
    final user = ref.watch(currentUserProvider).value;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppStyles.navyTop,
        body: Stack(
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: AppStyles.backgroundGradient,
              ),
              child: SafeArea(
                top: false,
                child: roomAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF8B6FFF)),
              ),
              error: (e, _) {
                final msg = e.toString();
                QaLoggerService.instance.log('GAME', 'GAME_ERROR e=${msg.length > 80 ? msg.substring(0, 80) : msg}');
                return Center(
                  child: Text('שגיאה: $e', style: const TextStyle(color: Colors.white70)),
                );
              },
              data: (room) {
                if (room == null) {
                  final shortId = widget.roomId.substring(0, widget.roomId.length.clamp(0, 6));
                  QaLoggerService.instance.log('GAME', 'GAME_ROOM_NULL_OR_MISSING roomId=$shortId lastPhase=${_lastKnownPhase?.name ?? 'unknown'}');
                  QaLoggerService.instance.log('GAME', 'GAME_NAV_HOME reason=room_null_or_deleted');
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) context.go('/home');
                  });
                  return const SizedBox.shrink();
                }

                final currentUserId = user?.id;

                if (!_gameScreenLogged) {
                  _gameScreenLogged = true;
                  final shortId = room.id.substring(0, room.id.length.clamp(0, 6));
                  QaLoggerService.instance.log('GAME', 'GAME_SCREEN_OPENED code=${room.code} id=$shortId players=${room.players.length} phase=${room.phase.name} turnPhase=${room.turnPhase.name}');
                }
                if (!_gameDataLogged) {
                  _gameDataLogged = true;
                  final turnName = room.players[room.currentTurnUserId]?.name ?? room.currentTurnUserId?.substring(0, (room.currentTurnUserId ?? '').length.clamp(0, 6)) ?? 'none';
                  QaLoggerService.instance.log('GAME', 'GAME_ROOM_DATA phase=${room.phase.name} turnPhase=${room.turnPhase.name} turn=$turnName revealed=${room.placedPieces.length}');
                }

                if (_lastKnownPhase != null && _lastKnownPhase != room.phase) {
                  QaLoggerService.instance.log('GAME', 'GAME_PHASE_CHANGED from=${_lastKnownPhase!.name} to=${room.phase.name}');
                }
                _lastKnownPhase = room.phase;

                // TurnPhase change detection — fires on every stream update after first
                // Suppress stale phase changes when game is already finished
                if (_lastKnownTurnPhase != null && _lastKnownTurnPhase != room.turnPhase &&
                    room.phase != GamePhase.finished) {
                  QaLoggerService.instance.log('TURN', 'TURN_PHASE_CHANGED from=${_lastKnownTurnPhase!.name} to=${room.turnPhase.name}');

                  if (room.turnPhase == TurnPhase.guessOpportunity) {
                    final oppId = room.guessOpportunityPlayerId ?? 'null';
                    final shortOppId = oppId.length > 6 ? oppId.substring(0, 6) : oppId;
                    final msLeft = room.guessOpportunityDeadlineMs != null
                        ? room.guessOpportunityDeadlineMs! - DateTime.now().millisecondsSinceEpoch
                        : -1;
                    QaLoggerService.instance.log('TURN', 'GUESS_OPPORTUNITY_STARTED oppId=$shortOppId msLeft=$msLeft');
                    if (currentUserId != null && room.guessOpportunityPlayerId == currentUserId) {
                      QaLoggerService.instance.log('GUESS', 'GUESS_BUTTON_VISIBLE msLeft=$msLeft');
                    }
                  }

                  if (room.turnPhase == TurnPhase.guessMode) {
                    final guesserId = room.guessModePlayerId ?? 'null';
                    final shortGuesserId = guesserId.length > 6 ? guesserId.substring(0, 6) : guesserId;
                    final msLeft = room.guessModeDeadlineMs != null
                        ? room.guessModeDeadlineMs! - DateTime.now().millisecondsSinceEpoch
                        : -1;
                    QaLoggerService.instance.log('TURN', 'GUESS_MODE_STARTED guesserId=$shortGuesserId msLeft=$msLeft');
                    // Reveal expiry timer is frozen while in guessMode — log once on entry.
                    QaLoggerService.instance.log('TURN', 'REVEAL_TIMER_FROZEN phase=guessMode');
                    QaLoggerService.instance.log('TURN', 'BOARD_DIMMED_GUESS_MODE');
                    QaLoggerService.instance.log('TURN', 'REVEAL_BAR_HIDDEN_GUESS_MODE');
                    HapticFeedback.mediumImpact().ignore();
                    if (currentUserId != null && room.guessModePlayerId == currentUserId) {
                      QaLoggerService.instance.log('GUESS', 'GUESS_MODE_UI_ENTER');
                    }
                  }

                  if (_lastKnownTurnPhase == TurnPhase.guessMode && room.turnPhase != TurnPhase.guessMode) {
                    QaLoggerService.instance.log('GUESS', 'GUESS_MODE_UI_EXIT');
                    _revealTickPlayer.stop().ignore();
                    _guessModeTickPlayer.stop().ignore();
                  }

                  if (room.turnPhase == TurnPhase.revealTurn) {
                    final turnId = room.currentTurnUserId ?? 'null';
                    final shortTurnId = turnId.length > 6 ? turnId.substring(0, 6) : turnId;
                    final msLeft = room.revealDeadlineMs != null
                        ? room.revealDeadlineMs! - DateTime.now().millisecondsSinceEpoch
                        : -1;
                    QaLoggerService.instance.log('TURN', 'REVEAL_DEADLINE_SET turnId=$shortTurnId msLeft=$msLeft');
                  }
                }
                // First stream delivery after game start: log initial revealDeadlineMs
                if (_lastKnownRevealDeadlineMs == null && room.revealDeadlineMs != null) {
                  final turnId = room.currentTurnUserId ?? 'null';
                  final shortTurnId = turnId.length > 6 ? turnId.substring(0, 6) : turnId;
                  final msLeft = room.revealDeadlineMs! - DateTime.now().millisecondsSinceEpoch;
                  QaLoggerService.instance.log('TURN', 'REVEAL_DEADLINE_SET turnId=$shortTurnId msLeft=$msLeft');
                  _lastKnownRevealDeadlineMs = room.revealDeadlineMs;
                }
                final _prevTurnPhaseForCounter = _lastKnownTurnPhase;
                _lastKnownTurnPhase = room.turnPhase;

                // ── Snapshot freshness ──────────────────────────────────────────────
                final _snapNow = DateTime.now().millisecondsSinceEpoch;
                _lastSnapshotMs = _snapNow;
                if (_isOffline) {
                  final _cycleAdvanced = _offlineSinceCycleId != null &&
                      room.revealCycleId != _offlineSinceCycleId;
                  final _turnPhaseChanged = _offlineSinceTurnPhase != null &&
                      room.turnPhase != _offlineSinceTurnPhase;
                  if (_cycleAdvanced || _turnPhaseChanged) {
                    _isOffline = false;
                    _offlineSinceCycleId = null;
                    _offlineSinceTurnPhase = null;
                    _showRecoveredBanner = true;
                    QaLoggerService.instance.log('NETWORK', 'NETWORK_RECOVERY_DETECTED');
                    QaLoggerService.instance.log('NETWORK', 'OFFLINE_BANNER_HIDDEN');
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) setState(() => _showRecoveredBanner = false);
                      });
                    });
                  }
                }
                _snapshotStaleLevelLogged = null; // new snapshot resets stale escalation
                if (_lastSnapshotLogCycleId != room.revealCycleId ||
                    _lastKnownPhase != room.phase) {
                  _lastSnapshotLogCycleId = room.revealCycleId;
                  QaLoggerService.instance.log('SNAPSHOT',
                      'SNAPSHOT_RECEIVED phase=${room.phase.name} turnPhase=${room.turnPhase.name} cycle=${room.revealCycleId}');
                }

                // ── Cycle integrity ─────────────────────────────────────────────────
                final _prevCycle = _lastKnownCycleId;
                if (_prevCycle != null && room.revealCycleId != _prevCycle) {
                  final jump = room.revealCycleId - _prevCycle;
                  if (jump > 1) {
                    QaLoggerService.instance.log('SNAPSHOT',
                        'CYCLE_GAP_DETECTED from=$_prevCycle to=${room.revealCycleId}');
                  } else if (jump < 0) {
                    QaLoggerService.instance.log('SNAPSHOT',
                        'CYCLE_DUPLICATE_DETECTED cycle=${room.revealCycleId}');
                  } else {
                    QaLoggerService.instance.log('SNAPSHOT',
                        'CYCLE_ADVANCED from=$_prevCycle to=${room.revealCycleId}');
                  }
                }
                _lastKnownCycleId = room.revealCycleId;

                // ── Timer lifecycle — reveal deadline ───────────────────────────────
                if (room.revealDeadlineMs != null &&
                    room.revealDeadlineMs != _lastKnownRevealDeadlineMs) {
                  if (_lastKnownRevealDeadlineMs == null) {
                    QaLoggerService.instance.log('TIMER',
                        'TIMER_CREATED type=revealTurn deadline=${room.revealDeadlineMs}');
                  } else {
                    QaLoggerService.instance.log('TIMER',
                        'TIMER_REPLACED type=revealTurn oldDeadline=$_lastKnownRevealDeadlineMs newDeadline=${room.revealDeadlineMs}');
                  }
                  _lastKnownRevealDeadlineMs = room.revealDeadlineMs;
                }

                // ── Timer lifecycle — guessOpportunity deadline ─────────────────────
                if (room.guessOpportunityDeadlineMs != _lastKnownGuessOpportunityDeadlineMs) {
                  if (room.guessOpportunityDeadlineMs != null) {
                    if (_lastKnownGuessOpportunityDeadlineMs == null) {
                      QaLoggerService.instance.log('TIMER',
                          'TIMER_CREATED type=guessOpportunity deadline=${room.guessOpportunityDeadlineMs}');
                    } else {
                      QaLoggerService.instance.log('TIMER',
                          'TIMER_REPLACED type=guessOpportunity oldDeadline=$_lastKnownGuessOpportunityDeadlineMs newDeadline=${room.guessOpportunityDeadlineMs}');
                    }
                  }
                  _lastKnownGuessOpportunityDeadlineMs = room.guessOpportunityDeadlineMs;
                }

                // ── Timer lifecycle — guessMode deadline ────────────────────────────
                if (room.guessModeDeadlineMs != _lastKnownGuessModeDeadlineMs) {
                  if (room.guessModeDeadlineMs != null) {
                    if (_lastKnownGuessModeDeadlineMs == null) {
                      QaLoggerService.instance.log('TIMER',
                          'TIMER_CREATED type=guessMode deadline=${room.guessModeDeadlineMs}');
                    } else {
                      QaLoggerService.instance.log('TIMER',
                          'TIMER_REPLACED type=guessMode oldDeadline=$_lastKnownGuessModeDeadlineMs newDeadline=${room.guessModeDeadlineMs}');
                    }
                  }
                  _lastKnownGuessModeDeadlineMs = room.guessModeDeadlineMs;
                }

                // ── Session counters ────────────────────────────────────────────────
                if (_prevTurnPhaseForCounter != null &&
                    _prevTurnPhaseForCounter != room.turnPhase) {
                  if (room.turnPhase == TurnPhase.revealTurn) _sessionRevealCount++;
                  if (room.turnPhase == TurnPhase.guessMode) _sessionGuessModeCount++;
                }
                // Detect wrong guesses from lastGuessEvent changes
                final _guessEventCorrect =
                    room.lastGuessEvent?['isCorrect'] as bool?;
                if (_guessEventCorrect == false &&
                    _lastGuessEventCorrect != false) {
                  _sessionWrongGuessCount++;
                }
                _lastGuessEventCorrect = _guessEventCorrect;

                if (room.imageId.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _loadImage(room.imageId));
                }

                // Capture game-start time the first frame phase becomes 'playing'
                if (room.phase == GamePhase.playing && _gameStartTime == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _gameStartTime == null) {
                      _gameStartTime = DateTime.now();
                    }
                  });
                }

                if (room.phase == GamePhase.finished) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _triggerMatchReward(room, currentUserId);
                  });
                  final hasWinner = room.winnerId != null && room.winnerId!.isNotEmpty;
                  if (hasWinner) {
                    final rawName = room.players[room.winnerId]?.name ?? '';
                    final winnerName = rawName.isEmpty ? 'שחקן' : rawName;
                    return GameWinnerView(
                      winnerName: winnerName,
                      placeName: _image?.name,
                      rewardBreakdown: _rewardBreakdown,
                      onHome: () {
                        QaLoggerService.instance.log('GAME', 'GAME_RETURN_HOME phase=finished_winner');
                        context.go('/home');
                      },
                    );
                  }
                  return _NoWinnerView(
                    answer: _image?.answer ?? '',
                    imageUrl: _image?.imageUrl,
                    onHome: () {
                      QaLoggerService.instance.log('GAME', 'GAME_RETURN_HOME phase=finished_no_winner');
                      context.go('/home');
                    },
                  );
                }

                // Cache room + userId for the expiry timer (no setState needed)
                _latestRoom = room;
                _currentUserIdForTimer = currentUserId;

                // Prize potential and pressure state QA logging
                if (room.phase == GamePhase.playing) {
                  final _pTotal = room.gridSize * room.gridSize;
                  final _pRatio = _pTotal > 0 ? room.placedPieces.length / _pTotal : 0.0;
                  if (room.placedPieces.length != _lastRevealedCountForLog) {
                    _lastRevealedCountForLog = room.placedPieces.length;
                    final _isSoloLog = room.players.values.where((p) => !p.isBot).length == 1;
                    final _coinsLog = RewardCalculator.calculateCurrentPrizePotential(
                      isSolo: _isSoloLog,
                      revealedCount: room.placedPieces.length,
                      totalTiles: _pTotal,
                    );
                    QaLoggerService.instance.log('GAME',
                        'PRIZE_POTENTIAL_DISPLAY coins=$_coinsLog revealed=${room.placedPieces.length} total=$_pTotal isSolo=$_isSoloLog');
                  }
                  final _pState = _pressureStateKey(_pRatio);
                  if (_pState != null && _pState != _lastPressureStateForLog) {
                    _lastPressureStateForLog = _pState;
                    QaLoggerService.instance.log('GAME', 'PRESSURE_STATE_CHANGED state=$_pState');
                  }
                }

                _scheduleBotTurn(room);
                _syncMusicVolume(room);

                if (room.currentTurnIndex != _revealedAtTurnIndex &&
                    (_hasRevealedThisTurn || _hasGuessedThisTurn)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _hasRevealedThisTurn = false;
                        _hasGuessedThisTurn = false;
                      });
                    }
                  });
                }

                if (room.guessCount != _lastShownGuessCount && room.lastGuessEvent != null) {
                  _lastShownGuessCount = room.guessCount;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    final event = room.lastGuessEvent!;
                    final isCorrect = event['isCorrect'] as bool? ?? false;
                    final isLocalGuess = (event['playerId'] as String?) == currentUserId;
                    setState(() {
                      _currentBanner = event;
                      _showBanner = true;
                      _showBotTyping = false;
                    });
                    if (isCorrect && !isLocalGuess) {
                      unawaited(_playCorrectDing());
                    } else if (!isCorrect) {
                      unawaited(_playWrongBuzz());
                    }
                    Future.delayed(const Duration(milliseconds: 1800), () {
                      if (mounted) setState(() => _showBanner = false);
                    });
                  });
                }

                final _isFinished = room.phase == GamePhase.finished;
                // isMyTurn: it's my reveal turn (revealTurn phase, I'm the current turn player)
                final isMyTurn = !_isFinished &&
                    currentUserId != null &&
                    room.currentTurnUserId == currentUserId &&
                    room.turnPhase == TurnPhase.revealTurn;
                // canGuessNow: I have the guess opportunity window
                final canGuessNow = !_isFinished &&
                    currentUserId != null &&
                    room.turnPhase == TurnPhase.guessOpportunity &&
                    room.guessOpportunityPlayerId == currentUserId;
                final isSolo = room.players.values.where((p) => !p.isBot).length == 1;
                final _totalTiles = room.gridSize * room.gridSize;
                final revealRatio = _totalTiles > 0 ? room.placedPieces.length / _totalTiles : 0.0;

                // B9: One-shot QA logs
                if (room.phase == GamePhase.playing) {
                  if (!_finalTileDramaLogged && room.availablePieceIndices.length == 1) {
                    _finalTileDramaLogged = true;
                    QaLoggerService.instance.log('GAME', 'FINAL_TILE_DRAMA_ACTIVE');
                  }
                  final _b9GuessModeActive = room.turnPhase == TurnPhase.guessMode;
                  final _b9IsMyGuessMode = currentUserId != null && room.guessModePlayerId == currentUserId;
                  if (!_spectatorGuessClockLogged && _b9GuessModeActive && !_b9IsMyGuessMode) {
                    _spectatorGuessClockLogged = true;
                    QaLoggerService.instance.log('GAME', 'SPECTATOR_GUESS_CLOCK_VISIBLE');
                  }
                  if (!_scoreCliffSignalLogged && canGuessNow) {
                    final _b9MyScore = currentUserId != null ? (room.players[currentUserId]?.score ?? 0) : 0;
                    final _b9LeaderScore = room.sortedPlayers.isNotEmpty ? room.sortedPlayers.first.score : 0;
                    if ((_b9LeaderScore - _b9MyScore) <= 1) {
                      _scoreCliffSignalLogged = true;
                      QaLoggerService.instance.log('GAME', 'SCORE_CLIFF_SIGNAL_VISIBLE');
                    }
                  }
                }

                return GameLayout(
                  room: room,
                  image: _image,
                  currentUserId: currentUserId,
                  isMyTurn: isMyTurn,
                  isBusy: _isBusy,
                  canGuessNow: canGuessNow,
                  isSolo: isSolo,
                  revealRatio: revealRatio,
                  showBanner: _showBanner,
                  bannerEvent: _currentBanner,
                  showBotTyping: _showBotTyping,
                  botTypingName: _botTypingName,
                  botTypingText: _botTypingText,
                  onBack: () {
                    QaLoggerService.instance.log('GAME', 'GAME_BACK_BUTTON_TAPPED');
                    if (room.phase == GamePhase.playing) {
                      _showExitConfirmation(context);
                    } else {
                      QaLoggerService.instance.log('GAME', 'GAME_NAV_HOME reason=back_button phase=${room.phase.name}');
                      context.go('/home');
                    }
                  },
                  onReveal: currentUserId == null
                      ? null
                      : (index) => _humanRevealTile(
                            room: room,
                            userId: currentUserId,
                            index: index,
                          ),
                  onRevealHint: currentUserId == null
                      ? null
                      : () => _useRevealHint(room, currentUserId),
                  onGuess: canGuessNow ? () => _enterGuessMode(room, currentUserId!) : null,
                  onGuessSubmit: (currentUserId != null &&
                          room.turnPhase == TurnPhase.guessMode &&
                          room.guessModePlayerId == currentUserId)
                      ? (value) => _submitGuess(room, currentUserId!, value)
                      : null,
                  onSkip: canGuessNow ? () => _skipTurn(room) : null,
                );
              },
            ),
          ),
            ),
            if (_showCorrectGuess) ...[
              Align(
                alignment: Alignment.topLeft,
                child: ConfettiWidget(
                  confettiController: _confettiLeft,
                  blastDirection: -pi / 4,
                  colors: const [Color(0xFF00F2FF), Color(0xFFFFE14D), Colors.white],
                  numberOfParticles: 22,
                  gravity: 0.18,
                  shouldLoop: false,
                ),
              ),
              Align(
                alignment: Alignment.topRight,
                child: ConfettiWidget(
                  confettiController: _confettiRight,
                  blastDirection: -3 * pi / 4,
                  colors: const [Color(0xFF00F2FF), Color(0xFFFFE14D), Colors.white],
                  numberOfParticles: 22,
                  gravity: 0.18,
                  shouldLoop: false,
                ),
              ),
              Center(
                child: IgnorePointer(
                  child: Text(
                    'ניחוש נכון! ✨',
                    textAlign: TextAlign.center,
                    style: AppStyles.heading1.copyWith(
                      fontSize: 48,
                      shadows: [
                        Shadow(color: AppStyles.cyanGlow, blurRadius: 30),
                        Shadow(
                          color: AppStyles.cyanGlow.withOpacity(0.5),
                          blurRadius: 60,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (_isOffline || _showRecoveredBanner)
              Positioned(
                top: MediaQuery.of(context).padding.top + 4,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _showRecoveredBanner
                            ? const Color(0xFF0D3B26).withOpacity(0.95)
                            : const Color(0xFF1A0A00).withOpacity(0.92),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _showRecoveredBanner
                              ? const Color(0xFF00C853).withOpacity(0.7)
                              : const Color(0xFFFF6B35).withOpacity(0.7),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _showRecoveredBanner
                            ? 'החיבור חזר'
                            : 'אין חיבור · מנסה להתחבר…',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoWinnerView extends StatefulWidget {
  final String answer;
  final String? imageUrl;
  final VoidCallback onHome;

  const _NoWinnerView({
    required this.answer,
    required this.imageUrl,
    required this.onHome,
  });

  @override
  State<_NoWinnerView> createState() => _NoWinnerViewState();
}

class _NoWinnerViewState extends State<_NoWinnerView> {
  bool _overlayVisible = false;
  bool _line1Visible = false;
  bool _line2Visible = false;
  bool _line3Visible = false;
  double _imageScale = 1.0;

  @override
  void initState() {
    super.initState();
    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _overlayVisible = true;
      _imageScale = 1.05;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _line1Visible = true);

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _line2Visible = true);

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _line3Visible = true);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imgSize = min(
          constraints.maxWidth - 32,
          min(constraints.maxHeight * 0.58, 280.0),
        );
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.imageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox.square(
                          dimension: imgSize,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              AnimatedScale(
                                scale: _imageScale,
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOut,
                                child: widget.imageUrl!.startsWith('assets/')
                                    ? Image.asset(widget.imageUrl!, fit: BoxFit.cover)
                                    : CachedNetworkImage(
                                        imageUrl: widget.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => const _ImageFallback(),
                                      ),
                              ),
                              AnimatedOpacity(
                                opacity: _overlayVisible ? 0.4 : 0.0,
                                duration: const Duration(milliseconds: 400),
                                child: const ColoredBox(color: Colors.black),
                              ),
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedOpacity(
                                        opacity: _line1Visible ? 1.0 : 0.0,
                                        duration: const Duration(milliseconds: 300),
                                        child: const Text(
                                          'אף אחד לא ניחש בזמן',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                            shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      AnimatedOpacity(
                                        opacity: _line2Visible ? 1.0 : 0.0,
                                        duration: const Duration(milliseconds: 300),
                                        child: const Text(
                                          'התשובה היא...',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      AnimatedOpacity(
                                        opacity: _line3Visible ? 1.0 : 0.0,
                                        duration: const Duration(milliseconds: 300),
                                        child: Text(
                                          widget.answer,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Color(0xFF9B7EFF),
                                            fontSize: 26,
                                            fontWeight: FontWeight.w900,
                                            shadows: [Shadow(color: Colors.black87, blurRadius: 12)],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      AnimatedOpacity(
                        opacity: _line1Visible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: const Text(
                          'אף אחד לא ניחש בזמן',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedOpacity(
                        opacity: _line2Visible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: const Text(
                          'התשובה היא...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedOpacity(
                        opacity: _line3Visible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          widget.answer,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF9B7EFF),
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 180,
                      child: FilledButton(
                        onPressed: widget.onHome,
                        child: const Text('משחק חדש'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FactDialog extends StatelessWidget {
  final String? fact;
  const _FactDialog({required this.fact});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF07101F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.5)),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      title: const Row(
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF87CEEB), size: 20),
          SizedBox(width: 8),
          Text(
            'רמז',
            style: TextStyle(
              color: Color(0xFF87CEEB),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      content: Text(
        fact ?? 'אין רמז זמין למקום הזה',
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          color: fact != null ? Colors.white : Colors.white54,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.55,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'הבנתי',
            style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A3E),
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.white24,
          size: 48,
        ),
      ),
    );
  }
}
