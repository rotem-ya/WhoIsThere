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
          _hasGuessed = false;
        });
      }
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
          children: [
            Text(
              'ניחוש שגוי: -${difficulty.wrongGuessPenalty} נקודות',
              style: const TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
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
        final effectivelyFlipped = _hasFlipped || allRevealed;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.exit_to_app_rounded),
              onPressed: () => _confirmExit(context, currentUser.id),
            ),
            title: isVirtualTurn
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🎮 ',
                          style: TextStyle(fontSize: 14)),
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
                    isMyTurn ? '⭐ התור שלך!' : '...',
                    style: TextStyle(
                      color: isMyTurn ? AppColors.primary : Colors.grey,
                      fontWeight: FontWeight.w800,
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

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
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
                  effectivelyFlipped: effectivelyFlipped,
                  hasGuessed: _hasGuessed,
                  isActing: _isActing,
                  isEliminated: myPlayer?.isEliminated == true,
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

// ─── Bottom Bar ───────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final bool isMyTurn;
  final bool isVirtualTurn;
  final String? actingPlayerName;
  final bool effectivelyFlipped;
  final bool hasGuessed;
  final bool isActing;
  final bool isEliminated;
  final VoidCallback onGuess;
  final VoidCallback onEndTurn;

  const _BottomBar({
    required this.isMyTurn,
    required this.isVirtualTurn,
    required this.actingPlayerName,
    required this.effectivelyFlipped,
    required this.hasGuessed,
    required this.isActing,
    required this.isEliminated,
    required this.onGuess,
    required this.onEndTurn,
  });

  @override
  Widget build(BuildContext context) {
    if (!isMyTurn) {
      return _infoBar(
        '⏳ ${actingPlayerName ?? '...'} מהפך חתיכה...',
        AppColors.primary.withOpacity(0.08),
        AppColors.primary,
      );
    }

    if (!effectivelyFlipped) {
      return _infoBar(
        isVirtualTurn
            ? '👆 הפוך עבור ${actingPlayerName ?? 'שחקן'}'
            : '👆 הפוך חתיכה על הלוח!',
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
            flex: 3,
            child: ElevatedButton.icon(
              onPressed: (hasGuessed || isEliminated) ? null : onGuess,
              icon: const Icon(Icons.psychology_rounded, size: 18),
              label: Text(hasGuessed ? 'ניחשת' : 'נחש'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              onPressed: isActing ? null : onEndTurn,
              icon: const Icon(Icons.skip_next_rounded, size: 18),
              label: const Text('סיים תור'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15),
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
      height: 76,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: room.sortedPlayers.map((player) {
          final isCurrentTurn = room.currentTurnUserId == player.id;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              children: [
                PlayerAvatar(
                  name: player.name,
                  photoUrl: player.photoUrl,
                  radius: 20,
                  isCurrentTurn: isCurrentTurn,
                  isEliminated: player.isEliminated,
                ),
                const SizedBox(height: 2),
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

// ─── Puzzle Board (image + card overlay) ─────────────────────

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

            // ── Card overlay grid ──
            Padding(
              padding: const EdgeInsets.all(3),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridSize,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                itemCount: gridSize * gridSize,
                itemBuilder: (context, index) {
                  final isRevealed = room.placedPieces.containsKey(index);
                  final canFlip = canFlipPiece && !isRevealed;

                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: isRevealed
                        ? SizedBox.expand(key: ValueKey('r_$index'))
                        : GestureDetector(
                            key: ValueKey('h_$index'),
                            onTap: canFlip ? () => onFlip?.call(index) : null,
                            child: _HiddenCard(isFlippable: canFlip),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Hidden Card ─────────────────────────────────────────────

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
