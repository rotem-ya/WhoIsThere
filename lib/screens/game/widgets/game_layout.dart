import 'package:flutter/material.dart';

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
  final bool isMyTurn;
  final bool isBusy;
  final int myCoins;
  final int myLetterCards;
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
    required this.isMyTurn,
    required this.isBusy,
    required this.myCoins,
    required this.myLetterCards,
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

    return Column(
      children: [
        TopHud(
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
          BotTypingBanner(botName: botTypingName, typedSoFar: botTypingText)
        else if (showBanner && bannerEvent != null)
          GuessBanner(event: bannerEvent!, players: room.players),
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
        AnswerSlots(answer: image?.answer ?? ''),
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
