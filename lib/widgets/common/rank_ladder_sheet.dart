import 'package:flutter/material.dart';

import '../../core/constants/player_rank.dart';

PlayerRank? _nextRank(PlayerRank r) =>
    r.index + 1 < PlayerRank.values.length
        ? PlayerRank.values[r.index + 1]
        : null;

/// A rank "medallion" — the tier emoji inside a rank-colored glowing ring.
class RankEmblem extends StatelessWidget {
  final PlayerRank rank;
  final double size;
  const RankEmblem({super.key, required this.rank, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: rank.color.withOpacity(0.18),
        border: Border.all(color: rank.color.withOpacity(0.75), width: 1.5),
        boxShadow: [
          BoxShadow(color: rank.color.withOpacity(0.3), blurRadius: 12),
        ],
      ),
      child: Text(rank.emoji, style: TextStyle(fontSize: size * 0.46)),
    );
  }
}

/// Tappable summary of the player's current rank + progress to the next tier.
/// Tapping opens the full [RankLadderSheet].
class RankBadgeCard extends StatelessWidget {
  final int totalPoints;
  const RankBadgeCard({super.key, required this.totalPoints});

  @override
  Widget build(BuildContext context) {
    final rank = PlayerRankX.fromPoints(totalPoints);
    final next = _nextRank(rank);
    final color = rank.color;
    final toNext =
        next == null ? 0 : (next.minPoints - totalPoints).clamp(0, 999999);
    final progress = next == null
        ? 1.0
        : ((totalPoints - rank.minPoints) / (next.minPoints - rank.minPoints))
            .clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () => RankLadderSheet.show(context, totalPoints),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0D1E30).withOpacity(0.9),
              color.withOpacity(0.18),
            ],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.55), width: 1.2),
        ),
        child: Row(
          children: [
            RankEmblem(rank: rank, size: 46),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'דרגה: ',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600),
                      ),
                      Text(
                        rank.label,
                        style: TextStyle(
                            color: color,
                            fontSize: 16,
                            fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rank.description,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6), fontSize: 11.5),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white.withOpacity(0.10),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    next == null
                        ? 'הגעת לדרגה הגבוהה ביותר'
                        : 'עוד $toNext נק׳ לדרגת ${next.label}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_left_rounded, color: color.withOpacity(0.8)),
          ],
        ),
      ),
    );
  }
}

/// Full ladder of all 7 tiers (legend at the top), with the player's current
/// rank highlighted and each tier's threshold + meaning. Explains "where is my
/// rank" and "what does each rank mean" in one place.
class RankLadderSheet extends StatelessWidget {
  final int totalPoints;
  const RankLadderSheet({super.key, required this.totalPoints});

  static Future<void> show(BuildContext context, int totalPoints) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RankLadderSheet(totalPoints: totalPoints),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = PlayerRankX.fromPoints(totalPoints);
    final ranks = PlayerRank.values.reversed.toList(); // legend first
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A1524),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 14),
              const Text(
                'סולם הדרגות',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'יש לך $totalPoints נקודות',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6), fontSize: 13),
              ),
              const SizedBox(height: 16),
              ...ranks.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RankRow(
                    rank: r,
                    isCurrent: r == current,
                    achieved: totalPoints >= r.minPoints,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final PlayerRank rank;
  final bool isCurrent;
  final bool achieved;
  const _RankRow({
    required this.rank,
    required this.isCurrent,
    required this.achieved,
  });

  @override
  Widget build(BuildContext context) {
    final color = rank.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrent
            ? color.withOpacity(0.16)
            : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? color.withOpacity(0.8)
              : Colors.white.withOpacity(0.06),
          width: isCurrent ? 1.4 : 1,
        ),
      ),
      child: Opacity(
        opacity: achieved ? 1.0 : 0.5,
        child: Row(
          children: [
            RankEmblem(rank: rank, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        rank.label,
                        style: TextStyle(
                            color: achieved ? color : Colors.white70,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: color.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(999)),
                          child: const Text(
                            'אתה כאן',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    rank.description,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.55), fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${rank.minPoints}+',
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
