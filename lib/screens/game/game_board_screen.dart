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
      final room = await ref.read(currentRoomProvider.future);
      if (room?.selectedImageId == null) return;
      final img =
          await ref.read(roomServiceProvider).getImage(room!.selectedImageId!);
      if (mounted) setState(() => _gameImage = img);
    } catch (e) {
      debugPrint('Failed to load game image: $e');
    }
  }

  Future<void> _flipPiece(int pieceIndex, RoomModel room) async {
    if (_hasFlipped || _isActing) return;
    final difficulty = room.selectedDifficulty!;
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    setState(() => _isActing = true);

    await ref.read(roomServiceProvider).revealPiece(
          roomId: widget.roomId,
          userId: user.id,
          pieceIndex: pieceIndex,
          difficulty: difficulty,
        );

    if (mounted) {
      setState(() {
        _hasFlipped = true;
        _isActing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ חתיכה נחשפה! +${difficulty.placePiecePoints} נקודות'),
          backgroundColor: AppColors.accent,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _endTurn() async {
    if (_isActing) return;
    setState(() => _isActing = true);
    await ref
        .read(roomServiceProvider)
        .skipPiecePlacement(roomId: widget.roomId);
    if (mounted) setState(() => _isActing = false);
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
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    setState(() {
      _hasGuessed = true;
      _isActing = true;
    });

    final isCorrect = await ref.read(roomServiceProvider).makeGuess(
          roomId: widget.roomId,
          userId: user.id,
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
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(currentRoomProvider);
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
        final isMyTurn = room.currentTurnUserId == currentUser.id;
        final myPlayer = room.players[currentUser.id];
        final allRevealed = room.availablePieceIndices.isEmpty;

        // Reset turn state when turn changes
        if (!isMyTurn && (_hasFlipped || _hasGuessed)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _hasFlipped = false;
                _hasGuessed = false;
              });
            }
          });
        }

        final canFlipPiece =
            isMyTurn && !_hasFlipped && !allRevealed && !_isActing;
        final effectivelyFlipped = _hasFlipped || allRevealed;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.exit_to_app_rounded),
              onPressed: () => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
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
                        if (currentUser != null) {
                          await ref
                              .read(roomServiceProvider)
                              .leaveRoom(widget.roomId, currentUser.id);
                        }
                        if (context.mounted) context.go('/home');
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary),
                      child: const Text('צא'),
                    ),
                  ],
                ),
              ),
            ),
            title: Text(
              isMyTurn ? '⭐ התור שלך!' : 'צופה...',
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
                    isCurrentTurn: isMyTurn,
                  ),
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Players row
                _PlayersBar(room: room, currentUserId: currentUser.id),

                // Board — takes most of the screen
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _PuzzleBoard(
                      room: room,
                      gameImage: _gameImage,
                      gridSize: gridSize,
                      canFlipPiece: canFlipPiece,
                      onFlip: (index) => _flipPiece(index, room),
                    ),
                  ),
                ),

                // Bottom action area
                if (isMyTurn) ...[
                  if (!effectivelyFlipped)
                    // Instruction: tap a piece to flip
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('👆', style: TextStyle(fontSize: 20)),
                          SizedBox(width: 10),
                          Text(
                            'הפוך חתיכה על הלוח!',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    // After flipping: guess or end turn
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  (_hasGuessed || myPlayer?.isEliminated == true)
                                      ? null
                                      : () => _showGuessDialog(room),
                              icon: const Icon(Icons.psychology_rounded),
                              label:
                                  Text(_hasGuessed ? 'ניחשת!' : 'נחש'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: _isActing ? null : _endTurn,
                            icon: const Icon(Icons.skip_next_rounded),
                            label: const Text('סיים תור'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                ] else ...[
                  // Waiting for other player
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.hourglass_bottom_rounded,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${room.players[room.currentTurnUserId]?.name ?? '...'} מהפך חתיכה...',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 8),
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
}

class _PlayersBar extends StatelessWidget {
  final RoomModel room;
  final String? currentUserId;

  const _PlayersBar({required this.room, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: room.sortedPlayers.map((player) {
          final isCurrentTurn = room.currentTurnUserId == player.id;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
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

class _PuzzleBoard extends StatelessWidget {
  final RoomModel room;
  final GameImageModel? gameImage;
  final int gridSize;
  final bool canFlipPiece;
  final void Function(int pieceIndex)? onFlip;

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
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridSize,
            crossAxisSpacing: 3,
            mainAxisSpacing: 3,
          ),
          itemCount: gridSize * gridSize,
          itemBuilder: (context, index) {
            final isRevealed = room.placedPieces.containsKey(index);
            final canFlip = canFlipPiece && !isRevealed;

            return GestureDetector(
              onTap: canFlip ? () => onFlip?.call(index) : null,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: child,
                ),
                child: isRevealed && gameImage != null
                    ? ClipRRect(
                        key: ValueKey('r_$index'),
                        borderRadius: BorderRadius.circular(3),
                        child: _PieceImage(
                          imageUrl: gameImage!.imageUrl,
                          pieceIndex: index,
                          gridSize: gridSize,
                        ),
                      )
                    : _HiddenPiece(
                        key: ValueKey('h_$index'),
                        isFlippable: canFlip,
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HiddenPiece extends StatelessWidget {
  final bool isFlippable;

  const _HiddenPiece({super.key, required this.isFlippable});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: isFlippable
            ? AppColors.primaryGradient
            : const LinearGradient(
                colors: [Color(0xFF3D4B8F), Color(0xFF2D3561)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(
          color: isFlippable
              ? Colors.white.withOpacity(0.6)
              : Colors.white.withOpacity(0.08),
          width: isFlippable ? 1.5 : 0.5,
        ),
        boxShadow: isFlippable
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: Center(
        child: Text(
          isFlippable ? '👆' : '?',
          style: TextStyle(
            fontSize: isFlippable ? 14 : 10,
            color: Colors.white.withOpacity(isFlippable ? 0.9 : 0.3),
          ),
        ),
      ),
    );
  }
}

class _PieceImage extends StatelessWidget {
  final String imageUrl;
  final int pieceIndex;
  final int gridSize;

  const _PieceImage({
    required this.imageUrl,
    required this.pieceIndex,
    required this.gridSize,
  });

  @override
  Widget build(BuildContext context) {
    final row = pieceIndex ~/ gridSize;
    final col = pieceIndex % gridSize;
    final divisor = gridSize <= 1 ? 1 : gridSize - 1;
    final alignX = gridSize <= 1 ? 0.0 : col / divisor * 2 - 1;
    final alignY = gridSize <= 1 ? 0.0 : row / divisor * 2 - 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 100.0;
        final cellH =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 100.0;
        final imageW = cellW * gridSize;
        final imageH = cellH * gridSize;

        return ClipRect(
          child: OverflowBox(
            minWidth: imageW,
            maxWidth: imageW,
            minHeight: imageH,
            maxHeight: imageH,
            alignment: Alignment(alignX, alignY),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: imageW,
              height: imageH,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  Container(color: Colors.grey.shade200),
            ),
          ),
        );
      },
    );
  }
}
