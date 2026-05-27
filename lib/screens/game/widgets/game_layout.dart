import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/game_constants.dart';
import '../../../models/game_image_model.dart';
import '../../../models/player_model.dart';
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
  final VoidCallback? onTapRevealed;
  final VoidCallback? onRevealHint;
  final int purchasedHintCount;
  final VoidCallback? onBuySecondHint;
  final VoidCallback? onGuess;
  final Future<bool> Function(String)? onGuessSubmit;
  final double revealRatio;
  final int potTotal;
  final int stunCardCount;
  final Future<void> Function(String targetId)? onStunCard;
  final int guessBlock5Count;
  final int guessBlock10Count;
  final int blackoutCardCount;
  final Map<String, int> guessBlockedUntilMs;
  final Map<String, int> blackoutActiveUntilMs;

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
    this.onTapRevealed,
    required this.onRevealHint,
    required this.onGuess,
    required this.onGuessSubmit,
    this.purchasedHintCount = 0,
    this.onBuySecondHint,
    this.revealRatio = 0.0,
    this.potTotal = 0,
    this.stunCardCount = 0,
    this.onStunCard,
    this.guessBlock5Count = 0,
    this.guessBlock10Count = 0,
    this.blackoutCardCount = 0,
    this.guessBlockedUntilMs = const {},
    this.blackoutActiveUntilMs = const {},
  });

  @override
  Widget build(BuildContext context) {
    final currentPlayer = room.players[room.currentTurnUserId];
    final revealedCount = room.placedPieces.length;
    final total = room.gridSize * room.gridSize;
    final _nowMs = DateTime.now().millisecondsSinceEpoch;

    // Blackout: am I currently blacked out?
    final _myBlackoutExpiry = currentUserId != null
        ? (blackoutActiveUntilMs[currentUserId] ?? 0)
        : 0;
    final _isBlackedOut = _myBlackoutExpiry > _nowMs;

    // Time-based guess block countdown in seconds
    final _myGuessBlockExpiry = currentUserId != null
        ? (guessBlockedUntilMs[currentUserId] ?? 0)
        : 0;
    final _guessBlockSecsLeft = _myGuessBlockExpiry > _nowMs
        ? ((_myGuessBlockExpiry - _nowMs) / 1000).ceil()
        : 0;

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

    // Stun card: eligible targets = other human non-eliminated players
    final stunnedPlayerIds = room.blockedGuessers.entries
        .where((e) => room.revealCount < e.value)
        .map((e) => e.key)
        .toSet();
    final stunTargets = room.players.values
        .where((p) => !p.isBot && !p.isEliminated && p.id != currentUserId)
        .toList();
    final canUseStunCard = !isSolo &&
        stunCardCount > 0 &&
        stunTargets.isNotEmpty &&
        room.turnPhase != TurnPhase.guessMode &&
        room.phase != GamePhase.finished;

    return Stack(
      children: [
        // ── Main game column ───────────────────────────────────────────────
        Column(
          children: [
            TopHud(
              players: room.sortedPlayers,
              stunnedPlayerIds: stunnedPlayerIds,
              currentPlayerId: room.currentTurnUserId,
              currentPlayerName: currentPlayer?.name ?? '',
              revealedText: '$revealedCount/$total',
              onBack: onBack,
              isMyTurn: isMyTurn,
              turnPhase: room.turnPhase,
              isMyGuessOpportunity: isMyGuessOpportunity,
              isMyGuessModeActive: isMyGuessModeActive,
              guessModePlayerName: guessModePlayerName,
              guessModePlayerId: room.guessModePlayerId,
              revealRatio: revealRatio,
              isSolo: isSolo,
              revealedCount: revealedCount,
              totalTiles: total,
              guessOpportunityDeadlineMs: room.guessOpportunityDeadlineMs,
              isLastTile: isLastTile,
              potTotal: potTotal,
              roomId: room.id,
              localUserId: currentUserId,
              guessBlock5Count: guessBlock5Count,
              guessBlock10Count: guessBlock10Count,
              blackoutCardCount: blackoutCardCount,
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
                child: Stack(
                  children: [
                    GameBoardView(
                      gridSize: room.gridSize,
                      revealedCells: room.revealedCells,
                      availableCells: room.availablePieceIndices,
                      imageUrl: _isBlackedOut ? null : image?.imageUrl,
                      enabled: false,
                      glowEnabled: false,
                      onReveal: onReveal,
                      onTapRevealed: onTapRevealed,
                      cardSkinId: room.cardSkinId,
                      pendingRevealTileIndex: room.pendingRevealTileIndex,
                      revealDeadlineMs: room.revealDeadlineMs,
                    ),
                    if (_isBlackedOut)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF000000).withOpacity(0.88),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.visibility_off_rounded, color: Colors.white54, size: 40),
                                SizedBox(height: 10),
                                Text(
                                  'המסך הוחשך!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'שחקן אחר החשיך לך את הלוח',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
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
              isTimeBlocked: _guessBlockSecsLeft > 0,
              timeBlockSecsLeft: _guessBlockSecsLeft,
              onRevealHint: onRevealHint,
              purchasedHintCount: purchasedHintCount,
              onBuySecondHint: onBuySecondHint,
              onGuess: onGuess,
              stunCardCount: stunCardCount,
              canUseStunCard: canUseStunCard,
              stunTargets: stunTargets,
              onStunCard: onStunCard,
            ),
          ],
        ),

        // ── Dramatic guess overlay — shown only for the active guesser ─
        if (isMyGuessModeActive)
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


