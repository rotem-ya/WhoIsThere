import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/game_constants.dart';
import '../../../models/game_image_model.dart';
import '../../../models/room_model.dart';
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
  final VoidCallback? onSkip;

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
    required this.onSkip,
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
        ),
        _TurnPhaseCountdownBar(
          turnPhase: room.turnPhase,
          revealDeadlineMs: room.revealDeadlineMs,
          guessOpportunityDeadlineMs: room.guessOpportunityDeadlineMs,
          guessModeDeadlineMs: room.guessModeDeadlineMs,
        ),
        if (showBotTyping)
          BotTypingBanner(botName: botTypingName, typedSoFar: botTypingText)
        else if (showBanner && bannerEvent != null)
          GuessBanner(
            key: ValueKey('${bannerEvent!['playerId']}-${bannerEvent!['guess']}-${bannerEvent!['isCorrect']}'),
            event: bannerEvent!,
            players: room.players,
          ),
        Expanded(
          child: Center(
            child: GameBoardView(
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
        AnswerSlots(answer: image?.answer ?? '', isMyTurn: isMyTurn),
        GameActions(
          isMyTurn: isMyTurn,
          isBusy: isBusy,
          canGuessNow: canGuessNow,
          isSolo: isSolo,
          revealedCount: revealedCount,
          totalTiles: total,
          onRevealHint: onRevealHint,
          onGuess: onGuess,
          onSkip: onSkip,
        ),
      ],
    );
  }
}

// Isolated countdown bar — has its own 1s timer so only this widget rebuilds per-second.
class _TurnPhaseCountdownBar extends StatefulWidget {
  final TurnPhase turnPhase;
  final int? revealDeadlineMs;
  final int? guessOpportunityDeadlineMs;
  final int? guessModeDeadlineMs;

  const _TurnPhaseCountdownBar({
    required this.turnPhase,
    this.revealDeadlineMs,
    this.guessOpportunityDeadlineMs,
    this.guessModeDeadlineMs,
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

    switch (widget.turnPhase) {
      case TurnPhase.revealTurn:
        deadlineMs = widget.revealDeadlineMs;
        totalMs = 8000;
        barColor = const Color(0xFF87CEEB); // cyan
      case TurnPhase.guessOpportunity:
        deadlineMs = widget.guessOpportunityDeadlineMs;
        totalMs = 7000;
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
              // Track
              Container(
                width: maxWidth,
                height: 3,
                color: Colors.white.withOpacity(0.06),
              ),
              // Fill — AnimatedContainer gives smooth linear shrink between 1s ticks
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
