import 'package:flutter/material.dart';
class GameLayout extends StatelessWidget {
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
          _BotTypingBanner(botName: botTypingName, typedSoFar: botTypingText)
        else if (showBanner && bannerEvent != null)
          _GuessBanner(event: bannerEvent!, players: room.players),
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
