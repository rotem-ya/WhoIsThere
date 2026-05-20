import 'package:flutter/material.dart';

import '../../../core/constants/game_constants.dart';
import '../../../models/player_model.dart';
import '../../../widgets/economy/coin_display.dart';

// Piecewise linear prize potential decay.
// 0–20% reveal → 100%→90% (slow)
// 20–50%       → 90%→70%  (medium)
// 50–75%       → 70%→45%  (aggressive)
// 75–100%      → 45%→15%  (severe)
double _computePrizePotential(double ratio) {
  if (ratio <= 0.0) return 1.0;
  if (ratio <= 0.20) return 1.0 - (ratio / 0.20) * 0.10;
  if (ratio <= 0.50) return 0.90 - ((ratio - 0.20) / 0.30) * 0.20;
  if (ratio <= 0.75) return 0.70 - ((ratio - 0.50) / 0.25) * 0.25;
  return (0.45 - ((ratio - 0.75) / 0.25) * 0.30).clamp(0.0, 1.0);
}

String? _prizePressureLabel(double ratio) {
  if (ratio >= 0.92) return 'כמעט אין פרס';
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF07101F).withOpacity(0.82),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isEndgame
                  ? const Color(0xFFFF9F43).withOpacity(0.55)
                  : const Color(0xFFD4AF37).withOpacity(0.30),
              width: isEndgame ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 7)),
              if (isEndgame)
                BoxShadow(
                  color: const Color(0xFFFF6B35).withOpacity(0.20),
                  blurRadius: 24,
                  spreadRadius: 2,
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
                    child: _TurnInfo(
                      name: currentPlayerName,
                      revealedText: revealedText,
                      isMyTurn: isMyTurn,
                      turnPhase: turnPhase,
                      isMyGuessOpportunity: isMyGuessOpportunity,
                      isMyGuessModeActive: isMyGuessModeActive,
                      guessModePlayerName: guessModePlayerName,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const CoinDisplay(compact: true),
                      const SizedBox(height: 3),
                      _PrizePotentialChip(revealRatio: revealRatio),
                    ],
                  ),
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
  final TurnPhase turnPhase;
  final bool isMyGuessOpportunity;
  final bool isMyGuessModeActive;
  final String guessModePlayerName;

  const _TurnInfo({
    required this.name,
    required this.revealedText,
    required this.isMyTurn,
    required this.turnPhase,
    required this.isMyGuessOpportunity,
    required this.isMyGuessModeActive,
    required this.guessModePlayerName,
  });

  @override
  Widget build(BuildContext context) {
    final (label, labelColor) = _phaseLabel();
    final isGuessMode = turnPhase == TurnPhase.guessMode;

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
          name.isEmpty ? 'ממתין לשחקן' : name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1),
        ),
        if (!isGuessMode) ...[
          const SizedBox(height: 4),
          Text(
            'גלויות $revealedText',
            style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ],
    );
  }

  (String, Color) _phaseLabel() {
    switch (turnPhase) {
      case TurnPhase.revealTurn:
        return isMyTurn
            ? ('גלה קלף', const Color(0xFFD4AF37))
            : ('${name.isEmpty ? 'יריב' : name} מגלה', const Color(0xFF87CEEB).withOpacity(0.85));
      case TurnPhase.guessOpportunity:
        return isMyGuessOpportunity
            ? ('האם אתה יודע?', const Color(0xFFFFE082))
            : ('${name.isEmpty ? 'יריב' : name} מחליט...', const Color(0xFF87CEEB).withOpacity(0.80));
      case TurnPhase.guessMode:
        final gName = guessModePlayerName.isEmpty ? 'יריב' : guessModePlayerName;
        return isMyGuessModeActive
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
          gradient: const LinearGradient(colors: [Color(0xFFFFE082), Color(0xFFD4AF37), Color(0xFFA1811A)]),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
          boxShadow: [BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.28), blurRadius: 10)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 72),
              child: Text(player.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF07101F), fontSize: 12, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 4),
            Text('${player.score}',
                style: TextStyle(color: const Color(0xFF07101F).withOpacity(0.82), fontSize: 11, fontWeight: FontWeight.w900)),
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

// Prize Potential chip — animates on every reveal (scale pulse + orange flash + shake).
class _PrizePotentialChip extends StatefulWidget {
  final double revealRatio;
  const _PrizePotentialChip({required this.revealRatio});

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
    if (widget.revealRatio > old.revealRatio + 0.001) {
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
    final potential = _computePrizePotential(widget.revealRatio);
    final pct = (potential * 100).round();
    final pressureLabel = _prizePressureLabel(widget.revealRatio);

    final Color valueColor;
    if (pct >= 70) {
      valueColor = const Color(0xFF4CAF50);
    } else if (pct >= 45) {
      valueColor = const Color(0xFFD4AF37);
    } else if (pct >= 25) {
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
            'פרס $pct%',
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
