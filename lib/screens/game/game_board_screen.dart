import 'dart:math' show Random, min;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/game_constants.dart';
import '../../models/game_image_model.dart';
import '../../models/player_model.dart';
import '../../models/room_model.dart';
import '../../providers/providers.dart';
import '../../widgets/game/letter_bank_input.dart';

const _kTileClosed = 'assets/images/tiles/tile_closed.png';
const _kTileEmpty = 'assets/images/tiles/tile_closed_empty.png';

class GameBoardScreen extends ConsumerStatefulWidget {
  final String roomId;

  const GameBoardScreen({super.key, required this.roomId});

  @override
  ConsumerState<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends ConsumerState<GameBoardScreen> {
  final _random = Random();
  final _guessController = TextEditingController();

  GameImageModel? _image;
  String _loadedImageId = '';
  String _lastBotTurnKey = '';
  bool _isBusy = false;

  @override
  void dispose() {
    _guessController.dispose();
    super.dispose();
  }

  Future<void> _loadImage(String imageId) async {
    if (imageId.isEmpty || imageId == _loadedImageId) return;
    _loadedImageId = imageId;
    try {
      final image = await ref.read(roomServiceProvider).getImage(imageId);
      if (mounted) setState(() => _image = image);
    } catch (e) {
      debugPrint('Failed to load image: $e');
    }
  }

  Future<void> _revealAndAdvance({
    required RoomModel room,
    required String userId,
    required int index,
  }) async {
    if (_isBusy) return;
    if (!room.availablePieceIndices.contains(index)) return;

    final difficulty = room.selectedDifficulty ?? Difficulty.easy;

    setState(() => _isBusy = true);
    try {
      await ref.read(roomServiceProvider).revealPiece(
            roomId: room.id,
            userId: userId,
            pieceIndex: index,
            difficulty: difficulty,
          );
      await ref.read(roomServiceProvider).skipPiecePlacement(roomId: room.id);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _scheduleBotTurn(RoomModel room) {
    final currentId = room.currentTurnUserId;
    if (currentId == null) return;

    final player = room.players[currentId];
    if (player == null || !player.isBot) return;
    if (room.availablePieceIndices.isEmpty) return;

    final key = '${room.id}-${room.currentTurnIndex}-${room.placedPieces.length}';
    if (_lastBotTurnKey == key) return;
    _lastBotTurnKey = key;

    final delayMs = 900 + _random.nextInt(1000);
    Future.delayed(Duration(milliseconds: delayMs), () async {
      if (!mounted) return;
      final latest = await ref.read(roomServiceProvider).watchRoom(room.id).first;
      if (latest == null) return;
      if (latest.currentTurnUserId != currentId) return;
      if (latest.availablePieceIndices.isEmpty) return;

      final index = latest.availablePieceIndices[
          _random.nextInt(latest.availablePieceIndices.length)];
      await _revealAndAdvance(room: latest, userId: currentId, index: index);
    });
  }

  Future<bool> _submitGuess(RoomModel room, String userId, String value) async {
    final image = _image;
    if (image == null || value.trim().isEmpty) return false;

    final correct = await ref.read(roomServiceProvider).submitAnswer(
          roomId: room.id,
          userId: userId,
          guess: value.trim(),
          image: image,
          difficulty: room.selectedDifficulty ?? Difficulty.easy,
        );

    if (!mounted) return correct;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(correct ? 'נכון!' : 'לא נכון, נסה שוב')),
    );
    return correct;
  }

  Future<void> _openGuessDialog(RoomModel room, String userId) async {
    final image = _image;
    if (image == null) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: Container(
                  width: min(420, constraints.maxWidth),
                  height: min(420, constraints.maxHeight),
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171B3D),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 62,
                        child: Stack(
                          children: [
                            const Center(
                              child: Text(
                                'מה המקום?',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                icon: const Icon(Icons.close_rounded, color: Colors.white54),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: LetterBankInput(
                          answer: image.answer,
                          enabled: true,
                          onComplete: (filled) async {
                            final correct = await _submitGuess(room, userId, filled);
                            if (correct && dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            return correct;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
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
        backgroundColor: const Color(0xFF0A0A1E),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF101A48), Color(0xFF0B0B24), Color(0xFF130A2F)],
            ),
          ),
          child: SafeArea(
            child: roomAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF8B6FFF)),
              ),
              error: (e, _) => Center(
                child: Text('שגיאה: $e', style: const TextStyle(color: Colors.white70)),
              ),
              data: (room) {
                if (room == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/home'));
                  return const SizedBox.shrink();
                }

                if (room.imageId.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _loadImage(room.imageId));
                }

                if (room.phase == GamePhase.finished) {
                  final winnerName = room.players[room.winnerId]?.name ?? 'שחקן';
                  return _FinishedView(winnerName: winnerName, onHome: () => context.go('/home'));
                }

                _scheduleBotTurn(room);

                final currentUserId = user?.id;
                final isMyTurn = currentUserId != null && room.currentTurnUserId == currentUserId;

                return _GameLayout(
                  room: room,
                  image: _image,
                  isMyTurn: isMyTurn,
                  isBusy: _isBusy,
                  onBack: () => context.go('/home'),
                  onReveal: currentUserId == null
                      ? null
                      : (index) => _revealAndAdvance(room: room, userId: currentUserId, index: index),
                  onGuess: currentUserId == null ? null : () => _openGuessDialog(room, currentUserId),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GameLayout extends StatelessWidget {
  final RoomModel room;
  final GameImageModel? image;
  final bool isMyTurn;
  final bool isBusy;
  final VoidCallback onBack;
  final void Function(int)? onReveal;
  final VoidCallback? onGuess;

  const _GameLayout({
    required this.room,
    required this.image,
    required this.isMyTurn,
    required this.isBusy,
    required this.onBack,
    required this.onReveal,
    required this.onGuess,
  });

  @override
  Widget build(BuildContext context) {
    final currentPlayer = room.players[room.currentTurnUserId];
    final revealedCount = room.placedPieces.length;
    final total = room.gridSize * room.gridSize;

    return Column(
      children: [
        _TopHud(
          code: room.code,
          players: room.sortedPlayers,
          currentPlayerId: room.currentTurnUserId,
          currentPlayerName: currentPlayer?.name ?? '',
          revealedText: '$revealedCount/$total',
          onBack: onBack,
        ),
        Expanded(
          child: Center(
            child: _GameBoard(
              gridSize: room.gridSize,
              revealedCells: room.revealedCells,
              availableCells: room.availablePieceIndices,
              imageUrl: image?.imageUrl,
              enabled: isMyTurn && !isBusy,
              onReveal: onReveal,
            ),
          ),
        ),
        _BottomActions(
          isMyTurn: isMyTurn,
          isBusy: isBusy,
          onGuess: onGuess,
        ),
      ],
    );
  }
}

class _TopHud extends StatelessWidget {
  final String code;
  final List<PlayerModel> players;
  final String? currentPlayerId;
  final String currentPlayerName;
  final String revealedText;
  final VoidCallback onBack;

  const _TopHud({
    required this.code,
    required this.players,
    required this.currentPlayerId,
    required this.currentPlayerName,
    required this.revealedText,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 19),
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  'תור: $currentPlayerName',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                revealedText,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: players.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final player = players[index];
                final active = player.id == currentPlayerId;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF6A43FF) : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: active ? Colors.white.withOpacity(0.28) : Colors.white.withOpacity(0.12),
                    ),
                  ),
                  child: Text(
                    '${player.name} ${player.score}⭐',
                    style: TextStyle(
                      color: active ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              code,
              style: TextStyle(
                color: Colors.white.withOpacity(0.18),
                fontSize: 10,
                letterSpacing: 3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameBoard extends StatelessWidget {
  final int gridSize;
  final List<int> revealedCells;
  final List<int> availableCells;
  final String? imageUrl;
  final bool enabled;
  final void Function(int)? onReveal;

  const _GameBoard({
    required this.gridSize,
    required this.revealedCells,
    required this.availableCells,
    required this.imageUrl,
    required this.enabled,
    required this.onReveal,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = min(constraints.maxWidth, constraints.maxHeight) * 0.96;
        return SizedBox.square(
          dimension: side,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl == null)
                  Image.asset(_kTileEmpty, fit: BoxFit.cover)
                else if (imageUrl!.startsWith('assets/'))
                  Image.asset(imageUrl!, fit: BoxFit.cover)
                else
                  CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover),
                GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridSize,
                    mainAxisSpacing: 0,
                    crossAxisSpacing: 0,
                  ),
                  itemCount: gridSize * gridSize,
                  itemBuilder: (context, index) {
                    final isRevealed = revealedCells.contains(index);
                    if (isRevealed) return const SizedBox.expand();
                    final canReveal = enabled && availableCells.contains(index) && onReveal != null;
                    return GestureDetector(
                      onTap: canReveal ? () => onReveal!(index) : null,
                      child: Opacity(
                        opacity: enabled ? 1 : 0.82,
                        child: Image.asset(_kTileClosed, fit: BoxFit.cover),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BottomActions extends StatelessWidget {
  final bool isMyTurn;
  final bool isBusy;
  final VoidCallback? onGuess;

  const _BottomActions({required this.isMyTurn, required this.isBusy, required this.onGuess});

  @override
  Widget build(BuildContext context) {
    final label = isMyTurn ? 'ניחוש' : 'ממתין לתור';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isMyTurn ? 'בחר משבצת או נסה לנחש' : 'שחקן אחר חושף משבצת',
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: isMyTurn && !isBusy ? onGuess : null,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: isMyTurn && !isBusy ? 1 : 0.55,
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9B7EFF), Color(0xFF6B44F8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7B5FFF).withOpacity(0.42),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: isBusy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                        )
                      : Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinishedView extends StatelessWidget {
  final String winnerName;
  final VoidCallback onHome;

  const _FinishedView({required this.winnerName, required this.onHome});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 84)),
            const SizedBox(height: 18),
            Text(
              '$winnerName ניצח!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 30),
            FilledButton(
              onPressed: onHome,
              child: const Text('חזרה למסך הראשי'),
            ),
          ],
        ),
      ),
    );
  }
}
