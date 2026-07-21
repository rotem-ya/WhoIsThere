import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/candy_theme.dart';

/// A 3x3 mini board whose tiles brighten in a diagonal wave, cycling through
/// the Candy accents — the app's branded stand-in for a loading spinner while
/// matchmaking / waiting for players. Self-contained (owns its ticker) so it
/// can drop in anywhere a "searching…" state appears.
class MatchmakingTiles extends StatefulWidget {
  final double tile;
  final double gap;

  const MatchmakingTiles({super.key, this.tile = 34, this.gap = 8});

  @override
  State<MatchmakingTiles> createState() => _MatchmakingTilesState();
}

class _MatchmakingTilesState extends State<MatchmakingTiles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  static const _accents = [
    Candy.teal,
    Candy.pink,
    Candy.tangerine,
    Candy.blue,
    Candy.gold,
  ];

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const grid = 3;
    final side = grid * widget.tile + (grid - 1) * widget.gap;
    return SizedBox(
      width: side,
      height: side,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final phase = _anim.value * 2 * math.pi;
          return Stack(
            children: [
              for (var r = 0; r < grid; r++)
                for (var c = 0; c < grid; c++)
                  Positioned(
                    left: c * (widget.tile + widget.gap),
                    top: r * (widget.tile + widget.gap),
                    width: widget.tile,
                    height: widget.tile,
                    child: _waveTile(r, c, phase),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _waveTile(int r, int c, double phase) {
    final d = (r + c) / 4.0; // 0..1 along the diagonal
    final t = (math.sin(phase - d * 2 * math.pi) + 1) / 2;
    final accent = _accents[(r * 3 + c) % _accents.length];
    final lit = Color.lerp(
        Colors.white.withOpacity(0.06), accent, Curves.easeInOut.transform(t))!;
    return Container(
      decoration: BoxDecoration(
        color: lit,
        borderRadius: BorderRadius.circular(widget.tile * 0.26),
        boxShadow: t > 0.6
            ? [BoxShadow(color: accent.withOpacity(0.5 * t), blurRadius: 12)]
            : null,
      ),
    );
  }
}
