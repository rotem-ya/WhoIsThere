import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/candy_theme.dart';
import '../../models/daily_quest.dart';
import '../../providers/providers.dart';
import '../../services/sfx_service.dart';
import 'coin_fly.dart';
import 'coin_icon.dart';

/// A slim daily-quest bar for the home screen: shows the rotating quest, a
/// progress track, and a claim button when it's complete. Collapses to nothing
/// while there's no active quest, so it never crowds a small screen.
class DailyQuestCard extends ConsumerStatefulWidget {
  const DailyQuestCard({super.key});

  @override
  ConsumerState<DailyQuestCard> createState() => _DailyQuestCardState();
}

class _DailyQuestCardState extends ConsumerState<DailyQuestCard> {
  String? _initedDayKey;
  bool _claiming = false;
  final GlobalKey _key = GlobalKey();

  int? _wins;
  int? _plays;
  int? _discoveries;

  Future<void> _claim() async {
    if (_claiming) return;
    final uid = ref.read(firebaseUserProvider).valueOrNull?.uid;
    if (uid == null || _wins == null) return;
    setState(() => _claiming = true);
    try {
      final coins = await ref.read(dailyQuestServiceProvider).claim(
            uid,
            wins: _wins!,
            plays: _plays!,
            discoveries: _discoveries!,
          );
      if (!mounted) return;
      setState(() => _claiming = false);
      if (coins != null && coins > 0) {
        HapticFeedback.mediumImpact();
        SfxService.instance.questComplete();
        SfxService.instance.coinGain();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final box = _key.currentContext?.findRenderObject() as RenderBox?;
          if (box == null || !box.hasSize) return;
          final from = box.localToGlobal(box.size.center(Offset.zero));
          CoinFly.burst(context, from: from, count: (coins ~/ 5).clamp(6, 14));
        });
      }
    } catch (_) {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider).valueOrNull;
    final user = ref.watch(currentUserProvider).valueOrNull;
    final docAsync = ref.watch(dailyQuestDocProvider);
    _wins = wallet?.totalMatchesWon;
    _plays = wallet?.totalMatchesPlayed;
    _discoveries = user?.discoveredImageIds.length;

    // Initialise today's quest once the counters are known (writes a baseline
    // if the stored day is stale or missing).
    final today = questDayKey();
    final uid = ref.watch(firebaseUserProvider).valueOrNull?.uid;
    if (uid != null && wallet != null && docAsync.hasValue &&
        _initedDayKey != today) {
      _initedDayKey = today;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(dailyQuestServiceProvider).ensureToday(
              uid,
              wins: wallet.totalMatchesWon,
              plays: wallet.totalMatchesPlayed,
              discoveries: user?.discoveredImageIds.length ?? 0,
            );
      });
    }

    final state = ref.watch(dailyQuestStateProvider);
    final show = state != null && !state.claimed;

    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      child: !show
          ? const SizedBox(width: double.infinity)
          : Container(
              key: _key,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Candy.surfaceLow.withOpacity(0.55),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Candy.gold.withOpacity(0.30)),
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Text(state.template.emoji,
                      style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row: short label + reward (both short, never clip).
                        Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            const Text(
                              'משימה יומית',
                              style: TextStyle(
                                color: Candy.gold,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text.rich(
                              TextSpan(text: '+${state.template.reward} ', children: [
                                coinSpan(size: 11),
                              ]),
                              style: const TextStyle(
                                color: Candy.gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // The task itself gets the full width and may wrap.
                        Text(
                          state.template.label,
                          textDirection: TextDirection.rtl,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: state.ratio,
                            minHeight: 6,
                            backgroundColor: Colors.white.withOpacity(0.10),
                            valueColor: const AlwaysStoppedAnimation(Candy.teal),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (state.canClaim)
                    GestureDetector(
                      onTap: _claiming ? null : _claim,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFE082), Candy.gold],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Candy.gold.withOpacity(0.4),
                                blurRadius: 10),
                          ],
                        ),
                        child: _claiming
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFF07101F)))
                            : const Text('אסוף',
                                style: TextStyle(
                                    color: Color(0xFF07101F),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900)),
                      ),
                    )
                  else
                    Text(
                      '${state.progress}/${state.template.target}',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w900),
                    ),
                ],
              ),
            ),
    );
  }
}
