import 'package:flutter/material.dart';
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
import '../../widgets/game/letter_bank_input.dart';

class GameBoardScreen extends ConsumerStatefulWidget {
  final String roomId;

  const GameBoardScreen({super.key, required this.roomId});

  @override
  ConsumerState<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends ConsumerState<GameBoardScreen> {
  bool _hasFlipped = false;
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
        });
      }
    }
  }

  Future<bool> _onAnswerComplete(RoomModel room, String filled) async {
    if (_gameImage == null) return false;
    try {
      return await ref.read(roomServiceProvider).submitAnswer(
            roomId: widget.roomId,
            userId: _actingUserId(room),
            guess: filled,
            image: _gameImage!,
            difficulty: room.selectedDifficulty!,
          );
    } catch (_) {
      return false;
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
        final isEliminated = myPlayer?.isEliminated == true;
        final canSubmitAnswer = isMyTurn && !isEliminated && !_isActing;

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
            title: Text(
              isVirtualTurn
                  ? 'תור של ${currentPlayer?.name ?? '...'}'
                  : isMyTurn
                      ? '⭐ התור שלך!'
                      : 'ממתין לתור...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isMyTurn ? AppColors.primary : Colors.grey,
                fontWeight: FontWeight.w800,
                fontSize: 17,
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
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final puzzleSide = constraints.maxHeight * 0.38;
                final puzzleSize =
                    puzzleSide.clamp(160.0, constraints.maxWidth - 24);

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PlayersBar(room: room, currentUserId: currentUser.id),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: SizedBox(
                              width: puzzleSize,
                              height: puzzleSize,
                              child: _PuzzleBoard(
                                room: room,
                                gameImage: _gameImage,
                                gridSize: gridSize,
                                canFlipPiece: canFlipPiece,
                                onFlip: (index) => _flipPiece(index, room),
                              ),
                            ),
                          ),
                        ),
                        if (_gameImage != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: LetterBankInput(
                              key: ValueKey('lbi_${_gameImage!.id}'),
                              answer: _gameImage!.answer,
                              enabled: canSubmitAnswer,
                              onComplete: (filled) =>
                                  _onAnswerComplete(room, filled),
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.primary),
                            ),
                          ),
                        const SizedBox(height: 6),
                        _ActionRow(
                          isMyTurn: isMyTurn,
                          isVirtualTurn: isVirtualTurn,
                          actingPlayerName: currentPlayer?.name,
                          isActing: _isActing,
                          isEliminated: isEliminated,
                          onSkipTurn: _endTurn,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                );
              },
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

// ─── Action Row (skip turn) ───────────────────────────────────

class _ActionRow extends StatelessWidget {
  final bool isMyTurn;
  final bool isVirtualTurn;
  final String? actingPlayerName;
  final bool isActing;
  final bool isEliminated;
  final VoidCallback onSkipTurn;

  const _ActionRow({
    required this.isMyTurn,
    required this.isVirtualTurn,
    required this.actingPlayerName,
    required this.isActing,
    required this.isEliminated,
    required this.onSkipTurn,
  });

  @override
  Widget build(BuildContext context) {
    if (!isMyTurn) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          '⏳ ${actingPlayerName ?? '...'} משחק עכשיו',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: (isActing || isEliminated) ? null : onSkipTurn,
          icon: const Icon(Icons.skip_next_rounded, size: 18),
          label: Text(isVirtualTurn ? 'דלג עבור הבוט' : 'סיים תור'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(vertical: 12),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
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
      height: 88,
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
                  radius: 18,
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

                      if (isRevealed) {
                        return SizedBox.expand(
                            key: ValueKey('empty_$index'));
                      }
                      return GestureDetector(
                        key: ValueKey('h_$index'),
                        onTap: canFlip ? () => onFlip?.call(index) : null,
                        child: _HiddenCard(isFlippable: canFlip),
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
}

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
