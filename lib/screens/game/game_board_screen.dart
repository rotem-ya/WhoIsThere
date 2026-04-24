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
  int? _selectedPieceIndex;
  bool _hasPlacedPiece = false;
  bool _hasGuessed = false;
  bool _isActing = false;
  GameImageModel? _gameImage;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final room = ref.read(currentRoomProvider).value;
    if (room?.selectedImageId == null) return;
    final img =
        await ref.read(roomServiceProvider).getImage(room!.selectedImageId!);
    if (mounted) setState(() => _gameImage = img);
  }

  Future<void> _tryPlacePiece(int slotIndex, RoomModel room) async {
    if (_selectedPieceIndex == null || _hasPlacedPiece || _isActing) return;
    final difficulty = room.selectedDifficulty!;
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    setState(() => _isActing = true);

    // Correct placement: piece index matches slot index
    final isCorrect = _selectedPieceIndex == slotIndex;

    if (isCorrect) {
      await ref.read(roomServiceProvider).placePiece(
            roomId: widget.roomId,
            userId: user.id,
            pieceIndex: _selectedPieceIndex!,
            difficulty: difficulty,
          );
      setState(() {
        _hasPlacedPiece = true;
        _selectedPieceIndex = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Text('✅ Piece placed! +${0} points'),
            ]),
            backgroundColor: AppColors.accent,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } else {
      // Wrong placement - piece bounces back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Doesn\'t fit here! Try another slot.'),
            backgroundColor: AppColors.secondary,
            duration: Duration(seconds: 1),
          ),
        );
      }
      // Don't advance turn - they still have their guess
    }

    setState(() => _isActing = false);
  }

  Future<void> _skipPiecePlacement() async {
    if (_isActing) return;
    setState(() => _isActing = true);
    await ref.read(roomServiceProvider).skipPiecePlacement(roomId: widget.roomId);
    setState(() {
      _hasPlacedPiece = true;
      _selectedPieceIndex = null;
      _isActing = false;
    });
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
          '🤔 Who is there?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Wrong guess: -${difficulty.wrongGuessPenalty} points',
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
                hintText: 'Type your guess...',
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final guess = controller.text.trim();
              Navigator.pop(ctx);
              _submitGuess(guess, room);
            },
            child: const Text('Guess!'),
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
      if (isCorrect) {
        // Navigation handled by room state listener
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '❌ Wrong! -${room.selectedDifficulty!.wrongGuessPenalty} points'),
            backgroundColor: AppColors.secondary,
          ),
        );
        // If placed piece already, advance turn
        if (_hasPlacedPiece) {
          setState(() => _isActing = false);
        } else {
          setState(() => _isActing = false);
        }
      }
    }

    setState(() => _isActing = false);
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

        final difficulty = room.selectedDifficulty ?? Difficulty.easy;
        final gridSize = difficulty.gridSize;
        final isMyTurn = room.currentTurnUserId == currentUser?.id;
        final myPlayer = room.players[currentUser?.id];

        // Reset turn state when turn changes
        if (isMyTurn && _hasPlacedPiece && !_hasGuessed) {
          // Still on our turn, can guess
        }
        if (!isMyTurn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && (_hasPlacedPiece || _hasGuessed)) {
              setState(() {
                _hasPlacedPiece = false;
                _hasGuessed = false;
                _selectedPieceIndex = null;
              });
            }
          });
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(
              isMyTurn ? '⭐ Your Turn!' : 'Watching...',
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
                _PlayersBar(room: room, currentUserId: currentUser?.id),

                // Board
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _PuzzleBoard(
                      room: room,
                      gameImage: _gameImage,
                      gridSize: gridSize,
                      selectedPieceIndex: _selectedPieceIndex,
                      isMyTurn: isMyTurn,
                      onSlotTap: isMyTurn && _selectedPieceIndex != null
                          ? (i) => _tryPlacePiece(i, room)
                          : null,
                    ),
                  ),
                ),

                // Pieces tray
                if (isMyTurn) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Available Pieces',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkBlue,
                                fontSize: 14,
                              ),
                            ),
                            if (!_hasPlacedPiece)
                              TextButton(
                                onPressed: _skipPiecePlacement,
                                child: const Text('Skip placement'),
                              ),
                          ],
                        ),
                        SizedBox(
                          height: 72,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: room.availablePieceIndices.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final pieceIdx =
                                  room.availablePieceIndices[i];
                              final isSelected =
                                  _selectedPieceIndex == pieceIdx;

                              return GestureDetector(
                                onTap: _hasPlacedPiece
                                    ? null
                                    : () => setState(
                                          () => _selectedPieceIndex =
                                              isSelected ? null : pieceIdx,
                                        ),
                                child: _PieceTile(
                                  pieceIndex: pieceIdx,
                                  gridSize: gridSize,
                                  imageUrl: _gameImage?.imageUrl,
                                  isSelected: isSelected,
                                  isLocked: _hasPlacedPiece,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          '${room.players[room.currentTurnUserId]?.name ?? '...'} is playing...',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action buttons
                if (isMyTurn)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (_hasGuessed || myPlayer?.isEliminated == true)
                                ? null
                                : () => _showGuessDialog(room),
                            icon: const Icon(Icons.psychology_rounded),
                            label: Text(_hasGuessed ? 'Guessed!' : 'Make a Guess'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        if (_hasPlacedPiece && _hasGuessed) ...[
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              // Turn ends automatically via Firestore
                            },
                            icon: const Icon(Icons.done_rounded),
                            label: const Text('End Turn'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
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
  final int? selectedPieceIndex;
  final bool isMyTurn;
  final void Function(int slotIndex)? onSlotTap;

  const _PuzzleBoard({
    required this.room,
    this.gameImage,
    required this.gridSize,
    this.selectedPieceIndex,
    required this.isMyTurn,
    this.onSlotTap,
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
          itemBuilder: (context, slotIndex) {
            final isPlaced = room.placedPieces.containsKey(slotIndex);
            final placedByUserId = room.placedPieces[slotIndex];
            final canDrop = onSlotTap != null && !isPlaced;

            return GestureDetector(
              onTap: canDrop ? () => onSlotTap!(slotIndex) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isPlaced
                      ? Colors.transparent
                      : canDrop
                          ? AppColors.primary.withOpacity(0.15)
                          : AppColors.pieceSlotEmpty.withOpacity(0.5),
                  border: Border.all(
                    color: canDrop
                        ? AppColors.primary.withOpacity(0.5)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: isPlaced && gameImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: _PieceImage(
                          imageUrl: gameImage!.imageUrl,
                          pieceIndex: slotIndex,
                          gridSize: gridSize,
                        ),
                      )
                    : isPlaced
                        ? Container(
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          )
                        : null,
              ),
            );
          },
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

    return ClipRect(
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        alignment: Alignment(
          col / (gridSize - 1) * 2 - 1,
          row / (gridSize - 1) * 2 - 1,
        ),
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Transform.scale(
            scale: gridSize.toDouble(),
            alignment: Alignment(
              col / (gridSize - 1) * 2 - 1,
              row / (gridSize - 1) * 2 - 1,
            ),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  Container(color: AppColors.boardBackground),
            ),
          ),
        ),
      ),
    );
  }
}

class _PieceTile extends StatelessWidget {
  final int pieceIndex;
  final int gridSize;
  final String? imageUrl;
  final bool isSelected;
  final bool isLocked;

  const _PieceTile({
    required this.pieceIndex,
    required this.gridSize,
    this.imageUrl,
    required this.isSelected,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.pieceSlotEmpty,
          width: isSelected ? 2.5 : 1.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
        color: isLocked ? Colors.grey.shade200 : Colors.white,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: imageUrl != null
            ? _PieceImage(
                imageUrl: imageUrl!,
                pieceIndex: pieceIndex,
                gridSize: gridSize,
              )
            : Center(
                child: Text(
                  '#$pieceIndex',
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : Colors.grey,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
      ),
    )
        .animate(target: isSelected ? 1 : 0)
        .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.1, 1.1),
            duration: 150.ms);
  }
}
