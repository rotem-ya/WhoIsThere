import 'widgets/answer_slots.dart';
import 'widgets/game_layout.dart';
import 'widgets/game_winner_view.dart';
import 'dart:async';
import 'dart:math' show Random, min, pi;

import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';

import '../../core/theme/app_styles.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/game_constants.dart';
import '../../models/game_image_model.dart';
import '../../models/player_model.dart';
import '../../models/room_model.dart';
import '../../models/economy/match_reward_breakdown.dart';
import '../../providers/providers.dart';
import '../../services/hint_economy_guard.dart';
import '../../widgets/game/animated_reward.dart';
import '../../widgets/game/letter_bank_input.dart';
import 'widgets/game_top_hud.dart';
import 'widgets/game_board_view.dart';

class GameBoardScreen extends ConsumerStatefulWidget {
  final String roomId;

  const GameBoardScreen({super.key, required this.roomId});

  @override
  ConsumerState<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends ConsumerState<GameBoardScreen>
    with WidgetsBindingObserver {
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

  // Background music
  static final AudioPlayer _bgPlayer = AudioPlayer(playerId: 'studio-bg');
  static final AssetSource _bgMusic = AssetSource('sounds/background_studio.mp3');

  // Reveal sound — owned here, not by ApertureTile
  static final AudioPlayer _revealSoundPlayer = AudioPlayer(playerId: 'reveal-aperture');
  static final AssetSource _revealSound = AssetSource('sounds/aperture_open.mp3');

  static Future<void> _primeRevealSound() async {
    try {
      await _revealSoundPlayer.setPlayerMode(PlayerMode.lowLatency);
    } catch (_) {}
    try {
      await _revealSoundPlayer.setSource(_revealSound);
    } catch (_) {}
  }

  static Future<void> _playRevealSound() async {
    try {
      await _revealSoundPlayer.stop();
      await _revealSoundPlayer.play(_revealSound);
    } catch (_) {}
  }

  static Future<void> _startBackgroundMusic() async {
    try {
      await _bgPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgPlayer.setVolume(0.30);
      await _bgPlayer.play(_bgMusic);
    } catch (_) {}
  }

  // Economy
  bool _rewardApplied = false;
  DateTime? _gameStartTime;
  MatchRewardBreakdown? _rewardBreakdown;

  // Correct-guess victory overlay
  bool _showCorrectGuess = false;
  late final ConfettiController _confettiLeft;
  late final ConfettiController _confettiRight;
  static final AudioPlayer _victoryPlayer = AudioPlayer(playerId: 'victory-fanfare');
  static final AssetSource _victorySound = AssetSource('sounds/victory_fanfare.mp3');

  @override
  void initState() {
    super.initState();
    _confettiLeft = ConfettiController(duration: const Duration(seconds: 2));
    _confettiRight = ConfettiController(duration: const Duration(seconds: 2));
    WidgetsBinding.instance.addObserver(this);
    unawaited(_startBackgroundMusic());
    unawaited(_primeRevealSound());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _bgPlayer.stop().ignore();
      _revealSoundPlayer.stop().ignore();
      _victoryPlayer.stop().ignore();
    }
  }

  @override
  void dispose() {
    _guessController.dispose();
    _confettiLeft.dispose();
    _confettiRight.dispose();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_bgPlayer.stop());
    super.dispose();
  }

  static Future<void> _playVictorySound() async {
    try {
      await _victoryPlayer.stop();
      await _victoryPlayer.play(_victorySound);
    } catch (_) {}
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
      unawaited(_playRevealSound());
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

      final afterReveal = await ref.read(roomServiceProvider).watchRoom(room.id).first;
      if (afterReveal == null || afterReveal.phase == GamePhase.finished) return;

      final afterTotal = afterReveal.gridSize * afterReveal.gridSize;
      final afterRevealed = afterReveal.placedPieces.length;
      final afterRatio = afterTotal > 0 ? afterRevealed / afterTotal : 0.0;

      double attemptChance;
      double correctChance;
      if (afterRevealed < 5 || afterRatio < 0.50) {
        attemptChance = 0.0;
        correctChance = 0.0;
      } else if (afterRatio >= 0.75) {
        attemptChance = 0.45;
        correctChance = 0.55;
      } else {
        attemptChance = 0.25;
        correctChance = 0.30;
      }

      final shouldGuess = _image != null && _random.nextDouble() < attemptChance;

      if (shouldGuess) {
        await _performBotGuess(afterReveal, currentId, correctChance);
      } else {
        if (mounted) {
          await ref.read(roomServiceProvider).skipPiecePlacement(roomId: afterReveal.id);
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

    await Future.delayed(Duration(milliseconds: 1200 + _random.nextInt(801)));

    for (int i = 1; i <= word.length; i++) {
      if (!mounted) return;
      setState(() => _botTypingText = word.substring(0, i));
      await Future.delayed(Duration(milliseconds: 220 + _random.nextInt(121)));
    }

    await Future.delayed(const Duration(milliseconds: 350));
  }

  Future<void> _performBotGuess(RoomModel room, String botId, double correctChance) async {
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

  Future<void> _triggerMatchReward(RoomModel room, String? uid) async {
    if (_rewardApplied || uid == null) return;
    _rewardApplied = true;

    final isWin = room.winnerId == uid;
    final isSolo = room.players.values.where((p) => !p.isBot).length == 1;
    final timeTaken = _gameStartTime != null
        ? DateTime.now().difference(_gameStartTime!)
        : const Duration(seconds: 999);
    final totalTilesCount = room.gridSize * room.gridSize;

    try {
      final breakdown = await ref.read(economyServiceProvider).applyMatchReward(
            uid: uid,
            isWin: isWin,
            isSolo: isSolo,
            tilesRevealedCount: room.placedPieces.length,
            totalTilesCount: totalTilesCount,
            wrongGuessCount: 0,
            timeTaken: timeTaken,
            roomId: room.id,
          );
      if (mounted) setState(() => _rewardBreakdown = breakdown);
    } catch (e) {
      debugPrint('Economy reward error: $e');
    }
  }

  Future<void> _useRevealHint(RoomModel room, String userId) async {
    final isSolo = room.players.values.where((p) => !p.isBot).length == 1;
    if (!isSolo) return;

    final wallet = ref.read(walletProvider).valueOrNull;
    if (wallet == null) return;

    final guard = ref.read(hintEconomyGuardProvider);
    if (!guard.canAfford(wallet, HintType.revealTile)) return;

    final granted = await guard.useHint(
      uid: userId,
      hint: HintType.revealTile,
      wallet: wallet,
      roomId: room.id,
    );

    if (!granted || !mounted) return;
    if (room.availablePieceIndices.isEmpty) return;

    final idx = room.availablePieceIndices[
        _random.nextInt(room.availablePieceIndices.length)];
    await _humanRevealTile(room: room, userId: userId, index: idx);
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
    if (correct) {
      setState(() => _showCorrectGuess = true);
      _confettiLeft.play();
      _confettiRight.play();
      unawaited(_playVictorySound());
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _showCorrectGuess = false);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('לא נכון, נסה שוב')),
      );
    }
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
        backgroundColor: AppStyles.navyTop,
        body: Stack(
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: AppStyles.backgroundGradient,
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

                final currentUserId = user?.id;

                if (room.imageId.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _loadImage(room.imageId));
                }

                // Capture game-start time the first frame phase becomes 'playing'
                if (room.phase == GamePhase.playing && _gameStartTime == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _gameStartTime == null) {
                      _gameStartTime = DateTime.now();
                    }
                  });
                }

                if (room.phase == GamePhase.finished) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _triggerMatchReward(room, currentUserId);
                  });
                  final hasWinner = room.winnerId != null && room.winnerId!.isNotEmpty;
                  if (hasWinner) {
                    final rawName = room.players[room.winnerId]?.name ?? '';
                    final winnerName = rawName.isEmpty ? 'שחקן' : rawName;
                    return GameWinnerView(
                      winnerName: winnerName,
                      rewardBreakdown: _rewardBreakdown,
                      onHome: () => context.go('/home'),
                    );
                  }
                  return _NoWinnerView(
                    answer: _image?.answer ?? '',
                    imageUrl: _image?.imageUrl,
                    onHome: () => context.go('/home'),
                  );
                }

                _scheduleBotTurn(room);

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

                final isMyTurn = currentUserId != null && room.currentTurnUserId == currentUserId;
                final canGuessNow = isMyTurn &&
                    _hasRevealedThisTurn &&
                    !_hasGuessedThisTurn &&
                    room.currentTurnIndex == _revealedAtTurnIndex;
                final isSolo = room.players.values.where((p) => !p.isBot).length == 1;

                return GameLayout(
                  room: room,
                  image: _image,
                  isMyTurn: isMyTurn,
                  isBusy: _isBusy,
                  canGuessNow: canGuessNow,
                  isSolo: isSolo,
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
                            index: index,
                          ),
                  onRevealHint: currentUserId == null
                      ? null
                      : () => _useRevealHint(room, currentUserId),
                  onGuess: canGuessNow ? () => _openGuessDialog(room, currentUserId!) : null,
                  onSkip: (isMyTurn && canGuessNow) ? () => _skipTurn(room) : null,
                );
              },
            ),
          ),
            ),
            if (_showCorrectGuess) ...[
              Align(
                alignment: Alignment.topLeft,
                child: ConfettiWidget(
                  confettiController: _confettiLeft,
                  blastDirection: -pi / 4,
                  colors: const [Color(0xFF00F2FF), Color(0xFFFFE14D), Colors.white],
                  numberOfParticles: 22,
                  gravity: 0.18,
                  shouldLoop: false,
                ),
              ),
              Align(
                alignment: Alignment.topRight,
                child: ConfettiWidget(
                  confettiController: _confettiRight,
                  blastDirection: -3 * pi / 4,
                  colors: const [Color(0xFF00F2FF), Color(0xFFFFE14D), Colors.white],
                  numberOfParticles: 22,
                  gravity: 0.18,
                  shouldLoop: false,
                ),
              ),
              Center(
                child: IgnorePointer(
                  child: Text(
                    'ניחוש נכון! ✨',
                    textAlign: TextAlign.center,
                    style: AppStyles.heading1.copyWith(
                      fontSize: 48,
                      shadows: [
                        Shadow(color: AppStyles.cyanGlow, blurRadius: 30),
                        Shadow(
                          color: AppStyles.cyanGlow.withOpacity(0.5),
                          blurRadius: 60,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedOpacity(
                                        opacity: _line1Visible ? 1.0 : 0.0,
                                        duration: const Duration(milliseconds: 300),
                                        child: const Text(
                                          'אף אחד לא ניחש בזמן',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                            shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
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
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
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
                                            shadows: [Shadow(color: Colors.black87, blurRadius: 12)],
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
