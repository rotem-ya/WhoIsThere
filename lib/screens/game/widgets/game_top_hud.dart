import 'package:flutter/material.dart';

import '../../../models/player_model.dart';
import '../../../widgets/economy/coin_display.dart';

class TopHud extends StatelessWidget {
  final String code;
  final List<PlayerModel> players;
  final String? currentPlayerId;
  final String currentPlayerName;
  final String revealedText;
  final VoidCallback onBack;

  const TopHud({
    required this.code,
    required this.players,
    required this.currentPlayerId,
    required this.currentPlayerName,
    required this.revealedText,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF07101F).withOpacity(0.82),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.30)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 7))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _BackButton(onTap: onBack),
                  const SizedBox(width: 8),
                  Expanded(child: _TurnInfo(name: currentPlayerName, revealedText: revealedText, code: code)),
                  const SizedBox(width: 8),
                  const CoinDisplay(compact: true),
                ],
              ),
              if (players.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: players.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final player = players[index];
                      return _PlayerChip(player: player, active: player.id == currentPlayerId);
                    },
                  ),
                ),
              ],
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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 17),
      ),
    );
  }
}

class _TurnInfo extends StatelessWidget {
  final String name;
  final String revealedText;
  final String code;
  const _TurnInfo({required this.name, required this.revealedText, required this.code});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      alignment: Alignment.centerRight,
      fit: BoxFit.scaleDown,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('תור עכשיו', style: TextStyle(color: const Color(0xFFD4AF37).withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w900, height: 1)),
          const SizedBox(height: 4),
          Text(name.isEmpty ? 'ממתין לשחקן' : name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, height: 1)),
          const SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('נחשפו $revealedText', style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(width: 12),
              Text(code, style: TextStyle(color: Colors.white.withOpacity(0.24), fontSize: 11, letterSpacing: 2.4, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
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
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: active ? const LinearGradient(colors: [Color(0xFFFFE082), Color(0xFFD4AF37), Color(0xFFA1811A)]) : null,
        color: active ? null : Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? Colors.white.withOpacity(0.18) : Colors.white.withOpacity(0.10)),
        boxShadow: active ? [BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.22), blurRadius: 10)] : const [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 78),
            child: Text(player.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? const Color(0xFF07101F) : Colors.white.withOpacity(0.76), fontSize: 12, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 5),
          Text('${player.score}', style: TextStyle(color: active ? const Color(0xFF07101F).withOpacity(0.82) : Colors.white.withOpacity(0.46), fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
