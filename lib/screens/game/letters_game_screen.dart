import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
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
import '../../services/sfx_service.dart';
import 'widgets/game_board_view.dart';

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

// Hebrew keyboard layout (matches the letter bank's key set).
const List<List<String>> _kKeyboardRows = [
  ['פ', 'ם', 'ן', 'ו', 'ט', 'א', 'ר', 'ק'],
  ['ף', 'ך', 'ל', 'ח', 'י', 'ע', 'כ', 'ג', 'ד', 'ש'],
  ['ץ', 'ת', 'צ', 'מ', 'נ', 'ה', 'ב', 'ס', 'ז'],
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

  String? get _myUid => ref.read(firebaseUserProvider).valueOrNull?.uid;

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

    Future.delayed(const Duration(milliseconds: 1200), () async {
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

  Future<void> _playAgain() async {
    final uid = _myUid;
    final me = ref.read(currentUserProvider).valueOrNull;
    if (uid == null || me == null) {
      if (mounted) context.go('/home');
      return;
    }
    final room = await ref.read(roomServiceProvider).createLettersRoom(
          hostId: me.id,
          hostName: me.name,
          hostPhotoUrl: me.photoUrl,
        );
    if (mounted) context.go('/letters/${room.id}');
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

    final gridSize = room.selectedDifficulty?.gridSize ?? 6;
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
                  child: GameBoardView(
                    gridSize: gridSize,
                    revealedCells: myRevealed,
                    availableCells: const [],
                    imageUrl: _image?.imageUrl,
                    enabled: false,
                    glowEnabled: false,
                    onReveal: null,
                    cardSkinId: room.cardSkinId,
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

  Widget _buildFinished(RoomModel room, LettersPuzzle puzzle) {
    final uid = _myUid ?? '';
    final iWon = room.winnerId == uid;
    final winner = room.players[room.winnerId];
    if (!_winSoundPlayed) {
      _winSoundPlayed = true;
      SfxService.instance.win();
    }
    final url = _image?.imageUrl;
    return Center(
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
                onPressed: _playAgain,
                style: FilledButton.styleFrom(
                  backgroundColor: _kGold,
                  foregroundColor: const Color(0xFF07101F),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                child: const Text('שחק שוב'),
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
