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
import '../../widgets/game/animated_reward.dart';
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

  // Turn-reveal tracking for human guess gate
  bool _hasRevealedThisTurn = false;
  int _revealedAtTurnIndex = -1;
  bool _hasGuessedThisTurn = false;

  // Guess-event banner
  int _lastShownGuessCount = -1;
  Map<String, dynamic>? _currentBanner;
  bool _showBanner = false;

  // Bot typing simulation
  bool _showBotTyping = false;
  String _botTypingName = '';
  String _botTypingText = '';

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

  // Human reveals a tile: stores it but does NOT advance the turn.
  // Guess button becomes active; player then guesses or taps Skip.
  Future<void> _humanRevealTile({
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
        if (mounted) {
          setState(() {
            _hasRevealedThisTurn = true;
            _revealedAtTurnIndex = room.currentTurnIndex;
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _skipTurn(RoomModel room) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await ref.read(roomServiceProvider).skipPiecePlacement(roomId: room.id);
      if (mounted) setState(() => _hasRevealedThisTurn = false);
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

    // Dedup on turn index only — prevent re-scheduling mid-turn.
    final key = '${room.id}-${room.currentTurnIndex}';
    if (_lastBotTurnKey == key) return;
    _lastBotTurnKey = key;

    final delayMs = 2000 + _random.nextInt(1201); // 2000–3200 ms
    Future.delayed(Duration(milliseconds: delayMs), () async {
      if (!mounted) return;
      final snapshot =
          await ref.read(roomServiceProvider).watchRoom(room.id).first;
      if (snapshot == null) return;
      if (snapshot.phase == GamePhase.finished) return;
      if (snapshot.currentTurnUserId != currentId) return;
      if (snapshot.availablePieceIndices.isEmpty) return;

      // Step 1: Always reveal a tile first.
      final idx = snapshot.availablePieceIndices[
          _random.nextInt(snapshot.availablePieceIndices.length)];
      final isLastTile = snapshot.availablePieceIndices.length == 1;
      final difficulty = snapshot.selectedDifficulty ?? Difficulty.easy;

      await ref.read(roomServiceProvider).revealPiece(
            roomId: snapshot.id,
            userId: currentId,
            pieceIndex: idx,
            difficulty: difficulty,
          );

      if (isLastTile) {
        if (mounted) {
          await ref.read(roomServiceProvider).endGameNoWinner(snapshot.id);
        }
        return;
      }

      if (!mounted) return;

      // Step 2: Fetch updated state, then decide whether to guess.
      final afterReveal =
          await ref.read(roomServiceProvider).watchRoom(room.id).first;
      if (afterReveal == null || afterReveal.phase == GamePhase.finished) return;

      final afterTotal = afterReveal.gridSize * afterReveal.gridSize;
      final afterRevealed = afterReveal.placedPieces.length;
      final afterRatio =
          afterTotal > 0 ? afterRevealed / afterTotal : 0.0;

      // Bots never guess before 50 % revealed or fewer than 5 tiles.
      double attemptChance;
      double correctChance;
      if (afterRevealed < 5 || afterRatio < 0.50) {
        attemptChance = 0.0;
        correctChance = 0.0;
      } else if (afterRatio >= 0.75) {
        attemptChance = 0.45;
        correctChance = 0.55;
      } else {
        // 50 %–75 % revealed
        attemptChance = 0.25;
        correctChance = 0.30;
      }

      final shouldGuess =
          _image != null && _random.nextDouble() < attemptChance;

      if (shouldGuess) {
        await _performBotGuess(afterReveal, currentId, correctChance);
        // submitAnswer advances turn on wrong; game ends on correct.
      } else {
        if (mounted) {
          await ref
              .read(roomServiceProvider)
              .skipPiecePlacement(roomId: afterReveal.id);
        }
      }
    });
  }

  Future<void> _simulateBotTyping(String botName, String word) async {
    if (!mounted) return;
    setState(() {
      _showBotTyping = true;
      _botTypingName = botName;
      _botTypingText = '';
    });

    // Brief "thinking" pause before typing starts.
    await Future.delayed(Duration(milliseconds: 1200 + _random.nextInt(801)));

    for (int i = 1; i <= word.length; i++) {
      if (!mounted) return;
      setState(() => _botTypingText = word.substring(0, i));
      await Future.delayed(Duration(milliseconds: 220 + _random.nextInt(121)));
    }

    // Pause on the completed word before submitting.
    await Future.delayed(const Duration(milliseconds: 350));
  }

  Future<void> _performBotGuess(
      RoomModel room, String botId, double correctChance) async {
    final image = _image;
    if (image == null) return;

    final isCorrect = _random.nextDouble() < correctChance;
    final guess = isCorrect ? image.answer : _realisticWrongGuess(image.answer);

    final botName = room.players[botId]?.name ?? 'בוט';
    await _simulateBotTyping(botName, guess);

    if (!mounted) return;
    setState(() => _showBotTyping = false);

    await ref.read(roomServiceProvider).submitAnswer(
          roomId: room.id,
          userId: botId,
          guess: guess,
          image: image,
          difficulty: room.selectedDifficulty ?? Difficulty.easy,
        );
    // Turn advances via submitAnswer: wrong → nextTurnIndex; correct → game ends.
  }

  static const _realisticGuessPool = [
    'מצדה',
    'הכותל',
    'ים המלח',
    'אילת',
    'החרמון',
    'קיסריה',
    'עכו',
    'יפו',
    'מכתש רמון',
    'הגנים הבהאיים',
    'נהריה',
    'בית שאן',
    'ראש הנקרה',
    'חיפה',
    'הכנרת',
  ];

  String _realisticWrongGuess(String correctAnswer) {
    final norm = normalizeHebrewFinals(correctAnswer.trim());
    final candidates = _realisticGuessPool
        .where((g) => normalizeHebrewFinals(g) != norm)
        .toList();
    if (candidates.isEmpty) return 'מצדה';
    return candidates[_random.nextInt(candidates.length)];
  }

  Future<bool> _submitGuess(RoomModel room, String userId, String value) async {
    final image = _image;
    if (image == null || value.trim().isEmpty) return false;

    // Lock out further guesses for this turn immediately.
    setState(() => _hasGuessedThisTurn = true);

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
              final inputHeight = min(400.0, constraints.maxHeight - 60);
              return Center(
                child: Container(
                  width: min(420.0, constraints.maxWidth),
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171B3D),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 44,
                        child: Stack(
                          children: [
                            const Center(
                              child: Text(
                                'מה המקום?',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
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
                            if (dialogContext.mounted) {
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
            top: false,
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

                // Reset per-turn flags when turn advances.
                if (room.currentTurnIndex != _revealedAtTurnIndex &&
                    (_hasRevealedThisTurn || _hasGuessedThisTurn)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _hasRevealedThisTurn = false;
                        _hasGuessedThisTurn = false;
                      });
                    }
                  });
                }

                // Trigger guess-event banner when a new guess is stored.
                if (room.guessCount != _lastShownGuessCount &&
                    room.lastGuessEvent != null) {
                  _lastShownGuessCount = room.guessCount;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() {
                      _currentBanner = room.lastGuessEvent;
                      _showBanner = true;
                      _showBotTyping = false; // result replaces typing banner
                    });
                    Future.delayed(const Duration(milliseconds: 3500), () {
                      if (mounted) setState(() => _showBanner = false);
                    });
                  });
                }

                final currentUserId = user?.id;
                final isMyTurn = currentUserId != null &&
                    room.currentTurnUserId == currentUserId;
                final myCoins = currentUserId != null
                    ? (room.players[currentUserId]?.score ?? 0)
                    : 0;
                final myLetterCards = currentUserId != null
                    ? (room.players[currentUserId]?.letterCards ?? 0)
                    : 0;
                final canGuessNow = isMyTurn &&
                    _hasRevealedThisTurn &&
                    !_hasGuessedThisTurn &&
                    room.currentTurnIndex == _revealedAtTurnIndex;

                return _GameLayout(
                  room: room,
                  image: _image,
                  isMyTurn: isMyTurn,
                  isBusy: _isBusy,
                  myCoins: myCoins,
                  myLetterCards: myLetterCards,
                  canGuessNow: canGuessNow,
                  showBanner: _showBanner,
                  bannerEvent: _currentBanner,
                  showBotTyping: _showBotTyping,
                  botTypingName: _botTypingName,
                  botTypingText: _botTypingText,
                  onBack: () => context.go('/home'),
                  onReveal: currentUserId == null
                      ? null
                      : (index) => _humanRevealTile(
                          room: room,
                          userId: currentUserId,
                          index: index),
                  onGuess: canGuessNow
                      ? () => _openGuessDialog(room, currentUserId!)
                      : null,
                  onSkip: (isMyTurn && canGuessNow)
                      ? () => _skipTurn(room)
                      : null,
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
  final int myLetterCards;
  final bool canGuessNow;
  final bool showBanner;
  final Map<String, dynamic>? bannerEvent;
  final bool showBotTyping;
  final String botTypingName;
  final String botTypingText;
  final VoidCallback onBack;
  final void Function(int)? onReveal;
  final VoidCallback? onGuess;
  final VoidCallback? onSkip;

  const _GameLayout({
    required this.room,
    required this.image,
    required this.isMyTurn,
    required this.isBusy,
    required this.myCoins,
    required this.myLetterCards,
    required this.canGuessNow,
    required this.showBanner,
    required this.bannerEvent,
    required this.showBotTyping,
    required this.botTypingName,
    required this.botTypingText,
    required this.onBack,
    required this.onReveal,
    required this.onGuess,
    required this.onSkip,
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
          myLetterCards: myLetterCards,
          onBack: onBack,
        ),
        if (showBotTyping)
          _BotTypingBanner(botName: botTypingName, typedSoFar: botTypingText)
        else if (showBanner && bannerEvent != null)
          _GuessBanner(event: bannerEvent!, players: room.players),
        Expanded(
          child: Center(
            child: _GameBoard(
              gridSize: room.gridSize,
              revealedCells: room.revealedCells,
              availableCells: room.availablePieceIndices,
              imageUrl: image?.imageUrl,
              enabled: isMyTurn && !isBusy && !canGuessNow,
              glowEnabled: isMyTurn && !isBusy && !canGuessNow,
              onReveal: onReveal,
            ),
          ),
        ),
        _AnswerSlots(answer: image?.answer ?? ''),
        _BottomActions(
          isMyTurn: isMyTurn,
          isBusy: isBusy,
          canGuessNow: canGuessNow,
          revealedCount: revealedCount,
          totalTiles: total,
          onGuess: onGuess,
          onSkip: onSkip,
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
  final int myLetterCards;
  final VoidCallback onBack;

  const _TopHud({
    required this.code,
    required this.players,
    required this.currentPlayerId,
    required this.currentPlayerName,
    required this.revealedText,
    required this.myCoins,
    required this.myLetterCards,
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
              if (myLetterCards > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Text(
                    '🔤 ×$myLetterCards',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ],
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
              fontWeight: FontWeight.w900,
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
  final bool glowEnabled;
  final void Function(int)? onReveal;

  const _GameBoard({
    required this.gridSize,
    required this.revealedCells,
    required this.availableCells,
    required this.imageUrl,
    required this.enabled,
    required this.glowEnabled,
    required this.onReveal,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tile =
            (min(constraints.maxWidth, constraints.maxHeight) * 0.96 / gridSize)
                .floorToDouble();
        final side = tile * gridSize;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: glowEnabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF8B6FFF).withOpacity(0.40),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ]
                : [],
          ),
          child: SizedBox.square(
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
                    CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const _ImageFallback(),
                    ),
                  for (var index = 0; index < gridSize * gridSize; index++)
                    if (!revealedCells.contains(index))
                      _ClosedTileOverlay(
                        index: index,
                        gridSize: gridSize,
                        tileSize: tile,
                        glowEnabled: glowEnabled,
                        enabled: enabled &&
                            availableCells.contains(index) &&
                            onReveal != null,
                        onTap: onReveal == null ? null : () => onReveal!(index),
                      ),
                ],
              ),
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
  final bool glowEnabled;
  final VoidCallback? onTap;

  const _ClosedTileOverlay({
    required this.index,
    required this.gridSize,
    required this.tileSize,
    required this.enabled,
    required this.glowEnabled,
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
          foregroundDecoration: glowEnabled
              ? BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF8B6FFF).withOpacity(0.42),
                    width: 1,
                  ),
                )
              : null,
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


class _AnswerSlots extends StatelessWidget {
  final String answer;

  const _AnswerSlots({required this.answer});

  @override
  Widget build(BuildContext context) {
    final chars = answer.trim().characters.toList();
    if (chars.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.rtl,
          children: [
            for (final char in chars)
              if (char.trim().isEmpty)
                const SizedBox(width: 12)
              else
                Container(
                  width: 28,
                  height: 34,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.28),
                      width: 1,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final bool isMyTurn;
  final bool isBusy;
  final bool canGuessNow;
  final int revealedCount;
  final int totalTiles;
  final VoidCallback? onGuess;
  final VoidCallback? onSkip;

  const _BottomActions({
    required this.isMyTurn,
    required this.isBusy,
    required this.canGuessNow,
    required this.revealedCount,
    required this.totalTiles,
    required this.onGuess,
    required this.onSkip,
  });

  int _reward() => _calcReward(revealedCount, totalTiles);

  int _penalty(int reward) => (reward * 0.15).round();

  @override
  Widget build(BuildContext context) {
    final reward = _reward();
    final penalty = _penalty(reward);
    final guessActive = canGuessNow && !isBusy;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              Expanded(
                flex: 7,
                child: _ActionButton(
                  label: canGuessNow
                      ? 'נחש'
                      : isMyTurn
                          ? 'בחר משבצת'
                          : 'ממתין לתור',
                  isPrimary: true,
                  isActive: guessActive || (isMyTurn && !canGuessNow),
                  glow: guessActive,
                  onTap: guessActive ? onGuess : null,
                  reward: canGuessNow ? reward : null,
                  penalty: canGuessNow ? penalty : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: _ActionButton(
                  label: 'דלג',
                  isPrimary: false,
                  isActive: canGuessNow && !isBusy,
                  glow: false,
                  onTap: canGuessNow && !isBusy ? onSkip : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final bool isActive;
  final bool glow;
  final VoidCallback? onTap;
  final int? reward;
  final int? penalty;

  const _ActionButton({
    required this.label,
    required this.isPrimary,
    required this.isActive,
    required this.glow,
    required this.onTap,
    this.reward,
    this.penalty,
  });

  @override
  Widget build(BuildContext context) {
    final hasReward = reward != null && penalty != null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: isActive ? 1.0 : 0.42,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 50,
          decoration: BoxDecoration(
            gradient: isPrimary
                ? const LinearGradient(
                    colors: [Color(0xFF9B7EFF), Color(0xFF6B44F8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isPrimary ? null : Colors.white.withOpacity(0.045),
            borderRadius: BorderRadius.circular(18),
            border: isPrimary
                ? null
                : Border.all(
                    color: Colors.white.withOpacity(isActive ? 0.28 : 0.12),
                    width: 1,
                  ),
            boxShadow: glow
                ? [
                    BoxShadow(
                      color: const Color(0xFF7B5FFF).withOpacity(0.46),
                      blurRadius: 20,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: isPrimary && label == 'נחש' && hasReward
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'נחש',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedReward(
                              key: ValueKey('penalty_$penalty'),
                              value: penalty!,
                              isPositive: false,
                            ),
                            const SizedBox(width: 12),
                            AnimatedReward(
                              key: ValueKey('reward_$reward'),
                              value: reward!,
                              isPositive: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      style: TextStyle(
                        color: isPrimary ? Colors.white : Colors.white70,
                        fontSize: isPrimary ? 21 : 18,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _GuessBanner extends StatelessWidget {
  final Map<String, dynamic> event;
  final Map<String, PlayerModel> players;

  const _GuessBanner({required this.event, required this.players});

  @override
  Widget build(BuildContext context) {
    final playerId = event['playerId'] as String? ?? '';
    final guess = event['guess'] as String? ?? '';
    final isCorrect = event['isCorrect'] as bool? ?? false;
    final playerName = players[playerId]?.name ?? playerId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isCorrect
              ? const Color(0xFF1B5E20).withOpacity(0.92)
              : const Color(0xFF7F0000).withOpacity(0.88),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCorrect
                ? Colors.green.shade400.withOpacity(0.5)
                : Colors.red.shade400.withOpacity(0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                '$playerName ניחש: "$guess"',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              isCorrect ? 'נכון! ✓' : 'לא נכון ✗',
              style: TextStyle(
                color: isCorrect ? Colors.greenAccent : Colors.redAccent,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
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
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) =>
                                            const _ImageFallback(),
                                      ),
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

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A3E),
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.white24,
          size: 48,
        ),
      ),
    );
  }
}

class _BotTypingBanner extends StatelessWidget {
  final String botName;
  final String typedSoFar;

  const _BotTypingBanner({
    required this.botName,
    required this.typedSoFar,
  });

  @override
  Widget build(BuildContext context) {
    final isTyping = typedSoFar.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF751010).withOpacity(0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.redAccent.withOpacity(0.45)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isTyping ? '$botName מקליד...' : '$botName חושב...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            if (isTyping)
              Text(
                '"$typedSoFar" |',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              )
            else
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
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
