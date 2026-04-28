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
import '../../widgets/common/premium_scaffold.dart';
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

        return PremiumScaffold(
          showBeams: true,
          child: Column(
            children: [
              ArcadeHeader(
                eyebrow: difficulty.label,
                title: isVirtualTurn
                    ? '${currentPlayer?.name ?? '...'} משחק'
                    : isMyTurn
                        ? 'התור שלך'
                        : 'ממתינים',
                subtitle: '${room.availablePieceIndices.length} חלקים מוסתרים',
                leading: IconButton(
                  icon: const Icon(Icons.exit_to_app_rounded,
                      color: Colors.white),
                  onPressed: () => _confirmExit(context, currentUser.id),
                ),
                trailing: myPlayer == null
                    ? null
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.16)),
                        ),
                        child: Text(
                          '${myPlayer.score} נק׳',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final height = constraints.maxHeight;
                    final width = constraints.maxWidth;
                    final playersHeight = room.players.length > 3 ? 72.0 : 88.0;
                    final actionsHeight = 78.0;
                    final verticalGaps = 18.0;
                    final availableForPuzzleAndInput =
                        height - playersHeight - actionsHeight - verticalGaps;
                    final puzzleSize = math
                        .min(width - 24, availableForPuzzleAndInput * 0.56)
                        .clamp(188.0, 318.0)
                        .toDouble();
                    final inputHeight = math.max(
                      150.0,
                      availableForPuzzleAndInput - puzzleSize,
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: playersHeight,
                          child: _PlayersBar(
                            room: room,
                            currentUserId: currentUser.id,
                          ),
                        ),
                        SizedBox(
                          height: puzzleSize,
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
                        SizedBox(
                          height: inputHeight,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                            child: _gameImage != null
                                ? LetterBankInput(
                                    key: ValueKey('lbi_${_gameImage!.id}'),
                                    answer: _gameImage!.answer,
                                    enabled: canSubmitAnswer,
                                    onComplete: (filled) =>
                                        _onAnswerComplete(room, filled),
                                  )
                                : const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                    ),
                                  ),
                          ),
                        ),
                        SizedBox(
                          height: actionsHeight,
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
                    );
                  },
                ),
              ),
            ],
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'לצאת מהמשחק?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text('תאבד את ההתקדמות שלך בסיבוב זה.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('הישאר'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(roomServiceProvider)
                  .leaveRoom(widget.roomId, userId);
              if (context.mounted) context.go('/home');
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            child: const Text('צא'),
          ),
        ],
      ),
    );
  }
}

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
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
          ),
          child: Text(
            '${actingPlayerName ?? 'שחקן'} משחק עכשיו',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
              height: 1,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withOpacity(0.22),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: (isActing || isEliminated) ? null : onSkipTurn,
          icon: const Icon(Icons.skip_next_rounded, size: 18),
          label: Text(isVirtualTurn ? 'דלג עבור הבוט' : 'סיים תור'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.grey.shade300,
            foregroundColor: Colors.white,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayersBar extends StatelessWidget {
  final RoomModel room;
  final String? currentUserId;

  const _PlayersBar({required this.room, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
      child: Row(
        children: room.sortedPlayers.map((player) {
          final isCurrentTurn = room.currentTurnUserId == player.id;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrentTurn
                      ? Colors.white.withOpacity(0.16)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayerAvatar(
                      name: player.name,
                      photoUrl: player.photoUrl,
                      radius: 13,
                      isCurrentTurn: isCurrentTurn,
                      isEliminated: player.isEliminated,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
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
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.boardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.30), width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.24),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
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
            GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: gridSize,
                mainAxisSpacing: 1,
                crossAxisSpacing: 1,
              ),
              itemCount: gridSize * gridSize,
              itemBuilder: (context, index) {
                final isRevealed = room.placedPieces.containsKey(index);
                final canFlip = canFlipPiece && !isRevealed;

                if (isRevealed) {
                  return SizedBox.expand(key: ValueKey('empty_$index'));
                }

                return GestureDetector(
                  key: ValueKey('h_$index'),
                  onTap: canFlip ? () => onFlip?.call(index) : null,
                  child: _HiddenCard(isFlippable: canFlip),
                );
              },
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
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        gradient: isFlippable
            ? AppColors.primaryGradient
            : const LinearGradient(
                colors: [Color(0xFF26315F), Color(0xFF1D2652)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
      ),
      child: Center(
        child: Text(
          isFlippable ? '?' : '?',
          style: TextStyle(
            fontSize: isFlippable ? 20 : 16,
            color: Colors.white.withOpacity(isFlippable ? 0.72 : 0.22),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
