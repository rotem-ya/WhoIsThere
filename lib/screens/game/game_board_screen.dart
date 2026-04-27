import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/game_constants.dart';
import '../../providers/providers.dart';
import '../../models/room_model.dart';
import '../../models/game_image_model.dart';
import '../../widgets/common/player_avatar.dart';
import '../../widgets/common/score_badge.dart';

class GameBoardScreen extends ConsumerStatefulWidget {
  final String roomId;

  const GameBoardScreen({super.key, required this.roomId});

  @override
  ConsumerState<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends ConsumerState<GameBoardScreen> {
  bool _hasFlipped = false;
  bool _hasGuessedLetter = false;
  bool _hasGuessed = false;
  bool _isActing = false;
  GameImageModel? _gameImage;
  bool _imageLoadStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadImage());
  }

  Future<void> _loadImage() async {
    if (_imageLoadStarted) return;
    _imageLoadStarted = true;
    try {
      final room = await ref.read(roomStreamProvider(widget.roomId).future);
      if (room?.selectedImageId == null) return;
      final img =
          await ref.read(roomServiceProvider).getImage(room!.selectedImageId!);
      if (mounted) setState(() => _gameImage = img);
    } catch (e) {
      debugPrint('Failed to load game image: $e');
    }
  }

  String _actingUserId(RoomModel room) {
    final user = ref.read(currentUserProvider).value;
    return room.currentTurnUserId ?? user?.id ?? '';
  }

  Future<void> _flipPiece(int pieceIndex, RoomModel room) async {
    if (_hasFlipped || _isActing) return;
    final difficulty = room.selectedDifficulty!;
    setState(() => _isActing = true);

    try {
      await ref.read(roomServiceProvider).revealPiece(
            roomId: widget.roomId,
            userId: _actingUserId(room),
            pieceIndex: pieceIndex,
            difficulty: difficulty,
          );
      if (mounted) {
        setState(() {
          _hasFlipped = true;
          _isActing = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _endTurn() async {
    if (_isActing) return;
    setState(() => _isActing = true);
    try {
      await ref
          .read(roomServiceProvider)
          .skipPiecePlacement(roomId: widget.roomId);
    } finally {
      if (mounted) {
        setState(() {
          _isActing = false;
          _hasFlipped = false;
          _hasGuessedLetter = false;
          _hasGuessed = false;
        });
      }
    }
  }

  void _showLetterGuessDialog(RoomModel room) {
    if (_hasGuessedLetter || _isActing) return;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          '🔤 נחש אות!',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'אות שגויה: -${room.selectedDifficulty?.wrongGuessPenalty ?? 2} נקודות',
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 1,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
              decoration: const InputDecoration(
                hintText: '?',
                counterText: '',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) {
                  Navigator.pop(ctx);
                  _submitLetterGuess(v.trim(), room);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () {
              final letter = controller.text.trim();
              if (letter.isNotEmpty) {
                Navigator.pop(ctx);
                _submitLetterGuess(letter, room);
              }
            },
            child: const Text('נחש!'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitLetterGuess(String letter, RoomModel room) async {
    if (_gameImage == null) return;
    setState(() {
      _hasGuessedLetter = true;
      _isActing = true;
    });
    try {
      final isCorrect = await ref.read(roomServiceProvider).guessLetter(
            roomId: widget.roomId,
            userId: _actingUserId(room),
            letter: letter,
            image: _gameImage!,
            difficulty: room.selectedDifficulty!,
          );
      if (mounted && !isCorrect) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '❌ האות "$letter" לא במילה! -${room.selectedDifficulty!.wrongGuessPenalty} נקודות'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _hasGuessedLetter = false);
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  void _showGuessDialog(RoomModel room) {
    if (_hasGuessed || _isActing) return;
    final difficulty = room.selectedDifficulty!;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          '🤔 מי שם?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'ניחוש שגוי: -${difficulty.wrongGuessPenalty} נקודות',
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'הקלד את הניחוש שלך...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onSubmitted: (v) {
                Navigator.pop(ctx);
                _submitGuess(v.trim(), room);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () {
              final guess = controller.text.trim();
              Navigator.pop(ctx);
              _submitGuess(guess, room);
            },
            child: const Text('נחש!'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitGuess(String guess, RoomModel room) async {
    if (guess.isEmpty || _gameImage == null) return;

    setState(() {
      _hasGuessed = true;
      _isActing = true;
    });

    try {
      final isCorrect = await ref.read(roomServiceProvider).makeGuess(
            roomId: widget.roomId,
            userId: _actingUserId(room),
            guess: guess,
            image: _gameImage!,
            difficulty: room.selectedDifficulty!,
          );

      if (mounted) {
        if (!isCorrect) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '❌ שגוי! -${room.selectedDifficulty!.wrongGuessPenalty} נקודות'),
              backgroundColor: AppColors.secondary,
            ),
          );
        }
        setState(() => _isActing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('שגיאה: $e')),
        );
        setState(() {
          _hasGuessed = false;
          _isActing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));
    final currentUser = ref.watch(currentUserProvider).value;

    return roomAsync.when(
      data: (room) {
        if (room == null) return const SizedBox();

        if (room.phase == GamePhase.finished) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/win/${widget.roomId}');
          });
        }

        if (currentUser == null) return const SizedBox();

        final difficulty = room.selectedDifficulty ?? Difficulty.easy;
        final gridSize = difficulty.gridSize;
        final currentPlayer = room.players[room.currentTurnUserId];
        final isVirtualTurn = currentPlayer?.isBot == true;
        final isMyTurn =
            room.currentTurnUserId == currentUser.id || isVirtualTurn;
        final myPlayer = room.players[currentUser.id];
        final allRevealed = room.availablePieceIndices.isEmpty;
        final canFlipPiece =
            isMyTurn && !_hasFlipped && !allRevealed && !_isActing;

        return Scaffold(
          backgroundColor: const Color(0xFFF0F2FF),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.exit_to_app_rounded,
                  color: AppColors.darkBlue),
              onPressed: () => _confirmExit(context, currentUser.id),
            ),
            title: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: isVirtualTurn
                  ? Row(
                      key: const ValueKey('virtual'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🎮', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'תור של ${currentPlayer?.name ?? '...'}',
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      key: ValueKey(isMyTurn),
                      isMyTurn ? '⭐ התור שלך!' : 'ממתין לתור...',
                      style: TextStyle(
                        color: isMyTurn ? AppColors.primary : Colors.grey,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
            ),
            actions: [
              if (myPlayer != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ScoreBadge(
                    score: myPlayer.score,
                    isCurrentTurn: isMyTurn && !isVirtualTurn,
                  ),
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                _PlayersBar(room: room, currentUserId: currentUser.id),

                // Word guess bar — interactive letter boxes
                if (_gameImage != null)
                  _WordGuessBar(
                    answer: _gameImage!.answer,
                    solvedLetters: room.solvedLetters,
                    canGuess: isMyTurn && !_hasGuessedLetter && !_isActing &&
                        !(room.players[currentUser.id]?.isEliminated ?? false),
                    onTapGuess: () => _showLetterGuessDialog(room),
                  ).animate().fadeIn(duration: 400.ms),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                    child: _PuzzleBoard(
                      room: room,
                      gameImage: _gameImage,
                      gridSize: gridSize,
                      canFlipPiece: canFlipPiece,
                      onFlip: (index) => _flipPiece(index, room),
                    ),
                  ),
                ),

                _BottomBar(
                  isMyTurn: isMyTurn,
                  isVirtualTurn: isVirtualTurn,
                  actingPlayerName: currentPlayer?.name,
                  hasFlipped: _hasFlipped,
                  allRevealed: allRevealed,
                  hasGuessed: _hasGuessed,
                  hasGuessedLetter: _hasGuessedLetter,
                  isActing: _isActing,
                  isEliminated: myPlayer?.isEliminated == true,
                  onGuessLetter: () => _showLetterGuessDialog(room),
                  onGuess: () => _showGuessDialog(room),
                  onEndTurn: _endTurn,
                ),
              ],
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('שגיאה: $e'))),
    );
  }

  void _confirmExit(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('לצאת מהמשחק?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('תאבד את ההתקדמות שלך בסיבוב זה.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('הישאר')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(roomServiceProvider)
                  .leaveRoom(widget.roomId, userId);
              if (context.mounted) context.go('/home');
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary),
            child: const Text('צא'),
          ),
        ],
      ),
    );
  }
}

// ─── Word Guess Bar ────────────────────────────────────────────

class _WordGuessBar extends StatelessWidget {
  final String answer;
  final List<String> solvedLetters;
  final bool canGuess;
  final VoidCallback onTapGuess;

  const _WordGuessBar({
    required this.answer,
    required this.solvedLetters,
    required this.canGuess,
    required this.onTapGuess,
  });

  @override
  Widget build(BuildContext context) {
    final chars = answer.runes.map(String.fromCharCode).toList();
    final solved = Set<String>.from(solvedLetters);

    return Container(
      width: double.infinity,
      color: const Color(0xFFF0F2FF),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: chars.map((char) {
            if (char == ' ') return const SizedBox(width: 14);

            final isRevealed = solved.contains(char.toLowerCase());

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: GestureDetector(
                onTap: (!isRevealed && canGuess) ? onTapGuess : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  width: 36,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: isRevealed ? AppColors.primaryGradient : null,
                    color: isRevealed
                        ? null
                        : canGuess
                            ? Colors.white
                            : Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: isRevealed
                          ? AppColors.primary
                          : canGuess
                              ? AppColors.primary.withOpacity(0.4)
                              : AppColors.pieceSlotEmpty,
                      width: canGuess && !isRevealed ? 1.8 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isRevealed
                            ? AppColors.primary.withOpacity(0.35)
                            : Colors.black.withOpacity(0.05),
                        blurRadius: isRevealed ? 8 : 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: isRevealed
                          ? Text(
                              char,
                              key: ValueKey('r_$char'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                height: 1,
                              ),
                            )
                          : Text(
                              canGuess ? '+' : '_',
                              key: ValueKey('h_$canGuess'),
                              style: TextStyle(
                                color: canGuess
                                    ? AppColors.primary
                                    : Colors.grey.shade400,
                                fontWeight: FontWeight.w700,
                                fontSize: canGuess ? 20 : 16,
                                height: 1,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Bottom Bar ───────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final bool isMyTurn;
  final bool isVirtualTurn;
  final String? actingPlayerName;
  final bool hasFlipped;
  final bool allRevealed;
  final bool hasGuessed;
  final bool hasGuessedLetter;
  final bool isActing;
  final bool isEliminated;
  final VoidCallback onGuessLetter;
  final VoidCallback onGuess;
  final VoidCallback onEndTurn;

  const _BottomBar({
    required this.isMyTurn,
    required this.isVirtualTurn,
    required this.actingPlayerName,
    required this.hasFlipped,
    required this.allRevealed,
    required this.hasGuessed,
    required this.hasGuessedLetter,
    required this.isActing,
    required this.isEliminated,
    required this.onGuessLetter,
    required this.onGuess,
    required this.onEndTurn,
  });

  @override
  Widget build(BuildContext context) {
    if (!isMyTurn) {
      return _infoBar(
        '⏳ ${actingPlayerName ?? '...'} חושף אות...',
        AppColors.primary.withOpacity(0.08),
        AppColors.primary,
      );
    }

    final needsFlip = !hasFlipped && !allRevealed;

    if (needsFlip) {
      return _infoBar(
        isVirtualTurn
            ? '👆 הפוך משבצת עבור ${actingPlayerName ?? 'שחקן'}'
            : '👆 הפוך משבצת לחשוף אות!',
        isVirtualTurn
            ? AppColors.accent.withOpacity(0.12)
            : AppColors.primary.withOpacity(0.1),
        isVirtualTurn ? AppColors.accent : AppColors.primary,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: (hasGuessedLetter || isEliminated || isActing)
                  ? null
                  : onGuessLetter,
              icon: const Icon(Icons.abc_rounded, size: 20),
              label: Text(hasGuessedLetter ? 'ניחשת אות' : 'כתוב אות'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 13),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: (hasGuessed || isEliminated || isActing) ? null : onGuess,
              icon: const Icon(Icons.psychology_rounded, size: 18),
              label: Text(hasGuessed ? 'ניחשת' : 'נחש מילה'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                padding: const EdgeInsets.symmetric(vertical: 13),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isActing ? null : onEndTurn,
              icon: const Icon(Icons.skip_next_rounded, size: 18),
              label: const Text('סיים תור'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 13),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBar(String text, Color bg, Color textColor) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

// ─── Players Bar ─────────────────────────────────────────────

class _PlayersBar extends StatelessWidget {
  final RoomModel room;
  final String? currentUserId;

  const _PlayersBar({required this.room, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        children: room.sortedPlayers.map((player) {
          final isCurrentTurn = room.currentTurnUserId == player.id;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PlayerAvatar(
                  name: player.name,
                  photoUrl: player.photoUrl,
                  radius: 20,
                  isCurrentTurn: isCurrentTurn,
                  isEliminated: player.isEliminated,
                ),
                const SizedBox(height: 4),
                ScoreBadge(
                  score: player.score,
                  isCurrentTurn: isCurrentTurn,
                  isEliminated: player.isEliminated,
                  isHost: player.isHost,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Puzzle Board ─────────────────────────────────────────────

class _PuzzleBoard extends StatelessWidget {
  final RoomModel room;
  final GameImageModel? gameImage;
  final int gridSize;
  final bool canFlipPiece;
  final void Function(int)? onFlip;

  const _PuzzleBoard({
    required this.room,
    this.gameImage,
    required this.gridSize,
    required this.canFlipPiece,
    this.onFlip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.boardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.pieceSlotEmpty, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Full image background ──
            if (gameImage != null)
              CachedNetworkImage(
                imageUrl: gameImage!.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: AppColors.boardBackground),
                errorWidget: (_, __, ___) =>
                    Container(color: AppColors.boardBackground),
              )
            else
              Container(color: AppColors.boardBackground),

            // ── Cell overlay grid ──
            // LayoutBuilder computes the exact cell aspect ratio so cells
            // fill the full container height, preventing image bleed at bottom.
            Padding(
              padding: const EdgeInsets.all(3),
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  const spacing = 2.0;
                  final totalSpacingH = spacing * (gridSize - 1);
                  final totalSpacingV = spacing * (gridSize - 1);
                  final cellW =
                      (constraints.maxWidth - totalSpacingH) / gridSize;
                  final cellH =
                      (constraints.maxHeight - totalSpacingV) / gridSize;
                  final ratio = cellW / cellH;

                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridSize,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      childAspectRatio: ratio,
                    ),
                    itemCount: gridSize * gridSize,
                    itemBuilder: (context, index) {
                      final isRevealed = room.placedPieces.containsKey(index);
                      final canFlip = canFlipPiece && !isRevealed;

                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        switchInCurve: Curves.easeOut,
                        transitionBuilder: (child, anim) => ScaleTransition(
                          scale: anim,
                          child: FadeTransition(opacity: anim, child: child),
                        ),
                        child: isRevealed
                            ? _buildRevealedCell(index)
                            : GestureDetector(
                                key: ValueKey('h_$index'),
                                onTap:
                                    canFlip ? () => onFlip?.call(index) : null,
                                child: _HiddenCard(isFlippable: canFlip),
                              ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevealedCell(int index) {
    // Revealed cells are transparent — the image beneath shows through
    return SizedBox.expand(key: ValueKey('empty_$index'));
  }
}

// ─── Hidden Card (unrevealed) ─────────────────────────────────

class _HiddenCard extends StatelessWidget {
  final bool isFlippable;

  const _HiddenCard({required this.isFlippable});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        gradient: isFlippable
            ? AppColors.primaryGradient
            : const LinearGradient(
                colors: [Color(0xFF3A4580), Color(0xFF252E66)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(
          color: isFlippable
              ? Colors.white.withOpacity(0.5)
              : Colors.white.withOpacity(0.06),
          width: 0.5,
        ),
      ),
      child: Center(
        child: Text(
          isFlippable ? '👆' : '?',
          style: TextStyle(
            fontSize: isFlippable ? 13 : 9,
            color: Colors.white.withOpacity(isFlippable ? 0.9 : 0.25),
          ),
        ),
      ),
    );
  }
}
