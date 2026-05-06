import 'package:flutter/material.dart';

import '../../../models/player_model.dart';

class TopHud extends StatelessWidget {
  final String code;
  final List<PlayerModel> players;
  final String? currentPlayerId;
  final String currentPlayerName;
  final String revealedText;
  final int myCoins;
  final int myLetterCards;
  final VoidCallback onBack;

  const TopHud({
    required this.code,
    required this.players,
    required this.currentPlayerId,
    required this.currentPlayerName,
    required this.revealedText,
    required this.myCoins,
    required this.myLetterCards,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
          decoration: BoxDecoration(
            color: const Color(0xFF07101F).withOpacity(0.78),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.34),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _BackButton(onTap: onBack),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TurnPanel(
                      currentPlayerName: currentPlayerName,
                      revealedText: revealedText,
                      code: code,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      CoinBadge(amount: myCoins),
                      if (myLetterCards > 0) ...[
                        const SizedBox(height: 5),
                        _LetterCardBadge(amount: myLetterCards),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 9),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: players.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 7),
                  itemBuilder: (context, index) {
                    final player = players[index];
                    final active = player.id == currentPlayerId;
                    return _PlayerChip(player: player, active: active);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 18),
      ),
    );
  }
}

class _TurnPanel extends StatelessWidget {
  final String currentPlayerName;
  final String revealedText;
  final String code;

  const _TurnPanel({
    required this.currentPlayerName,
    required this.revealedText,
    required this.code,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'תור עכשיו',
          maxLines: 1,
          style: TextStyle(
            color: const Color(0xFFD4AF37).withOpacity(0.88),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          currentPlayerName.isEmpty ? 'ממתין לשחקן' : currentPlayerName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              'נחשפו $revealedText',
              style: TextStyle(
                color: Colors.white.withOpacity(0.56),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              code,
              style: TextStyle(
                color: Colors.white.withOpacity(0.22),
                fontSize: 9,
                letterSpacing: 2.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final PlayerModel player;
  final bool active;

  const _PlayerChip({required this.player, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: active
            ? const LinearGradient(
                colors: [Color(0xFFD4AF37), Color(0xFFA1811A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : null,
        color: active ? null : Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? Colors.white.withOpacity(0.18)
              : Colors.white.withOpacity(0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 86),
            child: Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? const Color(0xFF07101F) : Colors.white.withOpacity(0.76),
                fontSize: 12,
                fontWeight: active ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '${player.score}',
            style: TextStyle(
              color: active ? const Color(0xFF07101F).withOpacity(0.82) : Colors.white.withOpacity(0.46),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class CoinBadge extends StatelessWidget {
  final int amount;

  const CoinBadge({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE082), Color(0xFFD4AF37), Color(0xFFA1811A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.24),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 13, height: 1)),
          const SizedBox(width: 3),
          Text(
            '$amount',
            style: const TextStyle(
              color: Color(0xFF07101F),
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _LetterCardBadge extends StatelessWidget {
  final int amount;

  const _LetterCardBadge({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF87CEEB).withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF87CEEB).withOpacity(0.28)),
      ),
      child: Text(
        '🔤 ×$amount',
        style: const TextStyle(
          color: Color(0xFF87CEEB),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}
