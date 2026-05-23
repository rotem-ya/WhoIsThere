import 'package:flutter/material.dart';

import '../../../core/constants/game_constants.dart';
import '../../../models/player_model.dart';
import '../../../services/reward_calculator.dart';
import '../../../widgets/economy/coin_display.dart';

String? _prizePressureLabel(double ratio) {
  if (ratio >= 0.92) return 'פרס מינימלי';
  if (ratio >= 0.85) return 'הזדמנות אחרונה';
  if (ratio >= 0.75) return 'סיכון עולה';
  return null;
}

class TopHud extends StatelessWidget {
  final List<PlayerModel> players;
  final String? currentPlayerId;
  final String currentPlayerName;
  final String revealedText;
  final VoidCallback onBack;
  final bool isMyTurn;
  final TurnPhase turnPhase;
  final bool isMyGuessOpportunity;
  final bool isMyGuessModeActive;
  final String guessModePlayerName;
  final double revealRatio;
  final bool isSolo;
  final int revealedCount;
  final int totalTiles;
  final int? guessOpportunityDeadlineMs;
  final bool isLastTile;
  final int potTotal;

  const TopHud({
    required this.players,
    required this.currentPlayerId,
    required this.currentPlayerName,
    required this.revealedText,
    required this.onBack,
    required this.isMyTurn,
    required this.turnPhase,
    required this.isMyGuessOpportunity,
    required this.isMyGuessModeActive,
    required this.guessModePlayerName,
    this.revealRatio = 0.0,
    this.isSolo = false,
    this.revealedCount = 0,
    this.totalTiles = 1,
    this.guessOpportunityDeadlineMs,
    this.isLastTile = false,
    this.potTotal = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isEndgame = revealRatio >= 0.75;
    final isGuessMode = turnPhase == TurnPhase.guessMode;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 8, 12, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button — outside the card, small and clean
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: _SmallBackButton(onTap: onBack),
            ),
            const SizedBox(width: 6),
            // Main HUD card
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF081E3A).withOpacity(0.90),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isEndgame
                        ? const Color(0xFFFF9F43).withOpacity(0.55)
                        : const Color(0xFF1890D0).withOpacity(0.65),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0040A0).withOpacity(0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        // Left: revealed count + optional guesser indicator (no phase labels)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isGuessMode) ...[
                                Text(
                                  isMyGuessModeActive
                                      ? 'אתה מנחש! 🎯'
                                      : 'מנחש: ${guessModePlayerName.isEmpty ? 'יריב' : guessModePlayerName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isMyGuessModeActive
                                        ? const Color(0xFF00F2FF)
                                        : const Color(0xFFFF6B35),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 3),
                              ],
                              Text(
                                'גלויות $revealedText',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.55),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Right: coin balance + pot/prize chip
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const CoinDisplay(compact: true),
                            const SizedBox(height: 3),
                            if (potTotal > 0)
                              _PotChip(potTotal: potTotal)
                            else
                              _PrizePotentialChip(
                                isSolo: isSolo,
                                revealedCount: revealedCount,
                                totalTiles: totalTiles,
                              ),
                          ],
                        ),
                      ],
                    ),
                    // Dedicated player names row — full name, up to 10 chars, up to 8 players
                    if (players.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 26,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: players.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 5),
                          itemBuilder: (context, index) {
                            return _PlayerNameChip(player: players[index]);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SmallBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF0D1E30).withOpacity(0.75),
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF2A5070).withOpacity(0.45),
            width: 0.8,
          ),
        ),
        child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white60, size: 13),
      ),
    );
  }
}

class _PlayerNameChip extends StatelessWidget {
  final PlayerModel player;
  const _PlayerNameChip({required this.player});

  @override
  Widget build(BuildContext context) {
    final name = player.name.length > 10 ? player.name.substring(0, 10) : player.name;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1E30).withOpacity(0.60),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2A5070).withOpacity(0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${player.score}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PotChip extends StatelessWidget {
  final int potTotal;
  const _PotChip({required this.potTotal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1000).withOpacity(0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.75), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏆', style: TextStyle(fontSize: 11)),
          const SizedBox(width: 3),
          Text(
            '$potTotal',
            style: const TextStyle(
              color: Color(0xFFFFE14D),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrizePotentialChip extends StatefulWidget {
  final bool isSolo;
  final int revealedCount;
  final int totalTiles;

  const _PrizePotentialChip({
    required this.isSolo,
    required this.revealedCount,
    required this.totalTiles,
  });

  @override
  State<_PrizePotentialChip> createState() => _PrizePotentialChipState();
}

class _PrizePotentialChipState extends State<_PrizePotentialChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;
  late Animation<double> _flashOpacity;
  late Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.84), weight: 28),
      TweenSequenceItem(tween: Tween(begin: 0.84, end: 1.0), weight: 72),
    ]).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut));
    _flashOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.36), weight: 22),
      TweenSequenceItem(tween: Tween(begin: 0.36, end: 0.0), weight: 78),
    ]).animate(_anim);
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -3.0), weight: 18),
      TweenSequenceItem(tween: Tween(begin: -3.0, end: 3.0), weight: 44),
      TweenSequenceItem(tween: Tween(begin: 3.0, end: 0.0), weight: 38),
    ]).animate(_anim);
  }

  @override
  void didUpdateWidget(_PrizePotentialChip old) {
    super.didUpdateWidget(old);
    if (widget.revealedCount > old.revealedCount) {
      _anim.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coins = RewardCalculator.calculateCurrentPrizePotential(
      isSolo: widget.isSolo,
      revealedCount: widget.revealedCount,
      totalTiles: widget.totalTiles,
    );
    final maxCoins = RewardCalculator.calculateCurrentPrizePotential(
      isSolo: widget.isSolo,
      revealedCount: 0,
      totalTiles: widget.totalTiles,
    );
    final coinRatio = maxCoins > 0 ? coins / maxCoins : 0.0;
    final ratio = widget.totalTiles > 0 ? widget.revealedCount / widget.totalTiles : 0.0;
    final pressureLabel = _prizePressureLabel(ratio);

    final Color valueColor;
    if (coinRatio >= 0.70) {
      valueColor = const Color(0xFF4CAF50);
    } else if (coinRatio >= 0.45) {
      valueColor = const Color(0xFFD4AF37);
    } else if (coinRatio >= 0.33) {
      valueColor = const Color(0xFFFF9F43);
    } else {
      valueColor = const Color(0xFFFF3B30);
    }

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shake.value, 0),
          child: Transform.scale(
            scale: _scale.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: _flashOpacity.value > 0.01
                    ? const Color(0xFFFF6B35).withOpacity(_flashOpacity.value)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
              ),
              child: child,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pressureLabel != null)
            Text(
              pressureLabel,
              style: const TextStyle(
                color: Color(0xFFFF3B30),
                fontSize: 8,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          Text(
            'פרס $coins 🪙',
            style: TextStyle(
              color: valueColor,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
