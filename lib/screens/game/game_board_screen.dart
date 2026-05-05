import 'widgets/game_layout.dart';
import 'dart:async';
import 'dart:math' show Random, min, max;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/game_constants.dart';
import '../../models/game_image_model.dart';
import '../../models/room_model.dart';
import '../../providers/providers.dart';
import '../../widgets/game/letter_bank_input.dart';

class GameBoardScreen extends ConsumerStatefulWidget {
  final String roomId;

  const GameBoardScreen({super.key, required this.roomId});

  @override
  ConsumerState<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends ConsumerState<GameBoardScreen> {
  final _random = Random();

  GameImageModel? _image;
  String _loadedImageId = '';
  String _lastBotTurnKey = '';
  bool _isBusy = false;
  bool _isGuessModeOpen = false;

  bool _hasRevealedThisTurn = false;
  int _revealedAtTurnIndex = -1;
  bool _hasGuessedThisTurn = false;

  int _lastShownGuessCount = -1;
  Map<String, dynamic>? _currentBanner;
  bool _showBanner = false;

  bool _showBotTyping = false;
  String _botTypingName = '';
  String _botTypingText = '';

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

  Future<void> _humanRevealTile({
    required RoomModel room,
    required String userId,
    required int index,
  }) async {
    if (_isBusy || _isGuessModeOpen) return;
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
      } else if (mounted) {
        setState(() {
          _hasRevealedThisTurn = true;
          _revealedAtTurnIndex = room.currentTurnIndex;
        });
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _skipTurn(RoomModel room) async {
    if (_isBusy || _isGuessModeOpen) return;
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

    final key = '${room.id}-${room.currentTurnIndex}';
    if (_lastBotTurnKey == key) return;
    _lastBotTurnKey = key;

    final delayMs = 2000 + _random.nextInt(1201);
    Future.delayed(Duration(milliseconds: delayMs), () async {
      if (!mounted) return;
      final snapshot = await ref.read(roomServiceProvider).watchRoom(room.id).first;
      if (snapshot == null) return;
      if (snapshot.phase == GamePhase.finished) return;
      if (snapshot.currentTurnUserId != currentId) return;
      if (snapshot.availablePieceIndices.isEmpty) return;

      final idx = snapshot.availablePieceIndices[_random.nextInt(snapshot.availablePieceIndices.length)];
      final isLastTile = snapshot.availablePieceIndices.length == 1;
      final difficulty = snapshot.selectedDifficulty ?? Difficulty.easy;

      await ref.read(roomServiceProvider).revealPiece(
            roomId: snapshot.id,
            userId: currentId,
            pieceIndex: idx,
            difficulty: difficulty,
          );

      if (isLastTile) {
        if (mounted) await ref.read(roomServiceProvider).endGameNoWinner(snapshot.id);
        return;
      }

      if (!mounted) return;
      final afterReveal = await ref.read(roomServiceProvider).watchRoom(room.id).first;
      if (afterReveal == null || afterReveal.phase == GamePhase.finished) return;

      final shouldAttemptGuess = _image != null && _random.nextDouble() < 0.50;
      if (shouldAttemptGuess) {
        final didSubmit = await _performBotGuess(afterReveal, currentId);
        if (didSubmit) return;
      }

      if (mounted) {
        await ref.read(roomServiceProvider).skipPiecePlacement(roomId: afterReveal.id);
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

    await Future.delayed(Duration(milliseconds: 1200 + _random.nextInt(801)));

    for (int i = 1; i <= word.length; i++) {
      if (!mounted) return;
      setState(() => _botTypingText = word.substring(0, i));
      await Future.delayed(Duration(milliseconds: 220 + _random.nextInt(121)));
    }

    await Future.delayed(const Duration(milliseconds: 350));
  }

  Future<bool> _performBotGuess(RoomModel room, String botId) async {
    final image = _image;
    if (image == null) return false;

    final guess = _buildBotGuess(room: room, image: image);
    if (guess == null) return false;

    final botName = room.players[botId]?.name ?? 'בוט';
    await _simulateBotTyping(botName, guess);

    if (!mounted) return false;
    setState(() => _showBotTyping = false);

    await ref.read(roomServiceProvider).submitAnswer(
          roomId: room.id,
          userId: botId,
          guess: guess,
          image: image,
          difficulty: room.selectedDifficulty ?? Difficulty.easy,
        );
    return true;
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
    'ירושלים',
    'תל אביב',
    'באר שבע',
    'רמת הגולן',
    'עין גדי',
    'תמנע',
    'זכרון יעקב',
    'מוזיאון ישראל',
    'נחל עמוד',
    'פארק הירקון',
    'גן סאקר',
  ];

  String? _buildBotGuess({required RoomModel room, required GameImageModel image}) {
    final total = room.gridSize * room.gridSize;
    final revealed = room.placedPieces.length;
    final revealedRatio = total > 0 ? revealed / total : 0.0;
    final canBeCorrect = revealedRatio >= 0.90 && _random.nextDouble() < 0.01;

    if (canBeCorrect) return image.answer;
    return _realisticWrongGuess(image.answer);
  }

  int _normalizedGuessLength(String value) {
    return normalizeHebrewFinals(value.trim()).characters.length;
  }

  String? _realisticWrongGuess(String correctAnswer) {
    final norm = normalizeHebrewFinals(correctAnswer.trim());
    final targetLength = _normalizedGuessLength(correctAnswer);
    final candidates = _realisticGuessPool.where((guess) {
      final normalizedGuess = normalizeHebrewFinals(guess.trim());
      return normalizedGuess != norm && normalizedGuess.characters.length == targetLength;
    }).toList();

    if (candidates.isEmpty) return null;
    return candidates[_random.nextInt(candidates.length)];
  }

  Future<bool> _submitGuess(RoomModel room, String userId, String value) async {
    final image = _image;
    if (image == null || value.trim().isEmpty) return false;

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
      SnackBar(content: Text(correct ? 'נכון!' : 'לא נכון, התור עובר')),
    );
    return correct;
  }

  Future<void> _submitTimeout(RoomModel room, String userId) async {
    final image = _image;
    if (image == null) return;
    setState(() => _hasGuessedThisTurn = true);
    await ref.read(roomServiceProvider).submitAnswer(
          roomId: room.id,
          userId: userId,
          guess: '',
          image: image,
          difficulty: room.selectedDifficulty ?? Difficulty.easy,
        );
  }

  Future<void> _openGuessDialog(RoomModel room, String userId) async {
    final image = _image;
    if (image == null || _isGuessModeOpen) return;

    setState(() => _isGuessModeOpen = true);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final inputHeight = min(560.0, max(470.0, constraints.maxHeight * 0.72));
                return Center(
                  child: Container(
                    width: constraints.maxWidth,
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
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
                        _GuessTimerBar(
                          duration: const Duration(seconds: 10),
                          onTimeout: () async {
                            if (!dialogContext.mounted) return;
                            await _submitTimeout(room, userId);
                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                          },
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: inputHeight,
                          child: LetterBankInput(
                            answer: image.answer,
                            enabled: true,
                            onComplete: (filled) async {
                              final correct = await _submitGuess(room, userId, filled);
                              if (dialogContext.mounted) Navigator.pop(dialogContext);
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
    } finally {
      if (mounted) setState(() => _isGuessModeOpen = false);
    }
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
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF8B6FFF))),
              error: (e, _) => Center(child: Text('שגיאה: $e', style: const TextStyle(color: Colors.white70))),
              data: (room) {
                if (room == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/home'));
                  return const SizedBox.shrink();
                }

                if (room.imageId.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _loadImage(room.imageId));
                }

                if (room.phase == GamePhase.finished) {
                  final hasWinner = room.winnerId != null && room.winnerId!.isNotEmpty;
                  if (hasWinner) {
                    final winnerName = room.players[room.winnerId]?.name ?? 'שחקן';
                    return _FinishedView(winnerName: winnerName, onHome: () => context.go('/home'));
                  }
                  return _NoWinnerView(
                    answer: _image?.answer ?? '',
                    imageUrl: _image?.imageUrl,
                    onHome: () => context.go('/home'),
                  );
                }

                _scheduleBotTurn(room);

                if (room.currentTurnIndex != _revealedAtTurnIndex && (_hasRevealedThisTurn || _hasGuessedThisTurn)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _hasRevealedThisTurn = false;
                        _hasGuessedThisTurn = false;
                      });
                    }
                  });
                }

                if (room.guessCount != _lastShownGuessCount && room.lastGuessEvent != null) {
                  _lastShownGuessCount = room.guessCount;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() {
                      _currentBanner = room.lastGuessEvent;
                      _showBanner = true;
                      _showBotTyping = false;
                    });
                    Future.delayed(const Duration(milliseconds: 3500), () {
                      if (mounted) setState(() => _showBanner = false);
                    });
                  });
                }

                final currentUserId = user?.id;
                final isMyTurn = currentUserId != null && room.currentTurnUserId == currentUserId;
                final myCoins = currentUserId != null ? (room.players[currentUserId]?.score ?? 0) : 0;
                final myLetterCards = currentUserId != null ? (room.players[currentUserId]?.letterCards ?? 0) : 0;
                final canGuessNow = isMyTurn &&
                    !_isGuessModeOpen &&
                    _hasRevealedThisTurn &&
                    !_hasGuessedThisTurn &&
                    room.currentTurnIndex == _revealedAtTurnIndex;

                return GameLayout(
                  room: room,
                  image: _image,
                  isMyTurn: isMyTurn,
                  isBusy: _isBusy || _isGuessModeOpen,
                  myCoins: myCoins,
                  myLetterCards: myLetterCards,
                  canGuessNow: canGuessNow,
                  showBanner: _showBanner,
                  bannerEvent: _currentBanner,
                  showBotTyping: _showBotTyping,
                  botTypingName: _botTypingName,
                  botTypingText: _botTypingText,
                  onBack: () => context.go('/home'),
                  onReveal: currentUserId == null ? null : (index) => _humanRevealTile(room: room, userId: currentUserId, index: index),
                  onGuess: canGuessNow ? () => _openGuessDialog(room, currentUserId!) : null,
                  onSkip: (isMyTurn && canGuessNow) ? () => _skipTurn(room) : null,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GuessTimerBar extends StatefulWidget {
  final Duration duration;
  final Future<void> Function() onTimeout;

  const _GuessTimerBar({required this.duration, required this.onTimeout});

  @override
  State<_GuessTimerBar> createState() => _GuessTimerBarState();
}

class _GuessTimerBarState extends State<_GuessTimerBar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _didTimeout = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_didTimeout) {
          _didTimeout = true;
          widget.onTimeout();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final remaining = 1.0 - _controller.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: remaining,
            minHeight: 7,
            backgroundColor: Colors.white.withOpacity(0.14),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF58B8E8)),
          ),
        );
      },
    );
  }
}

class _NoWinnerView extends StatefulWidget {
  final String answer;
  final String? imageUrl;
  final VoidCallback onHome;

  const _NoWinnerView({required this.answer, required this.imageUrl, required this.onHome});

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
        final imgSize = min(constraints.maxWidth - 32, min(constraints.maxHeight * 0.58, 280.0));
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                                    ? Image.asset(widget.imageUrl!, fit: BoxFit.cover)
                                    : CachedNetworkImage(
                                        imageUrl: widget.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => const _ImageFallback(),
                                      ),
                              ),
                              AnimatedOpacity(
                                opacity: _overlayVisible ? 0.4 : 0.0,
                                duration: const Duration(milliseconds: 400),
                                child: const ColoredBox(color: Colors.black),
                              ),
                              _AnswerRevealOverlay(
                                line1Visible: _line1Visible,
                                line2Visible: _line2Visible,
                                line3Visible: _line3Visible,
                                answer: widget.answer,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      _AnswerRevealText(
                        line1Visible: _line1Visible,
                        line2Visible: _line2Visible,
                        line3Visible: _line3Visible,
                        answer: widget.answer,
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(width: 180, child: FilledButton(onPressed: widget.onHome, child: const Text('משחק חדש'))),
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

class _AnswerRevealOverlay extends StatelessWidget {
  final bool line1Visible;
  final bool line2Visible;
  final bool line3Visible;
  final String answer;

  const _AnswerRevealOverlay({required this.line1Visible, required this.line2Visible, required this.line3Visible, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _AnswerRevealText(
          line1Visible: line1Visible,
          line2Visible: line2Visible,
          line3Visible: line3Visible,
          answer: answer,
          withShadow: true,
        ),
      ),
    );
  }
}

class _AnswerRevealText extends StatelessWidget {
  final bool line1Visible;
  final bool line2Visible;
  final bool line3Visible;
  final String answer;
  final bool withShadow;

  const _AnswerRevealText({required this.line1Visible, required this.line2Visible, required this.line3Visible, required this.answer, this.withShadow = false});

  @override
  Widget build(BuildContext context) {
    final shadows = withShadow ? const [Shadow(color: Colors.black87, blurRadius: 8)] : null;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(
          opacity: line1Visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Text('אף אחד לא ניחש בזמן', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, shadows: shadows)),
        ),
        const SizedBox(height: 8),
        AnimatedOpacity(
          opacity: line2Visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Text('התשובה היא...', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700, shadows: shadows)),
        ),
        const SizedBox(height: 6),
        AnimatedOpacity(
          opacity: line3Visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Text(answer, textAlign: TextAlign.center, style: TextStyle(color: const Color(0xFF9B7EFF), fontSize: 26, fontWeight: FontWeight.w900, shadows: withShadow ? const [Shadow(color: Colors.black87, blurRadius: 12)] : null)),
        ),
      ],
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A3E),
      child: const Center(child: Icon(Icons.image_not_supported_outlined, color: Colors.white24, size: 48)),
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
              style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 30),
            FilledButton(onPressed: onHome, child: const Text('חזרה למסך הראשי')),
          ],
        ),
      ),
    );
  }
}
