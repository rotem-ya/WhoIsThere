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
  final String? guessModePlayerId;

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
    this.guessModePlayerId,
  });

  @override
  Widget build(BuildContext context) {
    final isEndgame = revealRatio >= 0.75;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Top info row — outside the card, free for future info ──────
            Row(
              children: [
                // Left: my coins · pot (when active) · bonus preview
                const CoinDisplay(compact: true),
                const SizedBox(width: 6),
                if (potTotal > 0) ...[
                  _PotChip(potTotal: potTotal),
                  const SizedBox(width: 4),
                ],
                _BonusPreviewChip(
                  isSolo: isSolo,
                  revealedCount: revealedCount,
                  totalTiles: totalTiles,
                ),
                const Spacer(),
                // Right: back to lobby
                _SmallBackButton(onTap: onBack),
              ],
            ),
            const SizedBox(height: 6),
            // ── Player names card — 2 per row ─────────────────────────────
            if (players.isNotEmpty)
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF081E3A).withOpacity(0.90),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isEndgame
                        ? const Color(0xFFFF9F43).withOpacity(0.55)
                        : const Color(0xFF1890D0).withOpacity(0.50),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0040A0).withOpacity(0.30),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _PlayerGrid(players: players, guessModePlayerId: guessModePlayerId),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Small back button (outside card) ──────────────────────────────────────────

class _SmallBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SmallBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFF0D1E30).withOpacity(0.75),
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF2A5070).withOpacity(0.45),
            width: 0.8,
          ),
        ),
        child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white60, size: 12),
      ),
    );
  }
}

// ── Player grid — 2 columns, pairs stacked ────────────────────────────────────

class _PlayerGrid extends StatelessWidget {
  final List<PlayerModel> players;
  final String? guessModePlayerId;
  const _PlayerGrid({required this.players, this.guessModePlayerId});

  @override
  Widget build(BuildContext context) {
    // Build pairs: [0,1], [2,3], [4,5], [6,7]
    final rows = <Widget>[];
    for (var i = 0; i < players.length; i += 2) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 4));
      rows.add(Row(
        children: [
          Expanded(child: _PlayerCell(player: players[i], isGuessing: players[i].id == guessModePlayerId)),
          if (i + 1 < players.length) ...[
            const SizedBox(width: 6),
            Expanded(child: _PlayerCell(player: players[i + 1], isGuessing: players[i + 1].id == guessModePlayerId)),
          ] else
            const Expanded(child: SizedBox()),
        ],
      ));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

class _PlayerCell extends StatelessWidget {
  final PlayerModel player;
  final bool isGuessing;
  const _PlayerCell({required this.player, this.isGuessing = false});

  @override
  Widget build(BuildContext context) {
    final name = player.name.length > 10 ? player.name.substring(0, 10) : player.name;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isGuessing
                ? const Color(0xFF1A2E10).withOpacity(0.75)
                : const Color(0xFF0D1E30).withOpacity(0.55),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isGuessing
                  ? const Color(0xFF4CAF50).withOpacity(0.50)
                  : const Color(0xFF2A5070).withOpacity(0.30),
              width: isGuessing ? 1.0 : 0.8,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isGuessing ? const Color(0xFF80C080) : Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isGuessing)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text('✍', style: TextStyle(fontSize: 10)),
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
        ),
        Positioned(
          top: -7,
          right: -5,
          child: _DiscoveredMicroBadge(count: player.discoveredCount),
        ),
      ],
    );
  }
}

// ── Discovered micro badge (superscript corner) ───────────────────────────────

class _DiscoveredMicroBadge extends StatelessWidget {
  final int count;
  const _DiscoveredMicroBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF04101E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF4A8BAA).withOpacity(0.5), width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌍', style: TextStyle(fontSize: 7)),
          const SizedBox(width: 1),
          Text(
            '$count',
            style: const TextStyle(
              color: Color(0xFF87CEEB),
              fontSize: 8,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pot chip ──────────────────────────────────────────────────────────────────

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

// ── Prize potential chip ──────────────────────────────────────────────────────

class _BonusPreviewChip extends StatefulWidget {
  final bool isSolo;
  final int revealedCount;
  final int totalTiles;

  const _BonusPreviewChip({
    required this.isSolo,
    required this.revealedCount,
    required this.totalTiles,
  });

  @override
  State<_BonusPreviewChip> createState() => _BonusPreviewChipState();
}

class _BonusPreviewChipState extends State<_BonusPreviewChip>
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
  void didUpdateWidget(_BonusPreviewChip old) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
            '+$coins 🔥',
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
