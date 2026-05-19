import 'dart:async';

import 'package:flutter/foundation.dart';
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
  final VoidCallback? onGuessMode;
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
    required this.onGuessMode,
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

    final isGuessModeActive = room.turnPhase == TurnPhase.guessMode;
    final guessModePlayerName = room.players[room.guessModePlayerId]?.name ?? '';

    // Answer slots are visible only when this player is actively guessing, or after round ends.
    final showAnswerSlots = isMyGuessModeActive || room.turnPhase == TurnPhase.roundOver;

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
        Visibility(
          visible: showAnswerSlots,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: AnswerSlots(
            answer: image?.answer ?? '',
            isMyTurn: isMyGuessModeActive || isMyTurn,
          ),
        ),
        GameActions(
          isMyTurn: isMyTurn,
          isBusy: isBusy,
          canGuessNow: canGuessNow,
          isSolo: isSolo,
          revealedCount: revealedCount,
          totalTiles: total,
          isGuessModeActive: isGuessModeActive,
          isMyGuessModeActive: isMyGuessModeActive,
          guessModePlayerName: guessModePlayerName,
          onRevealHint: onRevealHint,
          onGuess: onGuess,
          onGuessMode: onGuessMode,
          onSkip: onSkip,
        ),
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
