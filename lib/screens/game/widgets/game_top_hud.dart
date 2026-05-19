import 'package:flutter/material.dart';

import '../../../models/player_model.dart';
import '../../../widgets/economy/coin_display.dart';

class TopHud extends StatelessWidget {
  final List<PlayerModel> players;
  final String? currentPlayerId;
  final String currentPlayerName;
  final String revealedText;
  final VoidCallback onBack;
  final bool isMyTurn;

  const TopHud({
    required this.players,
    required this.currentPlayerId,
    required this.currentPlayerName,
    required this.revealedText,
    required this.onBack,
    required this.isMyTurn,
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
            border: Border.all(
              color: isMyTurn
                  ? const Color(0xFFD4AF37).withOpacity(0.72)
                  : const Color(0xFF87CEEB).withOpacity(0.16),
              width: isMyTurn ? 1.8 : 1.0,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 7)),
              if (isMyTurn)
                BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.22), blurRadius: 18, spreadRadius: 1),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _BackButton(onTap: onBack),
                  const SizedBox(width: 8),
                  Expanded(child: _TurnInfo(name: currentPlayerName, revealedText: revealedText, isMyTurn: isMyTurn)),
                  const SizedBox(width: 8),
                  const CoinDisplay(compact: true),
                ],
              ),
              if (players.isNotEmpty) ...[
                const SizedBox(height: 6),
                SizedBox(
                  height: 28,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: players.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 5),
                    itemBuilder: (context, index) {
                      final player = players[index];
                      final isActive = player.id == currentPlayerId;
                      return _PlayerChip(
                        player: player,
                        active: isActive,
                        isMyTurn: isActive && isMyTurn,
                      );
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
        width: 44,
        height: 44,
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
  final bool isMyTurn;
  const _TurnInfo({required this.name, required this.revealedText, required this.isMyTurn});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isMyTurn ? '● התור שלי' : '● תור היריב',
          style: TextStyle(
            color: isMyTurn
                ? const Color(0xFFD4AF37)
                : const Color(0xFFFF6B35),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(name.isEmpty ? 'ממתין לשחקן' : name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1)),
        const SizedBox(height: 3),
        Text('גלויות $revealedText', style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _PlayerChip extends StatefulWidget {
  final PlayerModel player;
  final bool active;
  final bool isMyTurn;

  const _PlayerChip({
    required this.player,
    required this.active,
    this.isMyTurn = false,
  });

  @override
  State<_PlayerChip> createState() => _PlayerChipState();
}

class _PlayerChipState extends State<_PlayerChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.active) {
      return AnimatedBuilder(
        animation: _glow,
        builder: (_, child) {
          final t = Curves.easeInOut.transform(_glow.value);
          final glowColor = widget.isMyTurn
              ? Color.fromRGBO(0, 242, 255, 0.20 + 0.35 * t)
              : Color.fromRGBO(212, 175, 55, 0.18 + 0.14 * t);
          final blurRadius = widget.isMyTurn ? 18.0 : 10.0;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFFE082), Color(0xFFD4AF37), Color(0xFFA1811A)]),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
              boxShadow: [
                BoxShadow(color: glowColor, blurRadius: blurRadius, spreadRadius: widget.isMyTurn ? 1.0 : 0.0),
              ],
            ),
            child: child,
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 72),
              child: Text(widget.player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFF07101F),
                      fontSize: 12,
                      fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 4),
            Text('${widget.player.score}',
                style: TextStyle(
                    color: const Color(0xFF07101F).withOpacity(0.82),
                    fontSize: 11,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      );
    }

    // Inactive: compact initial circle + score only
    final initial =
        widget.player.name.isNotEmpty ? widget.player.name[0].toUpperCase() : '?';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.14),
            ),
            child: Center(
              child: Text(initial,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      height: 1)),
            ),
          ),
          const SizedBox(width: 4),
          Text('${widget.player.score}',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
