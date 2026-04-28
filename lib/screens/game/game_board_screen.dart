import 'dart:math' as math;

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
        final media = MediaQuery.of(context);
        const playersBarHeight = 76.0;
        const actionRowHeight = 52.0;
        const verticalChrome = playersBarHeight + actionRowHeight + 16.0;
        const minLetterBankHeight = 150.0;
        final bodyHeight =
            media.size.height - media.padding.vertical - kToolbarHeight;
        final maxPuzzleWidth = math.max(80.0, media.size.width - 24.0);
        final maxPuzzleHeight =
            math.max(80.0, bodyHeight - verticalChrome - minLetterBankHeight);
        final puzzleSize = math.min(
          maxPuzzleWidth,
          math.min(260.0, maxPuzzleHeight),
        );

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PlayersBar(room: room, currentUserId: currentUser.id),
                SizedBox(
                  height: puzzleSize,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Center(
                      child: SizedBox.square(
                        dimension: puzzleSize,
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
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _gameImage != null
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: maxPuzzleWidth,
                              child: LetterBankInput(
                                key: ValueKey('lbi_${_gameImage!.id}'),
                                answer: _gameImage!.answer,
                                enabled: canSubmitAnswer,
                                onComplete: (filled) =>
                                    _onAnswerComplete(room, filled),
                              ),
                            ),
                          )
                        : const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary),
                          ),
                  ),
                ),
                SizedBox(
                  height: actionRowHeight,
                  child: _ActionRow(
                    isMyTurn: isMyTurn,
                    isVirtualTurn: isVirtualTurn,
                    actingPlayerName: currentPlayer?.name,
                    isActing: _isActing,
                    isEliminated: isEliminated,
                    onSkipTurn: _endTurn,
                  ),
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
      height: 76,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          children: room.sortedPlayers.map((player) {
            final isCurrentTurn = room.currentTurnUserId == player.id;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PlayerAvatar(
                      name: player.name,
                      photoUrl: player.photoUrl,
                      radius: 15,
                      isCurrentTurn: isCurrentTurn,
                      isEliminated: player.isEliminated,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isCurrentTurn
                            ? AppColors.primary
                            : AppColors.darkBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ScoreBadge(
                        score: player.score,
                        isCurrentTurn: isCurrentTurn,
                        isEliminated: player.isEliminated,
                        isHost: player.isHost,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
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
            Column(
              children: List.generate(gridSize, (row) {
                return Expanded(
                  child: Row(
                    children: List.generate(gridSize, (column) {
                      final index = row * gridSize + column;
                      final isRevealed = room.placedPieces.containsKey(index);
                      final canFlip = canFlipPiece && !isRevealed;

                      return Expanded(
                        child: isRevealed
                            ? SizedBox.expand(key: ValueKey('empty_$index'))
                            : GestureDetector(
                                key: ValueKey('h_$index'),
                                onTap:
                                    canFlip ? () => onFlip?.call(index) : null,
                                child: _HiddenCard(isFlippable: canFlip),
                              ),
                      );
                    }),
                  ),
                );
              }),
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
