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
import 'guess_mode_overlay.dart';

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
  final double revealRatio;
  final int potTotal;

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
    this.revealRatio = 0.0,
    this.potTotal = 0,
  });

  @override
  Widget build(BuildContext context) {
    final currentPlayer = room.players[room.currentTurnUserId];
    final revealedCount = room.placedPieces.length;
    final total = room.gridSize * room.gridSize;

    // In race mode, guessOpportunityPlayerId is null when the window is open to all.
    final isMyGuessOpportunity = canGuessNow;

    final isMyGuessModeActive = currentUserId != null &&
        room.turnPhase == TurnPhase.guessMode &&
        room.guessModePlayerId == currentUserId;

    final isGuessModeActive = room.turnPhase == TurnPhase.guessMode;
    final guessModePlayerName = room.players[room.guessModePlayerId]?.name ?? '';
    final isLastTile = room.availablePieceIndices.length == 1;
    final userId = currentUserId;
    final myScore = userId != null ? (room.players[userId]?.score ?? 0) : 0;
    final leaderScore = room.sortedPlayers.isNotEmpty ? room.sortedPlayers.first.score : 0;
    final isScoreCliff = canGuessNow && (leaderScore - myScore) <= 1;
    final isBlocked = userId != null && room.isBlockedFromGuessing(userId);
    final blockedUntil = userId != null ? (room.blockedGuessers[userId] ?? 0) : 0;
    final blockedRemaining = isBlocked ? (blockedUntil - room.revealCount).clamp(0, 99) : 0;

    return Stack(
      children: [
        // ── Main game column ───────────────────────────────────────────────
        Column(
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
              isSolo: isSolo,
              revealedCount: revealedCount,
              totalTiles: total,
              guessOpportunityDeadlineMs: room.guessOpportunityDeadlineMs,
              isLastTile: isLastTile,
              potTotal: potTotal,
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
                  enabled: false,
                  glowEnabled: false,
                  onReveal: onReveal,
                  cardSkinId: room.cardSkinId,
                  pendingRevealTileIndex: room.pendingRevealTileIndex,
                  revealDeadlineMs: room.revealDeadlineMs,
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
              isGuessModeActive: isGuessModeActive,
              isScoreCliff: isScoreCliff,
              guessModePlayerName: guessModePlayerName,
              isBlocked: isBlocked,
              blockedRemaining: blockedRemaining,
              onRevealHint: onRevealHint,
              onGuess: onGuess,
            ),
          ],
        ),

        // ── Dramatic guess overlay — shown for ALL players during guessMode ─
        if (isGuessModeActive)
          GuessModeOverlay(
            key: ValueKey('guess-overlay-${room.guessModeDeadlineMs}'),
            guesserName: guessModePlayerName,
            isMyGuess: isMyGuessModeActive,
            deadlineMs: room.guessModeDeadlineMs,
            answer: image?.answer ?? '',
            onSubmit: onGuessSubmit,
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


