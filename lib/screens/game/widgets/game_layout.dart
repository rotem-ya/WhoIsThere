import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/game_categories.dart';
import '../../../core/constants/game_constants.dart';
import '../../../models/game_image_model.dart';
import '../../../models/room_model.dart';
import '../../../services/content_manifest_service.dart';
import 'answer_slots.dart';
import 'detective_toolbar.dart';
import 'game_actions.dart';
import 'game_banners.dart';
import 'game_board_view.dart';
import 'game_top_hud.dart';
import 'guess_mode_overlay.dart';
import '../../../widgets/game/letter_turn_panel.dart';

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
  final bool botTypingIsThreat;
  final VoidCallback onBack;
  final void Function(int)? onReveal;
  final VoidCallback? onTapRevealed;
  final VoidCallback? onRevealHint;
  final int purchasedHintCount;
  final VoidCallback? onBuySecondHint;
  final VoidCallback? onGuess;
  final Future<bool> Function(String)? onGuessSubmit;
  // Cancels the locally-opened guess input without submitting (no penalty).
  final VoidCallback? onGuessCancel;
  // Parallel guessing: the guess input overlay is driven by a LOCAL flag so each
  // player can open their own input independently (no shared exclusive lock).
  final bool showGuessInput;
  final int? localGuessDeadlineMs;
  final double revealRatio;
  final int potTotal;
  final int stunCardCount;
  final Future<void> Function(String targetId)? onStunCard;
  final int guessBlock5Count;
  final int guessBlock10Count;
  final int blackoutCardCount;
  final Map<String, int> guessBlockedUntilMs;
  final Map<String, int> blackoutActiveUntilMs;
  // Personal (this-player-only) tile reveals + the buy action for one more.
  final Set<int> personalRevealedCells;
  final VoidCallback? onBuyReveal;
  final int revealBuyPrice;
  final int revealBuyCount;
  final int maxRevealBuys;
  // Detective reveal tools + transient spotlight peek cells (this-player-only).
  final List<DetectiveAction> detectiveActions;
  final Set<int> spotlightCells;
  // Bought-letter reveal in the guess overlay.
  final int revealedLetterCount;
  final VoidCallback? onBuyLetter;
  final int nextLetterPrice;
  final bool showBuyLetter;
  // חי-צומח-דומם: vote to replace the current item (nobody recognizes it).
  final VoidCallback? onVoteSkip;
  // Turn-based letter guessing (additive hint layer, host-toggled).
  final ValueChanged<String>? onGuessLetterTurn;

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
    this.botTypingIsThreat = false,
    required this.onBack,
    required this.onReveal,
    this.onTapRevealed,
    required this.onRevealHint,
    required this.onGuess,
    required this.onGuessSubmit,
    this.onGuessCancel,
    this.showGuessInput = false,
    this.localGuessDeadlineMs,
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
    this.personalRevealedCells = const {},
    this.onBuyReveal,
    this.revealBuyPrice = 0,
    this.revealBuyCount = 0,
    this.maxRevealBuys = 5,
    this.detectiveActions = const [],
    this.spotlightCells = const {},
    this.revealedLetterCount = 0,
    this.onBuyLetter,
    this.nextLetterPrice = 0,
    this.showBuyLetter = false,
    this.onVoteSkip,
    this.onGuessLetterTurn,
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

    // Stun card: eligible targets = all non-self, non-eliminated players (bots included)
    final stunnedPlayerIds = room.blockedGuessers.entries
        .where((e) => room.revealCount < e.value)
        .map((e) => e.key)
        .toSet();
    final stunTargets = room.players.values
        .where((p) => !p.isEliminated && p.id != currentUserId)
        .toList();
    final canUseStunCard = stunCardCount > 0 &&
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
              showExposure: !room.isPublicRoom,
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
              tricksDisabled: !room.tricksEnabled,
            ),
            // חי/צומח/דומם: always show the current topic + round, so the player
            // knows what they're guessing at every stage.
            if (room.isHeat) _HeatTopicChip(room: room),
            if (kDebugMode)
              _DebugPhaseBadge(
                turnPhase: room.turnPhase,
                guessOpportunityPlayerId: room.guessOpportunityPlayerId,
                guessModePlayerId: room.guessModePlayerId,
                currentUserId: currentUserId,
              ),
            if (showBotTyping)
              BotTypingBanner(
                botName: botTypingName,
                typedSoFar: botTypingText,
                isThreat: botTypingIsThreat,
              )
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
                      // Merge shared reveals with this player's personal reveals
                      // so paid tiles show only on the buyer's screen.
                      revealedCells: personalRevealedCells.isEmpty
                          ? room.revealedCells
                          : <int>{...room.revealedCells, ...personalRevealedCells}
                              .toList(),
                      availableCells: room.availablePieceIndices,
                      imageUrl: _isBlackedOut ? null : image?.imageUrl,
                      enabled: false,
                      glowEnabled: false,
                      onReveal: onReveal,
                      onTapRevealed: onTapRevealed,
                      cardSkinId: room.cardSkinId,
                      pendingRevealTileIndex: room.pendingRevealTileIndex,
                      revealDeadlineMs: room.revealDeadlineMs,
                      spotlightCells: _isBlackedOut ? const {} : spotlightCells,
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
                    // Endgame escalation: a pulsing red vignette ramps up as the
                    // board fills past 75% (and harder past 85%), making the race
                    // to guess feel urgent. Suppressed while blacked out.
                    if (!_isBlackedOut && revealRatio >= 0.75)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: _EndgameVignette(ratio: revealRatio),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            AnswerSlots(answer: image?.answer ?? '', isMyTurn: isMyTurn),
            if (room.isLetterTurnActive)
              LetterTurnPanel(
                answer: room.letterTurnAnswer!,
                revealedSlots: room.letterTurnRevealedSlots.toSet(),
                guessedLetters: room.letterTurnGuessedLetters,
                isMyTurn: currentUserId != null &&
                    room.letterTurnPlayerId == currentUserId,
                turnPlayerName:
                    room.players[room.letterTurnPlayerId]?.name ?? '',
                deadlineMs: room.letterTurnDeadlineMs,
                onGuessLetter: onGuessLetterTurn ?? (_) {},
              ),
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
              onBuyReveal: onBuyReveal,
              revealBuyPrice: revealBuyPrice,
              revealBuyCount: revealBuyCount,
              maxRevealBuys: maxRevealBuys,
              detectiveActions: detectiveActions,
              showSkipVote: room.skipVoteEligible(revealRatio),
              skipVoteCount: room.skipVoteCount,
              skipVoteThreshold: room.skipVoteThreshold,
              iVotedSkip:
                  userId != null && room.skipVotes.contains(userId),
              onVoteSkip: onVoteSkip,
            ),
          ],
        ),

        // ── Dramatic guess overlay — opened locally by THIS player ─
        // Parallel guessing: shown when this client opened its own input, so
        // multiple players can be guessing simultaneously on their own screens.
        if (showGuessInput && room.phase == GamePhase.playing)
          GuessModeOverlay(
            key: ValueKey('guess-overlay-$localGuessDeadlineMs'),
            guesserName: room.players[currentUserId]?.name ?? '',
            isMyGuess: true,
            deadlineMs: localGuessDeadlineMs,
            answer: image?.answer ?? '',
            onSubmit: onGuessSubmit,
            onCancel: onGuessCancel,
            revealedLetterCount: revealedLetterCount,
            onBuyLetter: onBuyLetter,
            nextLetterPrice: nextLetterPrice,
            showBuyLetter: showBuyLetter,
            // A proverb is a whole phrase — allow up to 24 letter slots (the
            // longest baked answer is 19; words wrap to extra rows).
            maxLetters: room.isProverbs ? 24 : 12,
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

/// A pulsing red vignette drawn over the board during the endgame. Intensity
/// scales from the 0.75 (endgame) threshold up to and beyond 0.85 (super-
/// endgame), turning "almost solved" into visible, breathing pressure.
class _EndgameVignette extends StatefulWidget {
  final double ratio;

  const _EndgameVignette({required this.ratio});

  @override
  State<_EndgameVignette> createState() => _EndgameVignetteState();
}

class _EndgameVignetteState extends State<_EndgameVignette>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_EndgameVignette oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Pulse faster the deeper into the endgame we are (down to ~640ms).
    final superT = ((widget.ratio - 0.85) / 0.15).clamp(0.0, 1.0);
    final ms = (1100 - 460 * superT).round();
    if (ms != _pulse.duration?.inMilliseconds) {
      _pulse.duration = Duration(milliseconds: ms);
      _pulse
        ..reset()
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Base intensity from 0 at 0.75 to 1 at ~0.95.
    final base = ((widget.ratio - 0.75) / 0.20).clamp(0.0, 1.0);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final pulse = 0.55 + 0.45 * _pulse.value; // 0.55 → 1.0
        final strength = base * pulse;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: RadialGradient(
              radius: 0.95,
              colors: [
                Colors.transparent,
                Colors.transparent,
                const Color(0xFFE53935).withOpacity(0.06 + 0.30 * strength),
              ],
              stops: const [0.0, 0.62, 1.0],
            ),
            border: Border.all(
              color: const Color(0xFFFF5252).withOpacity(0.18 + 0.55 * strength),
              width: 1.5 + 1.5 * strength,
            ),
          ),
        );
      },
    );
  }
}



/// Persistent topic chip for the חי/צומח/דומם heat — shows the current category
/// (with emoji) and the round position, visible at every stage of the round.
class _HeatTopicChip extends StatelessWidget {
  final RoomModel room;
  const _HeatTopicChip({required this.room});

  @override
  Widget build(BuildContext context) {
    final cat = GameCategories.byId(room.selectedCategory);
    // Admin display-name override from the content manifest, else built-in name.
    final label = ContentManifestService.instance
            .topicLabel(room.selectedCategory) ??
        cat.nameHe;
    final total = room.heatImageIds.length;
    final round = (room.heatRoundIndex + 1).clamp(1, total == 0 ? 1 : total);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF07101F).withOpacity(0.72),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF20A8E0).withOpacity(0.45)),
          ),
          child: Text(
            '${cat.emoji}  $label   ·   סבב $round/$total',
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
