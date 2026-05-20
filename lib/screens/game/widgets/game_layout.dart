import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/game_constants.dart';
import '../../../models/game_image_model.dart';
import '../../../models/room_model.dart';
import '../../../services/qa_logger_service.dart';
import '../../../widgets/game/letter_bank_input.dart';
import 'answer_slots.dart';
import 'game_actions.dart';
import 'game_banners.dart';
import 'game_board_view.dart';
import 'game_top_hud.dart';

class GameLayout extends StatelessWidget {
  final RoomModel room;
  final GameImageModel? image;
  final String? currentUserId;
  final bool isMyTurn;
  final bool isBusy;
  final bool canGuessNow;
  final bool isSolo;
  final bool showBanner;
  final Map<String, dynamic>? bannerEvent;
  final bool showBotTyping;
  final String botTypingName;
  final String botTypingText;
  final VoidCallback onBack;
  final void Function(int)? onReveal;
  final VoidCallback? onRevealHint;
  final VoidCallback? onGuess;
  final Future<bool> Function(String)? onGuessSubmit;
  final VoidCallback? onSkip;
  final double revealRatio;

  const GameLayout({
    required this.room,
    required this.image,
    required this.currentUserId,
    required this.isMyTurn,
    required this.isBusy,
    required this.canGuessNow,
    required this.isSolo,
    required this.showBanner,
    required this.bannerEvent,
    required this.showBotTyping,
    required this.botTypingName,
    required this.botTypingText,
    required this.onBack,
    required this.onReveal,
    required this.onRevealHint,
    required this.onGuess,
    required this.onGuessSubmit,
    required this.onSkip,
    this.revealRatio = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final currentPlayer = room.players[room.currentTurnUserId];
    final revealedCount = room.placedPieces.length;
    final total = room.gridSize * room.gridSize;

    final isMyGuessOpportunity = currentUserId != null &&
        room.turnPhase == TurnPhase.guessOpportunity &&
        room.guessOpportunityPlayerId == currentUserId;

    final isMyGuessModeActive = currentUserId != null &&
        room.turnPhase == TurnPhase.guessMode &&
        room.guessModePlayerId == currentUserId;

    final isGuessModeActive = room.turnPhase == TurnPhase.guessMode;
    final guessModePlayerName = room.players[room.guessModePlayerId]?.name ?? '';

    return Column(
      children: [
        TopHud(
          players: room.sortedPlayers,
          currentPlayerId: room.currentTurnUserId,
          currentPlayerName: currentPlayer?.name ?? '',
          revealedText: '$revealedCount/$total',
          onBack: onBack,
          isMyTurn: isMyTurn,
          turnPhase: room.turnPhase,
          isMyGuessOpportunity: isMyGuessOpportunity,
          isMyGuessModeActive: isMyGuessModeActive,
          guessModePlayerName: guessModePlayerName,
          revealRatio: revealRatio,
        ),
        // During guessMode: hide the 3px bar — inline countdown replaces it
        if (isGuessModeActive)
          const SizedBox(height: 3)
        else
          _TurnPhaseCountdownBar(
            turnPhase: room.turnPhase,
            revealDeadlineMs: room.revealDeadlineMs,
            guessOpportunityDeadlineMs: room.guessOpportunityDeadlineMs,
            guessModeDeadlineMs: room.guessModeDeadlineMs,
            revealRatio: revealRatio,
          ),
        if (kDebugMode)
          _DebugPhaseBadge(
            turnPhase: room.turnPhase,
            guessOpportunityPlayerId: room.guessOpportunityPlayerId,
            guessModePlayerId: room.guessModePlayerId,
            currentUserId: currentUserId,
          ),
        if (showBotTyping)
          BotTypingBanner(botName: botTypingName, typedSoFar: botTypingText)
        else if (showBanner && bannerEvent != null)
          GuessBanner(
            key: ValueKey('${bannerEvent!['playerId']}-${bannerEvent!['guess']}-${bannerEvent!['isCorrect']}'),
            event: bannerEvent!,
            players: room.players,
          ),
        // Board dims during guessMode; hover/glow disabled
        Expanded(
          child: Center(
            child: AnimatedOpacity(
              opacity: isGuessModeActive ? 0.35 : 1.0,
              duration: const Duration(milliseconds: 350),
              child: GameBoardView(
                gridSize: room.gridSize,
                revealedCells: room.revealedCells,
                availableCells: room.availablePieceIndices,
                imageUrl: image?.imageUrl,
                enabled: isMyTurn && !isBusy && !canGuessNow && !isGuessModeActive,
                glowEnabled: isMyTurn && !isBusy && !canGuessNow && !isGuessModeActive,
                onReveal: onReveal,
              ),
            ),
          ),
        ),
        // Bottom section: inline guess UI for guesser, normal actions for everyone else
        if (isMyGuessModeActive)
          _InlineGuessSection(
            answer: image?.answer ?? '',
            deadlineMs: room.guessModeDeadlineMs,
            onSubmit: onGuessSubmit,
          )
        else ...[
          AnswerSlots(answer: image?.answer ?? '', isMyTurn: isMyTurn),
          GameActions(
            isMyTurn: isMyTurn,
            isBusy: isBusy,
            canGuessNow: canGuessNow,
            isSolo: isSolo,
            revealedCount: revealedCount,
            totalTiles: total,
            isGuessModeActive: isGuessModeActive,
            guessModePlayerName: guessModePlayerName,
            onRevealHint: onRevealHint,
            onGuess: onGuess,
            onSkip: onSkip,
          ),
        ],
      ],
    );
  }
}

class _DebugPhaseBadge extends StatelessWidget {
  final TurnPhase turnPhase;
  final String? guessOpportunityPlayerId;
  final String? guessModePlayerId;
  final String? currentUserId;

  const _DebugPhaseBadge({
    required this.turnPhase,
    required this.guessOpportunityPlayerId,
    required this.guessModePlayerId,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    String detail = '';
    if (turnPhase == TurnPhase.guessOpportunity && guessOpportunityPlayerId != null) {
      final id = guessOpportunityPlayerId!;
      final short = id.length > 6 ? id.substring(0, 6) : id;
      final isMe = id == currentUserId;
      detail = ' opp=$short${isMe ? '(ME)' : ''}';
    } else if (turnPhase == TurnPhase.guessMode && guessModePlayerId != null) {
      final id = guessModePlayerId!;
      final short = id.length > 6 ? id.substring(0, 6) : id;
      final isMe = id == currentUserId;
      detail = ' guesser=$short${isMe ? '(ME)' : ''}';
    }

    return Container(
      width: double.infinity,
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Text(
        '[DBG] turnPhase=${turnPhase.name}$detail',
        style: const TextStyle(color: Color(0xFFFFE082), fontSize: 10, fontFamily: 'monospace'),
      ),
    );
  }
}

// Isolated countdown bar — has its own 1s timer so only this widget rebuilds per-second.
class _TurnPhaseCountdownBar extends StatefulWidget {
  final TurnPhase turnPhase;
  final int? revealDeadlineMs;
  final int? guessOpportunityDeadlineMs;
  final int? guessModeDeadlineMs;
  final double revealRatio;

  const _TurnPhaseCountdownBar({
    required this.turnPhase,
    this.revealDeadlineMs,
    this.guessOpportunityDeadlineMs,
    this.guessModeDeadlineMs,
    this.revealRatio = 0.0,
  });

  @override
  State<_TurnPhaseCountdownBar> createState() => _TurnPhaseCountdownBarState();
}

class _TurnPhaseCountdownBarState extends State<_TurnPhaseCountdownBar> {
  Timer? _t;
  int _nowMs = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _nowMs = DateTime.now().millisecondsSinceEpoch);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int? deadlineMs;
    int totalMs;
    Color barColor;

    final ratio = widget.revealRatio;
    final isEndgame = ratio >= 0.75;

    switch (widget.turnPhase) {
      case TurnPhase.revealTurn:
        deadlineMs = widget.revealDeadlineMs;
        // Match server-side _revealTimerMs formula for accurate bar fraction
        if (ratio <= 0.25) totalMs = 8000;
        else if (ratio <= 0.50) totalMs = 6500;
        else if (ratio <= 0.75) totalMs = 5000;
        else totalMs = 3500;
        barColor = isEndgame
            ? const Color(0xFFFF9F43) // amber-orange at endgame
            : const Color(0xFF87CEEB); // cyan
      case TurnPhase.guessOpportunity:
        deadlineMs = widget.guessOpportunityDeadlineMs;
        // Match server-side _guessOppTimerMs formula
        if (ratio <= 0.50) totalMs = 7000;
        else if (ratio <= 0.75) totalMs = 5000;
        else totalMs = 3500;
        barColor = const Color(0xFFD4AF37); // gold
      case TurnPhase.guessMode:
        deadlineMs = widget.guessModeDeadlineMs;
        totalMs = 20000;
        barColor = const Color(0xFFFF6B35); // orange
      default:
        return const SizedBox(height: 3);
    }

    if (deadlineMs == null) return const SizedBox(height: 3);

    final remainingMs = (deadlineMs - _nowMs).clamp(0, totalMs);
    final fraction = remainingMs / totalMs;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        return SizedBox(
          height: 3,
          child: Stack(
            children: [
              Container(
                width: maxWidth,
                height: 3,
                color: Colors.white.withOpacity(0.06),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 900),
                curve: Curves.linear,
                width: maxWidth * fraction,
                height: 3,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(2),
                    bottomRight: Radius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Inline guess section — shown in place of AnswerSlots + GameActions when isMyGuessModeActive.
class _InlineGuessSection extends StatelessWidget {
  final String answer;
  final int? deadlineMs;
  final Future<bool> Function(String)? onSubmit;

  const _InlineGuessSection({
    required this.answer,
    required this.deadlineMs,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: const Color(0xFF07101F).withOpacity(0.88),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (deadlineMs != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _InlineGuessCountdown(deadlineMs: deadlineMs!),
              ),
            SizedBox(
              height: 350,
              child: LetterBankInput(
                key: deadlineMs != null ? ValueKey('guess-$deadlineMs') : null,
                answer: answer,
                enabled: onSubmit != null,
                onComplete: onSubmit ?? (_) async => false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Large, pulsing countdown shown during guessMode for the active guesser.
class _InlineGuessCountdown extends StatefulWidget {
  final int deadlineMs;
  const _InlineGuessCountdown({required this.deadlineMs});

  @override
  State<_InlineGuessCountdown> createState() => _InlineGuessCountdownState();
}

class _InlineGuessCountdownState extends State<_InlineGuessCountdown>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scaleAnim;
  Timer? _t;
  int _nowMs = DateTime.now().millisecondsSinceEpoch;
  bool _last5Logged = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.14).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeOut),
    );
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _nowMs = DateTime.now().millisecondsSinceEpoch);
      _pulse.forward().then((_) => _pulse.reverse());
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remainingSec = ((widget.deadlineMs - _nowMs) / 1000).ceil().clamp(0, 20);
    final isRed = remainingSec <= 5;
    final isOrange = remainingSec <= 10 && !isRed;

    if (isRed && !_last5Logged) {
      _last5Logged = true;
      QaLoggerService.instance.log('GUESS', 'GUESS_COUNTDOWN_LAST5 sec=$remainingSec');
    }

    final color = isRed
        ? const Color(0xFFFF3B30)
        : isOrange
            ? const Color(0xFFFF6B35)
            : Colors.white;

    return Center(
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          decoration: isRed
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF3B30).withOpacity(0.45),
                      blurRadius: 32,
                      spreadRadius: 6,
                    ),
                  ],
                )
              : null,
          child: Text(
            '$remainingSec',
            style: TextStyle(
              color: color,
              fontSize: 52,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
