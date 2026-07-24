import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/candy_theme.dart';
import '../../models/quests_state.dart';
import '../../providers/providers.dart';
import '../../services/rewards_config_service.dart';
import '../../services/sfx_service.dart';
import '../common/pressable.dart';
import 'coin_fly.dart';
import 'coin_icon.dart';
import 'daily_reward_sheet.dart';
import 'daily_spin_sheet.dart';

/// The unified "מרכז פרסים" (Rewards Hub): the daily spin, the daily reward,
/// and the daily + weekly quest list in one place. Opened from the home gifts
/// button.
void showRewardsHub(BuildContext context, WidgetRef ref) {
  SfxService.instance.sheetOpen();
  // Make sure today's / this week's quest periods exist before showing.
  final uid = ref.read(firebaseUserProvider).valueOrNull?.uid;
  final wallet = ref.read(walletProvider).valueOrNull;
  final user = ref.read(currentUserProvider).valueOrNull;
  if (uid != null && wallet != null) {
    final cfg = RewardsConfigService.instance.config;
    ref.read(questsServiceProvider).ensurePeriods(
          uid,
          wins: wallet.totalMatchesWon,
          plays: wallet.totalMatchesPlayed,
          discoveries: user?.discoveredImageIds.length ?? 0,
          dailyDefs: cfg.activeDaily,
          weeklyDefs: cfg.activeWeekly,
        );
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _RewardsHubSheet(),
  );
}

class _RewardsHubSheet extends ConsumerWidget {
  const _RewardsHubSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spinAvailable = isDailySpinAvailable(
        ref.watch(walletProvider).valueOrNull?.lastDailySpinAt);
    final happyMult = RewardsConfigService.instance.happyHourMultiplier;
    final happyActive = happyMult > 1;

    return Container(
      decoration: BoxDecoration(
        color: Candy.bgBottom,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Candy.gold.withOpacity(0.34), width: 1.2),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 20,
        top: 10,
        left: 18,
        right: 18,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Center(
              child: Text('🎁 מרכז פרסים',
                  style: TextStyle(
                      color: Candy.gold,
                      fontSize: 24,
                      fontWeight: FontWeight.w900)),
            ),
            if (happyActive) ...[
              const SizedBox(height: 10),
              _HappyHourBanner(
                  label: RewardsConfigService.instance.happyHourLabel,
                  multiplier: happyMult),
            ],
            const SizedBox(height: 16),
            // Spin + daily reward entries.
            Row(
              children: [
                Expanded(
                  child: _RewardTile(
                    emoji: '🎡',
                    title: 'גלגל המזל',
                    subtitle: spinAvailable ? 'סיבוב חינם מחכה!' : 'חזרו מחר',
                    ready: spinAvailable,
                    onTap: () {
                      Navigator.pop(context);
                      showDailySpinSheet(context, ref);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _RewardTile(
                    emoji: '🎁',
                    title: 'פרס יומי',
                    subtitle: 'מטבעות בכל יום',
                    ready: true,
                    onTap: () {
                      Navigator.pop(context);
                      showDailyRewardSheet(context, ref);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerRight,
              child: Text('משימות',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerRight,
              child: Text('השלימו משימות ואספו מטבעות',
                  style: TextStyle(color: Colors.white54, fontSize: 12.5)),
            ),
            const SizedBox(height: 10),
            const _QuestsList(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _HappyHourBanner extends StatelessWidget {
  final String label;
  final int multiplier;
  const _HappyHourBanner({required this.label, required this.multiplier});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFFF7A1A), Color(0xFFFFB03A)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFFF7A1A).withOpacity(0.45),
              blurRadius: 16,
              spreadRadius: 1),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⚡', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$label כל המטבעות ×$multiplier',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool ready;
  final VoidCallback onTap;
  const _RewardTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.ready,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          gradient: Candy.jellyFill(Candy.surface),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: ready ? Candy.gold.withOpacity(0.6) : Colors.white24,
            width: ready ? 1.4 : 1,
          ),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 30)),
                if (ready)
                  Positioned(
                    top: -3,
                    right: -6,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: Candy.teal,
                        shape: BoxShape.circle,
                        border: Border.all(color: Candy.bgBottom, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: ready ? Candy.gold : Colors.white54,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _QuestsList extends ConsumerWidget {
  const _QuestsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = ref.watch(questViewsProvider);
    if (views.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text('אין משימות כרגע. חזרו בקרוב!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13)),
      );
    }
    return Column(
      children: [
        for (final v in views)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _QuestRow(view: v),
          ),
      ],
    );
  }
}

class _QuestRow extends ConsumerStatefulWidget {
  final QuestView view;
  const _QuestRow({required this.view});

  @override
  ConsumerState<_QuestRow> createState() => _QuestRowState();
}

class _QuestRowState extends ConsumerState<_QuestRow> {
  bool _busy = false;

  Future<void> _claim() async {
    if (_busy) return;
    final uid = ref.read(firebaseUserProvider).valueOrNull?.uid;
    final wallet = ref.read(walletProvider).valueOrNull;
    final user = ref.read(currentUserProvider).valueOrNull;
    if (uid == null || wallet == null) return;
    setState(() => _busy = true);
    try {
      final coins = await ref.read(questsServiceProvider).claim(
            uid,
            def: widget.view.def,
            weekly: widget.view.weekly,
            wins: wallet.totalMatchesWon,
            plays: wallet.totalMatchesPlayed,
            discoveries: user?.discoveredImageIds.length ?? 0,
          );
      if (!mounted) return;
      if (coins != null && coins > 0) {
        HapticFeedback.mediumImpact();
        SfxService.instance.questComplete();
        SfxService.instance.coinGain();
        final box = context.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          CoinFly.burst(context,
              from: box.localToGlobal(box.size.center(Offset.zero)),
              count: (coins ~/ 6).clamp(6, 14));
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.view;
    final d = v.def;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: v.claimable
              ? Candy.gold.withOpacity(0.55)
              : Colors.white.withOpacity(0.09),
        ),
      ),
      child: Row(
        children: [
          Text(d.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  // Top-align so a 2-line title sits neatly beside the chip.
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (v.weekly)
                      Container(
                        margin: const EdgeInsets.only(left: 6, top: 1),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Candy.grape.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('שבועי',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800)),
                      ),
                    // Wrap to a second line before truncating; the weekly chip
                    // otherwise stole enough width to clip titles like
                    // "נצחו 15 משחקים השבוע".
                    Expanded(
                      child: Text(d.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.15)),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: v.ratio,
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.10),
                    valueColor: AlwaysStoppedAnimation(
                        v.complete ? Candy.gold : Candy.teal),
                  ),
                ),
                const SizedBox(height: 3),
                Text('${v.progress}/${d.target}',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 10.5)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _RewardChip(reward: d.reward, view: v, busy: _busy, onClaim: _claim),
        ],
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  final int reward;
  final QuestView view;
  final bool busy;
  final VoidCallback onClaim;
  const _RewardChip({
    required this.reward,
    required this.view,
    required this.busy,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    if (view.claimed) {
      return const Icon(Icons.check_circle_rounded, color: Candy.teal, size: 26);
    }
    if (view.claimable) {
      return SizedBox(
        height: 34,
        child: FilledButton(
          onPressed: busy ? null : onClaim,
          style: FilledButton.styleFrom(
            backgroundColor: Candy.gold,
            foregroundColor: const Color(0xFF07101F),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
          child: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF07101F)))
              : const Text('אסוף'),
        ),
      );
    }
    // Not complete: show the reward amount.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('+$reward',
            style: const TextStyle(
                color: Candy.gold, fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(width: 3),
        const CoinIcon(size: 14),
      ],
    );
  }
}
