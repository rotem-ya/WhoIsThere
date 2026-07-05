import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/game_constants.dart';
import '../../core/theme/app_styles.dart';
import '../../core/utils/letters_matcher.dart';
import '../../models/game_image_model.dart';
import '../../models/room_model.dart';
import '../../providers/providers.dart';
import '../../services/analytics_service.dart';
import '../../services/review_prompt_service.dart';
import '../../services/settings_service.dart';
import '../../services/sfx_service.dart';

/// The letters game (משחק האותיות) — a Wordle-style image-reveal duel.
/// Turn-based 1v1: on your turn you place a letter into a slot. A correct
/// letter (green) reveals 4 image tiles on *your* board, a present-elsewhere
/// letter (yellow) reveals 2, a miss reveals none. First to fill every slot
/// wins. Each player sees only their own revealed tiles.
class LettersGameScreen extends ConsumerStatefulWidget {
  final String roomId;
  const LettersGameScreen({super.key, required this.roomId});

  @override
  ConsumerState<LettersGameScreen> createState() => _LettersGameScreenState();
}

// Hebrew keyboard layout (matches the letter bank's key set): all base letters,
// the five final forms, and a geresh key (') for words like ג'ירפה.
const List<List<String>> _kKeyboardRows = [
  ['פ', 'ם', 'ן', 'ו', 'ט', 'א', 'ר', 'ק'],
  ['ף', 'ך', 'ל', 'ח', 'י', 'ע', 'כ', 'ג', 'ד', 'ש'],
  ['ץ', 'ת', 'צ', 'מ', 'נ', 'ה', 'ב', 'ס', 'ז', "'"],
];

const Color _kGold = Color(0xFFD4AF37);
const Color _kGoldLight = Color(0xFFFFE082);
const Color _kGreen = Color(0xFF3DCC7A);
const Color _kYellow = Color(0xFFE0A93D);
const Color _kAbsent = Color(0xFF3A4A5E);

class _LettersGameScreenState extends ConsumerState<LettersGameScreen> {
  GameImageModel? _image;
  String? _loadingImageId;
  int? _selectedSlot; // null → auto-target the first empty slot
  bool _submitting = false;
  String? _lastBotTurnKey;
  bool _winSoundPlayed = false;
  bool _startTriggered = false;
  bool _rematchBusy = false;
  bool _startLogged = false;
  Timer? _randomFallbackTimer;

  static final AudioPlayer _bgPlayer = AudioPlayer(playerId: 'letters-bg');
  static final AssetSource _bgMusic = AssetSource('sounds/background_studio.mp3');
  late final ConfettiController _confetti;

  String? get _myUid => ref.read(firebaseUserProvider).valueOrNull?.uid;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _startMusic();
  }

  Future<void> _startMusic() async {
    try {
      final vol = SettingsService.instance.musicVolume;
      await _bgPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgPlayer.setVolume(0.44 * vol);
      await _bgPlayer.play(_bgMusic);
    } catch (_) {
      // Audio is non-critical.
    }
  }

  /// Navigating /letters/A → /letters/B ("play again") reuses this State —
  /// the GoRoute page key is per-route, not per-roomId — so every per-room
  /// flag must be reset here or the new duel inherits stale state (e.g.
  /// _startTriggered=true would block the rematch room from ever starting).
  @override
  void didUpdateWidget(covariant LettersGameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId == widget.roomId) return;
    _randomFallbackTimer?.cancel();
    _randomFallbackTimer = null;
    _image = null;
    _loadingImageId = null;
    _selectedSlot = null;
    _submitting = false;
    _lastBotTurnKey = null;
    _winSoundPlayed = false;
    _startTriggered = false;
    _startLogged = false;
    _startMusic(); // the finished overlay stopped the bg music
  }

  @override
  void dispose() {
    _confetti.dispose();
    _randomFallbackTimer?.cancel();
    _bgPlayer.stop();
    super.dispose();
  }

  /// Host-only: start the duel once a 2nd player is present. For a random
  /// (public) room, fall back to a bot after a short search so nobody waits
  /// forever.
  void _maybeAutoStart(RoomModel room) {
    final uid = _myUid;
    if (uid == null || uid != room.hostId || _startTriggered) return;

    if (room.players.length >= 2) {
      _startTriggered = true;
      _randomFallbackTimer?.cancel();
      ref.read(roomServiceProvider).startLettersGame(widget.roomId);
      return;
    }
    if (room.isPublicRoom && _randomFallbackTimer == null) {
      _randomFallbackTimer = Timer(const Duration(seconds: 8), () {
        final live = ref.read(roomStreamProvider(widget.roomId)).valueOrNull;
        if (!mounted || live == null || live.phase != GamePhase.waiting) return;
        _startTriggered = true;
        ref
            .read(roomServiceProvider)
            .startLettersGame(widget.roomId, addBotIfAlone: true);
      });
    }
  }

  void _playVsBotNow() {
    if (_startTriggered) return;
    _startTriggered = true;
    _randomFallbackTimer?.cancel();
    ref
        .read(roomServiceProvider)
        .startLettersGame(widget.roomId, addBotIfAlone: true);
  }

  Future<void> _ensureImage(String? imageId) async {
    if (imageId == null || imageId.isEmpty) return;
    if (_image?.id == imageId || _loadingImageId == imageId) return;
    _loadingImageId = imageId;
    final img = await ref.read(roomServiceProvider).getImage(imageId);
    if (!mounted) return;
    setState(() {
      _image = img;
      _loadingImageId = null;
    });
  }

  int _firstEmptySlot(LettersPuzzle puzzle, Set<int> solved) {
    for (var i = 0; i < puzzle.length; i++) {
      if (!solved.contains(i)) return i;
    }
    return 0;
  }

  Future<void> _guess(RoomModel room, LettersPuzzle puzzle, String letter) async {
    final uid = _myUid;
    if (uid == null || _submitting) return;
    final solved = (room.lettersSolvedSlots[uid] ?? const []).toSet();
    final slot = (_selectedSlot != null && !solved.contains(_selectedSlot))
        ? _selectedSlot!
        : _firstEmptySlot(puzzle, solved);

    setState(() => _submitting = true);
    HapticFeedback.lightImpact();
    final res = await ref.read(roomServiceProvider).guessLetterInLettersGame(
          roomId: widget.roomId,
          userId: uid,
          slotIndex: slot,
          letter: letter,
        );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _selectedSlot = null;
    });
    if (!res.accepted) return;
    // Feedback sounds for my own board.
    if (res.win) {
      // win fanfare handled by the finished overlay
    } else if (res.feedback == LetterFeedback.exact) {
      SfxService.instance.letterCorrect();
      SfxService.instance.reveal();
    } else if (res.feedback == LetterFeedback.present) {
      SfxService.instance.reveal();
    } else {
      SfxService.instance.letterWrong();
    }
  }

  /// Host-only: drive the bot's turn. Picks the first empty slot and, with some
  /// skill, plays the correct letter there; otherwise probes a random unused
  /// letter (which may turn out present or absent).
  void _maybeScheduleBotTurn(RoomModel room, LettersPuzzle puzzle) {
    final uid = _myUid;
    if (uid == null || uid != room.hostId) return;
    final turnUid = room.currentTurnUserId;
    if (turnUid == null || !turnUid.startsWith('virtual_')) return;
    if (room.phase != GamePhase.playing) return;

    final key = '${room.currentTurnIndex}-$turnUid';
    if (_lastBotTurnKey == key) return;
    _lastBotTurnKey = key;

    // Deliberate "thinking" pace so the duel reads clearly as turn-by-turn.
    final delayMs = 2500 + math.Random().nextInt(1500); // 2.5–4.0s
    Future.delayed(Duration(milliseconds: delayMs), () async {
      if (!mounted) return;
      final live = ref.read(roomStreamProvider(widget.roomId)).valueOrNull;
      if (live == null ||
          live.phase != GamePhase.playing ||
          live.currentTurnUserId != turnUid) {
        return;
      }
      final solved = (live.lettersSolvedSlots[turnUid] ?? const []).toSet();
      final guessed = (live.lettersGuessed[turnUid] ?? const []).toSet();
      final slot = _firstEmptySlot(puzzle, solved);

      final rng = math.Random();
      String letter;
      if (rng.nextDouble() < 0.5 && slot < puzzle.length) {
        letter = puzzle.matchChars[slot]; // bot "knows" this slot
      } else {
        final pool = [
          for (final row in _kKeyboardRows)
            for (final k in row)
              if (!guessed.contains(k)) k
        ];
        letter = pool.isEmpty
            ? puzzle.matchChars[slot]
            : pool[rng.nextInt(pool.length)];
      }
      await ref.read(roomServiceProvider).guessLetterInLettersGame(
            roomId: widget.roomId,
            userId: turnUid,
            slotIndex: slot,
            letter: letter,
          );
    });
  }

  /// "Play again". Solo (vs bot): spin up a fresh bot duel immediately.
  /// Vs a human: rematch via [RoomModel.rematchRoomId] — the first tapper
  /// creates a private letters room and stamps its id on the finished room;
  /// the opponent's button flips to "join rematch" via the room stream, so
  /// both land in the SAME new room instead of two separate empty ones.
  Future<void> _playAgain(RoomModel room) async {
    if (_rematchBusy) return;
    final uid = _myUid;
    final me = ref.read(currentUserProvider).valueOrNull;
    if (uid == null || me == null) {
      if (mounted) context.go('/home');
      return;
    }
    setState(() => _rematchBusy = true);
    final svc = ref.read(roomServiceProvider);
    try {
      final vsHuman =
          room.players.values.any((p) => !p.isBot && p.id != uid);
      if (!vsHuman) {
        final newRoom = await svc.createLettersRoom(
          hostId: me.id,
          hostName: me.name,
          hostPhotoUrl: me.photoUrl,
        );
        if (mounted) context.go('/letters/${newRoom.id}');
        return;
      }

      var targetId = room.rematchRoomId;
      if (targetId == null || targetId.isEmpty) {
        targetId = await svc.createLettersRematch(
          oldRoomId: room.id,
          hostId: me.id,
          hostName: me.name,
          hostPhotoUrl: me.photoUrl,
        );
      }
      // Join whatever room won the rematch slot (no-op for its creator).
      // Null means the rematch already started without us or is gone.
      RoomModel? joined;
      if (targetId != null && targetId.isNotEmpty) {
        joined = await svc.joinRematch(
          rematchRoomId: targetId,
          userId: me.id,
          userName: me.name,
          userPhotoUrl: me.photoUrl,
        );
      }
      if (!mounted) return;
      if (joined == null || targetId == null || targetId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('המשחק החוזר כבר התחיל או שאינו זמין')),
        );
        return;
      }
      context.go('/letters/$targetId');
    } finally {
      if (mounted) setState(() => _rematchBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppStyles.navyTop,
        body: Container(
          decoration: const BoxDecoration(gradient: AppStyles.backgroundGradient),
          child: SafeArea(
            child: roomAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: _kGold)),
              error: (e, _) => Center(
                child: Text('שגיאה: $e',
                    style: const TextStyle(color: Colors.white70)),
              ),
              data: (room) {
                if (room == null) {
                  return const Center(
                      child: Text('החדר לא נמצא',
                          style: TextStyle(color: Colors.white70)));
                }
                // Resolve the secret image lazily.
                WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _ensureImage(room.selectedImageId));

                final word = room.secretWord ?? '';
                final puzzle = buildLettersPuzzle(word);

                if (room.phase == GamePhase.finished) {
                  return _buildFinished(room, puzzle);
                }

                if (room.phase == GamePhase.waiting) {
                  _maybeAutoStart(room);
                  return _buildWaiting(room);
                }

                if (!_startLogged) {
                  _startLogged = true;
                  AnalyticsService.instance.gameStart(
                    mode: 'letters',
                    solo: room.players.values.any((p) => p.isBot),
                  );
                }
                _maybeScheduleBotTurn(room, puzzle);
                return _buildPlaying(room, puzzle);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaying(RoomModel room, LettersPuzzle puzzle) {
    final uid = _myUid ?? '';
    final mySolved = (room.lettersSolvedSlots[uid] ?? const []).toSet();
    final myGuessed = (room.lettersGuessed[uid] ?? const []).toSet();
    final myRevealed = (room.lettersRevealedTiles[uid] ?? const []);
    final isMyTurn = room.currentTurnUserId == uid;

    // Opponent (the other player in the turn order).
    final oppId = room.turnOrder.firstWhere((id) => id != uid, orElse: () => '');
    final opp = room.players[oppId];
    final oppSolved = (room.lettersSolvedSlots[oppId] ?? const []).length;
    final oppRevealed = (room.lettersRevealedTiles[oppId] ?? const []);

    final activeSlot = (_selectedSlot != null && !mySolved.contains(_selectedSlot))
        ? _selectedSlot
        : _firstEmptySlot(puzzle, mySolved);

    return Column(
      children: [
        _Header(
          isMyTurn: isMyTurn,
          mySolved: mySolved.length,
          total: puzzle.length,
          oppName: opp?.name ?? 'יריב',
          oppSolved: oppSolved,
          onClose: () => context.go('/home'),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                const SizedBox(height: 6),
                Expanded(
                  child: _FrostedBoard(
                    gridSize: kLettersGridSize,
                    imageUrl: _image?.imageUrl,
                    myRevealed: myRevealed,
                    oppRevealed: oppRevealed,
                  ),
                ),
                const SizedBox(height: 10),
                _Slots(
                  puzzle: puzzle,
                  solved: mySolved,
                  activeSlot: isMyTurn ? activeSlot : null,
                  onTapSlot: isMyTurn
                      ? (i) {
                          if (mySolved.contains(i)) return;
                          HapticFeedback.selectionClick();
                          setState(() => _selectedSlot = i);
                        }
                      : null,
                ),
                const SizedBox(height: 12),
                _Keyboard(
                  enabled: isMyTurn && !_submitting,
                  puzzle: puzzle,
                  solved: mySolved,
                  guessed: myGuessed,
                  onLetter: (l) => _guess(room, puzzle, l),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaiting(RoomModel room) {
    final uid = _myUid ?? '';
    final isHost = uid == room.hostId;
    final isRandom = room.isPublicRoom;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('משחק האותיות',
                style: TextStyle(
                    color: _kGoldLight, fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 18),
            if (isRandom) ...[
              const CircularProgressIndicator(color: _kGold),
              const SizedBox(height: 20),
              const Text('מחפש יריב…',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('מחברים אותך למשחק…',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
            ] else if (isHost) ...[
              const Text('הזמינו חבר',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              const Text('קוד החדר',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: room.code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('הקוד הועתק'), duration: Duration(seconds: 2)),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF07101F),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kGold.withOpacity(0.6), width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(room.code,
                          style: const TextStyle(
                              color: _kGoldLight,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 6)),
                      const SizedBox(width: 10),
                      Icon(Icons.copy_rounded, color: _kGold.withOpacity(0.8), size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text('שתפו את הקוד עם חבר כדי לשחק יחד',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: _kGold),
              const SizedBox(height: 12),
              const Text('ממתין לחבר…',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 18),
              TextButton(
                onPressed: _playVsBotNow,
                child: const Text('התחל משחק עכשיו',
                    style: TextStyle(color: _kGoldLight, fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ] else ...[
              const CircularProgressIndicator(color: _kGold),
              const SizedBox(height: 18),
              const Text('ממתין שהמשחק יתחיל…',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            ],
            const SizedBox(height: 26),
            TextButton(
              onPressed: () => context.go('/home'),
              child: const Text('חזרה לבית',
                  style: TextStyle(color: Colors.white54, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinished(RoomModel room, LettersPuzzle puzzle) {
    final uid = _myUid ?? '';
    final iWon = room.winnerId == uid;
    final winner = room.players[room.winnerId];
    if (!_winSoundPlayed) {
      _winSoundPlayed = true;
      _bgPlayer.stop();
      SfxService.instance.win();
      if (iWon) {
        _confetti.play();
        // A win is the best moment to (rarely) ask for a store rating.
        unawaited(ReviewPromptService.instance.onGameWon());
        final oppIsBot = room.players.values
            .any((p) => p.isBot && p.id != (_myUid ?? ''));
        AnalyticsService.instance.gameWin(mode: 'letters', solo: oppIsBot);
      }
    }
    final url = _image?.imageUrl;
    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 22,
            maxBlastForce: 22,
            minBlastForce: 8,
            gravity: 0.25,
            colors: const [_kGold, _kGoldLight, _kGreen, AppStyles.cyanGlow],
          ),
        ),
        Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              iWon ? '🏆 ניצחת!' : 'הפסדת',
              style: TextStyle(
                color: iWon ? _kGoldLight : Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              iWon ? 'השלמת את המילה ראשון' : '${winner?.name ?? "היריב"} השלים ראשון',
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 18),
            if (url != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: url.startsWith('assets/')
                      ? Image.asset(url, fit: BoxFit.cover)
                      : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
                ),
              ),
            const SizedBox(height: 14),
            Text(
              room.secretWord ?? '',
              style: const TextStyle(
                color: _kGoldLight,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _rematchBusy ? null : () => _playAgain(room),
                style: FilledButton.styleFrom(
                  backgroundColor: _kGold,
                  foregroundColor: const Color(0xFF07101F),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                child: Text(
                    (room.rematchRoomId != null && room.rematchRoomId!.isNotEmpty)
                        ? 'הצטרף למשחק חוזר'
                        : 'שחק שוב'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => context.go('/home'),
              child: const Text('חזרה לבית',
                  style: TextStyle(color: Colors.white70, fontSize: 16)),
            ),
          ],
        ),
      ),
        ),
      ],
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool isMyTurn;
  final int mySolved;
  final int total;
  final String oppName;
  final int oppSolved;
  final VoidCallback onClose;

  const _Header({
    required this.isMyTurn,
    required this.mySolved,
    required this.total,
    required this.oppName,
    required this.oppSolved,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  isMyTurn ? 'תורך — בחר אות' : 'תור $oppName',
                  style: TextStyle(
                    color: isMyTurn ? _kGoldLight : Colors.white60,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'אתה $mySolved/$total · $oppName $oppSolved/$total',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ── Answer slots ────────────────────────────────────────────────────────────

class _Slots extends StatelessWidget {
  final LettersPuzzle puzzle;
  final Set<int> solved;
  final int? activeSlot;
  final void Function(int)? onTapSlot;

  const _Slots({
    required this.puzzle,
    required this.solved,
    required this.activeSlot,
    required this.onTapSlot,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const slotGap = 6.0;
      const wordGap = 16.0;
      final total = math.max(1, puzzle.length);
      final wordCount = math.max(1, puzzle.wordLengths.length);
      final gaps = slotGap * (total - wordCount) + wordGap * (wordCount - 1);
      final size =
          math.min(46.0, math.max(26.0, (c.maxWidth - 8 - gaps) / total));
      var idx = 0;
      final words = <Widget>[];
      for (final len in puzzle.wordLengths) {
        final slots = <Widget>[];
        for (var i = 0; i < len; i++) {
          if (i > 0) slots.add(const SizedBox(width: slotGap));
          final slotIndex = idx;
          final isSolved = solved.contains(slotIndex);
          final isActive = slotIndex == activeSlot;
          slots.add(GestureDetector(
            onTap: onTapSlot == null ? null : () => onTapSlot!(slotIndex),
            child: _SlotBox(
              letter: isSolved ? puzzle.displayChars[slotIndex] : null,
              size: size,
              active: isActive,
            ),
          ));
          idx++;
        }
        words.add(Row(
            textDirection: TextDirection.rtl,
            mainAxisSize: MainAxisSize.min,
            children: slots));
      }
      return Wrap(
        textDirection: TextDirection.rtl,
        alignment: WrapAlignment.center,
        spacing: wordGap,
        runSpacing: 8,
        children: words,
      );
    });
  }
}

class _SlotBox extends StatelessWidget {
  final String? letter;
  final double size;
  final bool active;

  const _SlotBox({required this.letter, required this.size, required this.active});

  @override
  Widget build(BuildContext context) {
    final filled = letter != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: filled
            ? const LinearGradient(
                colors: [_kGoldLight, _kGold, Color(0xFFA1811A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : null,
        color: filled ? null : const Color(0xFF07101F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? AppStyles.cyanGlow
              : filled
                  ? _kGoldLight
                  : _kGold.withOpacity(0.55),
          width: active ? 2.6 : (filled ? 2.2 : 1.5),
        ),
        boxShadow: active
            ? [BoxShadow(color: AppStyles.cyanGlow.withOpacity(0.5), blurRadius: 12)]
            : null,
      ),
      child: Text(
        letter ?? '',
        style: TextStyle(
          color: const Color(0xFF07101F),
          fontSize: math.max(16, size * 0.58),
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

// ── Keyboard ────────────────────────────────────────────────────────────────

class _Keyboard extends StatelessWidget {
  final bool enabled;
  final LettersPuzzle puzzle;
  final Set<int> solved;
  final Set<String> guessed;
  final ValueChanged<String> onLetter;

  const _Keyboard({
    required this.enabled,
    required this.puzzle,
    required this.solved,
    required this.guessed,
    required this.onLetter,
  });

  Color _colorFor(KeyStatus s) {
    switch (s) {
      case KeyStatus.solved:
        return _kGreen;
      case KeyStatus.present:
        return _kYellow;
      case KeyStatus.absent:
        return _kAbsent;
      case KeyStatus.neutral:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 4.0;
      const maxKeys = 10;
      final keySize =
          math.min(42.0, math.max(24.0, (c.maxWidth - gap * (maxKeys - 1)) / maxKeys));
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < _kKeyboardRows.length; r++) ...[
            Row(
              textDirection: TextDirection.rtl,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final letter in _kKeyboardRows[r])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _Key(
                      label: letter,
                      size: keySize,
                      enabled: enabled,
                      color: _colorFor(
                          keyStatusFor(puzzle, letter, solved, guessed)),
                      onTap: () => onLetter(letter),
                    ),
                  ),
              ],
            ),
            if (r != _kKeyboardRows.length - 1) const SizedBox(height: 7),
          ],
        ],
      );
    });
  }
}

class _Key extends StatelessWidget {
  final String label;
  final double size;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  const _Key({
    required this.label,
    required this.size,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = color == Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(11),
        child: Ink(
          width: size,
          height: size + 10,
          decoration: BoxDecoration(
            color: enabled ? color : color.withOpacity(0.45),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _kGold.withOpacity(0.45), width: 1.2),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: dark ? const Color(0xFF07101F) : Colors.white,
                fontSize: math.max(18, size * 0.56),
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Frosted-glass board ─────────────────────────────────────────────────────
//
// One blurred copy of the secret image is the "frosted glass" base (you see
// vague colours but no detail). Tiles YOU revealed punch through to a sharp
// slice; tiles the OPPONENT revealed (that you haven't) tint to frosted red
// glass — your only window into how close they are. Newly revealed tiles pop in.
class _FrostedBoard extends StatelessWidget {
  final int gridSize;
  final String? imageUrl;
  final List<int> myRevealed;
  final List<int> oppRevealed;

  const _FrostedBoard({
    required this.gridSize,
    required this.imageUrl,
    required this.myRevealed,
    required this.oppRevealed,
  });

  Widget _fullImage(double side) {
    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return Container(color: const Color(0xFF0A1A2E));
    }
    return url.startsWith('assets/')
        ? Image.asset(url, width: side, height: side, fit: BoxFit.cover)
        : CachedNetworkImage(
            imageUrl: url,
            width: side,
            height: side,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(color: const Color(0xFF0A1A2E)),
          );
  }

  Widget _sharpSlice(int index, double side, double tileSize) {
    final row = index ~/ gridSize;
    final col = index % gridSize;
    final x = gridSize <= 1 ? 0.0 : (col / (gridSize - 1)) * 2.0 - 1.0;
    final y = gridSize <= 1 ? 0.0 : (row / (gridSize - 1)) * 2.0 - 1.0;
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment(x, y),
        minWidth: side,
        maxWidth: side,
        minHeight: side,
        maxHeight: side,
        child: _fullImage(side),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mySet = myRevealed.toSet();
    final oppOnly = oppRevealed.toSet().difference(mySet);

    return LayoutBuilder(builder: (context, c) {
      final side = math.min(c.maxWidth, c.maxHeight);
      final tile = side / gridSize;

      return Center(
        child: Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppStyles.cyanGlow.withOpacity(0.30), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              children: [
                // Frosted base: heavily blurred image + cool glass tint.
                Positioned.fill(
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: _fullImage(side),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.14),
                          Colors.white.withOpacity(0.05),
                          const Color(0xFF0A1A2E).withOpacity(0.22),
                        ],
                      ),
                    ),
                  ),
                ),
                // Opponent-only tiles → frosted red glass.
                for (final idx in oppOnly)
                  Positioned(
                    key: ValueKey('o$idx'),
                    left: (idx % gridSize) * tile,
                    top: (idx ~/ gridSize) * tile,
                    width: tile,
                    height: tile,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 360),
                      builder: (_, t, __) => DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFFFF5A5A).withOpacity(0.42 * t),
                              const Color(0xFFB81E1E).withOpacity(0.30 * t),
                            ],
                          ),
                          border: Border.all(
                            color: const Color(0xFFFF8A8A).withOpacity(0.45 * t),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                // My revealed tiles → sharp image, popping in.
                for (final idx in mySet)
                  Positioned(
                    key: ValueKey('m$idx'),
                    left: (idx % gridSize) * tile,
                    top: (idx ~/ gridSize) * tile,
                    width: tile,
                    height: tile,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutBack,
                      builder: (_, t, child) => Opacity(
                        opacity: t.clamp(0.0, 1.0),
                        child: Transform.scale(scale: 0.7 + 0.3 * t, child: child),
                      ),
                      child: _sharpSlice(idx, side, tile),
                    ),
                  ),
                // Glass grid lines on top so every tile reads as a glass pane.
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _GridPainter(gridSize)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _GridPainter extends CustomPainter {
  final int gridSize;
  const _GridPainter(this.gridSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..strokeWidth = 1;
    final tw = size.width / gridSize;
    final th = size.height / gridSize;
    for (var i = 1; i < gridSize; i++) {
      canvas.drawLine(Offset(tw * i, 0), Offset(tw * i, size.height), paint);
      canvas.drawLine(Offset(0, th * i), Offset(size.width, th * i), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.gridSize != gridSize;
}
