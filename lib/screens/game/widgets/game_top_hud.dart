import 'dart:async';

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
  });

  @override
  Widget build(BuildContext context) {
    final isEndgame = revealRatio >= 0.75;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
          decoration: BoxDecoration(
            color: const Color(0xFF07101F).withOpacity(0.82),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isEndgame
                  ? const Color(0xFFFF9F43).withOpacity(0.18)
                  : Colors.white.withOpacity(0.06),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
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
                    child: _TurnInfo(
                      name: currentPlayerName,
                      revealedText: revealedText,
                      isMyTurn: isMyTurn,
                      turnPhase: turnPhase,
                      isMyGuessOpportunity: isMyGuessOpportunity,
                      isMyGuessModeActive: isMyGuessModeActive,
                      guessModePlayerName: guessModePlayerName,
                      guessOpportunityDeadlineMs: guessOpportunityDeadlineMs,
                      isLastTile: isLastTile,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const CoinDisplay(compact: true),
                      const SizedBox(height: 3),
                      _PrizePotentialChip(
                        isSolo: isSolo,
                        revealedCount: revealedCount,
                        totalTiles: totalTiles,
                      ),
                    ],
                  ),
                ],
              ),
              if (players.isNotEmpty) ...[
                const SizedBox(height: 6),
                SizedBox(
                  height: 24,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: players.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 5),
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
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 17),
      ),
    );
  }
}

class _TurnInfo extends StatefulWidget {
  final String name;
  final String revealedText;
  final bool isMyTurn;
  final TurnPhase turnPhase;
  final bool isMyGuessOpportunity;
  final bool isMyGuessModeActive;
  final String guessModePlayerName;
  final int? guessOpportunityDeadlineMs;
  final bool isLastTile;

  const _TurnInfo({
    required this.name,
    required this.revealedText,
    required this.isMyTurn,
    required this.turnPhase,
    required this.isMyGuessOpportunity,
    required this.isMyGuessModeActive,
    required this.guessModePlayerName,
    this.guessOpportunityDeadlineMs,
    this.isLastTile = false,
  });

  @override
  State<_TurnInfo> createState() => _TurnInfoState();
}

class _TurnInfoState extends State<_TurnInfo> {
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
    final (label, labelColor) = _phaseLabel();
    final isGuessMode = widget.turnPhase == TurnPhase.guessMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: isGuessMode ? 14 : 11,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          widget.name.isEmpty ? 'ממתין לשחקן' : widget.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1),
        ),
        if (!isGuessMode) ...[
          const SizedBox(height: 4),
          Text(
            'גלויות ${widget.revealedText}',
            style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ],
    );
  }

  (String, Color) _phaseLabel() {
    switch (widget.turnPhase) {
      case TurnPhase.revealTurn:
        if (widget.isLastTile) {
          return widget.isMyTurn
              ? ('גילוי אחרון!', const Color(0xFFFF3B30))
              : ('ממתין לגילוי האחרון', const Color(0xFFFF6B35));
        }
        return widget.isMyTurn
            ? ('גלה קלף', Colors.white)
            : ('${widget.name.isEmpty ? 'יריב' : widget.name} מגלה', const Color(0xFF6A9CC4));
      case TurnPhase.guessOpportunity:
        if (widget.isMyGuessOpportunity) {
          return ('האם אתה יודע?', const Color(0xFFFFE082));
        }
        if (widget.guessOpportunityDeadlineMs != null) {
          final remaining = widget.guessOpportunityDeadlineMs! - _nowMs;
          if (remaining <= 2000) {
            return ('ייתכן שינחש!', const Color(0xFFFF3B30));
          } else if (remaining <= 3500) {
            return ('יריב שוקל...', const Color(0xFFFF9F43));
          }
        }
        return ('${widget.name.isEmpty ? 'יריב' : widget.name} מחליט...', const Color(0xFF87CEEB).withOpacity(0.80));
      case TurnPhase.guessMode:
        final gName = widget.guessModePlayerName.isEmpty ? 'יריב' : widget.guessModePlayerName;
        return widget.isMyGuessModeActive
            ? ('אתה מנחש!', const Color(0xFF00F2FF))
            : ('$gName מנחש!', const Color(0xFFFF6B35));
      case TurnPhase.resolvingGuess:
      case TurnPhase.roundOver:
        return ('סיום סיבוב', Colors.white54);
    }
  }
}

class _PlayerChip extends StatelessWidget {
  final PlayerModel player;
  final bool active;
  const _PlayerChip({required this.player, required this.active});

  @override
  Widget build(BuildContext context) {
    if (active) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF162E44),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 72),
              child: Text(player.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 4),
            Text('${player.score}',
                style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 11, fontWeight: FontWeight.w900)),
          ],
        ),
      );
    }

    // Inactive: compact initial circle + score only
    final initial = player.name.isNotEmpty ? player.name[0].toUpperCase() : '?';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, height: 1)),
            ),
          ),
          const SizedBox(width: 4),
          Text('${player.score}',
              style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

// Prize Potential chip — shows actual achievable coins from RewardCalculator.
// Animates on every reveal: scale pulse + orange flash + lateral shake.
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
