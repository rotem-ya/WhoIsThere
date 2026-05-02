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

// Shared reward formula used by the button widget and bot logic.
int _calcReward(int revealedCount, int total) {
  if (total == 0) return 100;
  return (100 - revealedCount / total * 80).clamp(20.0, 100.0).round();
}

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
    final isLastTile = room.availablePieceIndices.length == 1;

    setState(() => _isBusy = true);
    try {
      await ref.read(roomServiceProvider).revealPiece(
            roomId: room.id,
            userId: userId,
            pieceIndex: index,
            difficulty: difficulty,
          );
      if (isLastTile) {
        await ref.read(roomServiceProvider).endGameNoWinner(room.id);
      } else {
        await ref.read(roomServiceProvider).skipPiecePlacement(roomId: room.id);
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _scheduleBotTurn(RoomModel room) {
    final currentId = room.currentTurnUserId;
    if (currentId == null) return;

    final player = room.players[currentId];
    if (player == null || !player.isBot) return;

    final total = room.gridSize * room.gridSize;
    final revealedCount = room.placedPieces.length;
    final revealedRatio = total > 0 ? revealedCount / total : 0.0;

    // Bot can guess only after 3 tiles AND ratio >= 30%.
    final canConsiderGuessing = revealedCount >= 3 && revealedRatio >= 0.30;
    if (!canConsiderGuessing && room.availablePieceIndices.isEmpty) return;

    final key =
        '${room.id}-${room.currentTurnIndex}-$revealedCount';
    if (_lastBotTurnKey == key) return;
    _lastBotTurnKey = key;

    final delayMs = 900 + _random.nextInt(701); // 900–1600 ms
    Future.delayed(Duration(milliseconds: delayMs), () async {
      if (!mounted) return;
      final latest =
          await ref.read(roomServiceProvider).watchRoom(room.id).first;
      if (latest == null) return;
      if (latest.phase == GamePhase.finished) return;
      if (latest.currentTurnUserId != currentId) return;

      final latestTotal = latest.gridSize * latest.gridSize;
      final latestRevealed = latest.placedPieces.length;
      final latestRatio =
          latestTotal > 0 ? latestRevealed / latestTotal : 0.0;

      // Tiered attempt / correctness probabilities.
      // No guessing before 3 tiles revealed or ratio < 30%.
      double attemptChance;
      double correctChance;
      if (latestRevealed < 3 || latestRatio < 0.30) {
        attemptChance = 0.0;
        correctChance = 0.0;
      } else if (latestRatio >= 0.75) {
        attemptChance = 0.65;
        correctChance = 0.70;
      } else if (latestRatio >= 0.50) {
        attemptChance = 0.45;
        correctChance = 0.55;
      } else {
        // 30 %–50 % revealed
        attemptChance = 0.25;
        correctChance = 0.35;
      }

      final shouldGuess =
          _image != null && _random.nextDouble() < attemptChance;

      if (shouldGuess) {
        await _performBotGuess(latest, currentId, correctChance);
      } else if (latest.availablePieceIndices.isNotEmpty) {
        final index = latest.availablePieceIndices[
            _random.nextInt(latest.availablePieceIndices.length)];
        await _revealAndAdvance(room: latest, userId: currentId, index: index);
      }
    });
  }

  Future<void> _performBotGuess(
      RoomModel room, String botId, double correctChance) async {
    final image = _image;
    if (image == null || _isBusy) return;

    setState(() => _isBusy = true);
    try {
      final isCorrect = _random.nextDouble() < correctChance;
      final guess =
          isCorrect ? image.answer : _randomWrongGuess(image.answer);

      final correct = await ref.read(roomServiceProvider).submitAnswer(
            roomId: room.id,
            userId: botId,
            guess: guess,
            image: image,
            difficulty: room.selectedDifficulty ?? Difficulty.easy,
          );

      // After a wrong guess advance the turn so the game doesn't stall.
      if (!correct && mounted) {
        await ref
            .read(roomServiceProvider)
            .skipPiecePlacement(roomId: room.id);
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String _randomWrongGuess(String correctAnswer) {
    const letters = 'אבגדהוזחטיכלמנסעפצקרשת';
    final length = correctAnswer.replaceAll(' ', '').length;
    String guess;
    do {
      guess = List.generate(
        length,
        (_) => letters[_random.nextInt(letters.length)],
      ).join();
    } while (normalizeHebrewFinals(guess) ==
        normalizeHebrewFinals(correctAnswer));
    return guess;
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
              final inputHeight = min(380.0, constraints.maxHeight - 84);
              return Center(
                child: Container(
                  width: min(420.0, constraints.maxWidth),
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171B3D),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                      SizedBox(
                        height: inputHeight,
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
                  final hasWinner =
                      room.winnerId != null && room.winnerId!.isNotEmpty;
                  if (hasWinner) {
                    final winnerName =
                        room.players[room.winnerId]?.name ?? 'שחקן';
                    return _FinishedView(
                        winnerName: winnerName,
                        onHome: () => context.go('/home'));
                  }
                  return _NoWinnerView(
                    answer: _image?.answer ?? '',
                    imageUrl: _image?.imageUrl,
                    onHome: () => context.go('/home'),
                  );
                }

                _scheduleBotTurn(room);

                final currentUserId = user?.id;
                final isMyTurn = currentUserId != null && room.currentTurnUserId == currentUserId;
                final myCoins = currentUserId != null
                    ? (room.players[currentUserId]?.score ?? 0)
                    : 0;

                return _GameLayout(
                  room: room,
                  image: _image,
                  isMyTurn: isMyTurn,
                  isBusy: _isBusy,
                  myCoins: myCoins,
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
  final int myCoins;
  final VoidCallback onBack;
  final void Function(int)? onReveal;
  final VoidCallback? onGuess;

  const _GameLayout({
    required this.room,
    required this.image,
    required this.isMyTurn,
    required this.isBusy,
    required this.myCoins,
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
          myCoins: myCoins,
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
          revealedCount: revealedCount,
          totalTiles: total,
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
  final int myCoins;
  final VoidCallback onBack;

  const _TopHud({
    required this.code,
    required this.players,
    required this.currentPlayerId,
    required this.currentPlayerName,
    required this.revealedText,
    required this.myCoins,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white70, size: 18),
                onPressed: onBack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              Expanded(
                child: Text(
                  'תור: $currentPlayerName',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _CoinBadge(amount: myCoins),
              const SizedBox(width: 6),
              Text(
                revealedText,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: players.length,
              separatorBuilder: (_, __) => const SizedBox(width: 5),
              itemBuilder: (context, index) {
                final player = players[index];
                final active = player.id == currentPlayerId;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF6A43FF)
                        : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: active
                          ? Colors.white.withOpacity(0.28)
                          : Colors.white.withOpacity(0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 80),
                        child: Text(
                          player.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: active ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight:
                                active ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${player.score}⭐',
                        style: TextStyle(
                          color: active ? Colors.white70 : Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 1),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              code,
              style: TextStyle(
                color: Colors.white.withOpacity(0.15),
                fontSize: 9,
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

class _CoinBadge extends StatelessWidget {
  final int amount;

  const _CoinBadge({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107).withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFFFC107).withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 12, height: 1)),
          const SizedBox(width: 2),
          Text(
            '$amount',
            style: const TextStyle(
              color: Color(0xFFFFC107),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1,
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
        // Floor tile to a whole logical pixel so tile * gridSize == side exactly,
        // eliminating sub-pixel gaps between Positioned tiles.
        final tile = (min(constraints.maxWidth, constraints.maxHeight) * 0.96 / gridSize).floorToDouble();
        final side = tile * gridSize;

        return SizedBox.square(
          dimension: side,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl == null)
                  Image.asset(_kTileEmpty, fit: BoxFit.cover)
                else if (imageUrl!.startsWith('assets/'))
                  Image.asset(imageUrl!, fit: BoxFit.cover)
                else
                  CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover),
                for (var index = 0; index < gridSize * gridSize; index++)
                  if (!revealedCells.contains(index))
                    _ClosedTileOverlay(
                      index: index,
                      gridSize: gridSize,
                      tileSize: tile,
                      enabled: enabled &&
                          availableCells.contains(index) &&
                          onReveal != null,
                      onTap: onReveal == null ? null : () => onReveal!(index),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ClosedTileOverlay extends StatelessWidget {
  final int index;
  final int gridSize;
  final double tileSize;
  final bool enabled;
  final VoidCallback? onTap;

  const _ClosedTileOverlay({
    required this.index,
    required this.gridSize,
    required this.tileSize,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = index ~/ gridSize;
    final col = index % gridSize;

    return Positioned(
      left: col * tileSize,
      top: row * tileSize,
      width: tileSize,
      height: tileSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          color: const Color(0xFF15183D),
          child: ClipRect(
            child: Transform.scale(
              scale: 1.08,
              child: Image.asset(
                _kTileClosed,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final bool isMyTurn;
  final bool isBusy;
  final int revealedCount;
  final int totalTiles;
  final VoidCallback? onGuess;

  const _BottomActions({
    required this.isMyTurn,
    required this.isBusy,
    required this.revealedCount,
    required this.totalTiles,
    required this.onGuess,
  });

  int _reward() => _calcReward(revealedCount, totalTiles);

  int _penalty(int reward) => (reward * 0.15).round();

  @override
  Widget build(BuildContext context) {
    final reward = _reward();
    final penalty = _penalty(reward);
    final hiddenTiles = totalTiles - revealedCount;

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
          if (hiddenTiles == 1) ...[
            const SizedBox(height: 4),
            const Text(
              'הזדמנות אחרונה לנחש!',
              style: TextStyle(
                color: Color(0xFFFFCA28),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
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
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.4),
                        )
                      : isMyTurn
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'נחש',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🪙',
                                        style: TextStyle(
                                            fontSize: 13, height: 1)),
                                    const SizedBox(width: 3),
                                    Text(
                                      '+$reward',
                                      style: const TextStyle(
                                        color: Color(0xFF66BB6A),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    const Text('❌',
                                        style: TextStyle(
                                            fontSize: 11, height: 1)),
                                    const SizedBox(width: 3),
                                    Text(
                                      '-$penalty',
                                      style: const TextStyle(
                                        color: Color(0xFFEF5350),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : const Text(
                              'ממתין לתור',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
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

class _NoWinnerView extends StatefulWidget {
  final String answer;
  final String? imageUrl;
  final VoidCallback onHome;

  const _NoWinnerView({
    required this.answer,
    required this.imageUrl,
    required this.onHome,
  });

  @override
  State<_NoWinnerView> createState() => _NoWinnerViewState();
}

class _NoWinnerViewState extends State<_NoWinnerView> {
  bool _overlayVisible = false;
  bool _line1Visible = false;
  bool _line2Visible = false;
  bool _line3Visible = false;
  double _imageScale = 1.0;

  @override
  void initState() {
    super.initState();
    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _overlayVisible = true;
      _imageScale = 1.05;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _line1Visible = true);

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _line2Visible = true);

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _line3Visible = true);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imgSize = min(
          constraints.maxWidth - 32,
          min(constraints.maxHeight * 0.58, 280.0),
        );
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.imageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox.square(
                          dimension: imgSize,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              AnimatedScale(
                                scale: _imageScale,
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOut,
                                child: widget.imageUrl!.startsWith('assets/')
                                    ? Image.asset(widget.imageUrl!,
                                        fit: BoxFit.cover)
                                    : CachedNetworkImage(
                                        imageUrl: widget.imageUrl!,
                                        fit: BoxFit.cover),
                              ),
                              AnimatedOpacity(
                                opacity: _overlayVisible ? 0.4 : 0.0,
                                duration: const Duration(milliseconds: 400),
                                child: const ColoredBox(color: Colors.black),
                              ),
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedOpacity(
                                        opacity: _line1Visible ? 1.0 : 0.0,
                                        duration:
                                            const Duration(milliseconds: 300),
                                        child: const Text(
                                          'אף אחד לא ניחש בזמן',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                            shadows: [
                                              Shadow(
                                                  color: Colors.black87,
                                                  blurRadius: 8)
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      AnimatedOpacity(
                                        opacity: _line2Visible ? 1.0 : 0.0,
                                        duration:
                                            const Duration(milliseconds: 300),
                                        child: const Text(
                                          'התשובה היא...',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            shadows: [
                                              Shadow(
                                                  color: Colors.black87,
                                                  blurRadius: 8)
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      AnimatedOpacity(
                                        opacity: _line3Visible ? 1.0 : 0.0,
                                        duration:
                                            const Duration(milliseconds: 300),
                                        child: Text(
                                          widget.answer,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Color(0xFF9B7EFF),
                                            fontSize: 26,
                                            fontWeight: FontWeight.w900,
                                            shadows: [
                                              Shadow(
                                                  color: Colors.black87,
                                                  blurRadius: 12)
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      AnimatedOpacity(
                        opacity: _line1Visible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: const Text(
                          'אף אחד לא ניחש בזמן',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedOpacity(
                        opacity: _line2Visible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: const Text(
                          'התשובה היא...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedOpacity(
                        opacity: _line3Visible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          widget.answer,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF9B7EFF),
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 180,
                      child: FilledButton(
                        onPressed: widget.onHome,
                        child: const Text('משחק חדש'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
