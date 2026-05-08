import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/economy_config.dart';
import '../../providers/providers.dart';
import '../../services/reward_calculator.dart';

void showDailyRewardSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _DailyRewardSheet(),
  );
}

class _DailyRewardSheet extends ConsumerStatefulWidget {
  const _DailyRewardSheet();

  @override
  ConsumerState<_DailyRewardSheet> createState() => _DailyRewardSheetState();
}

class _DailyRewardSheetState extends ConsumerState<_DailyRewardSheet>
    with SingleTickerProviderStateMixin {
  bool _isClaiming = false;
  bool _claimed = false;
  int _earnedCoins = 0;

  late final AnimationController _claimAnim;

  @override
  void initState() {
    super.initState();
    _claimAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _claimAnim.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    if (_isClaiming || _claimed) return;
    setState(() => _isClaiming = true);

    try {
      final uid = ref.read(firebaseUserProvider).valueOrNull?.uid;
      if (uid == null) return;

      final result =
          await ref.read(economyServiceProvider).claimDailyReward(uid);
      if (!mounted) return;

      if (result != null) {
        setState(() {
          _claimed = true;
          _earnedCoins = result.coins;
          _isClaiming = false;
        });
        _claimAnim.forward();
        await Future.delayed(const Duration(milliseconds: 2200));
        if (mounted) Navigator.pop(context);
      } else {
        if (mounted) setState(() => _isClaiming = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletProvider);
    final wallet = walletAsync.valueOrNull;

    final now = DateTime.now().toUtc();
    final predictedStreak = RewardCalculator.computeNewStreak(
      wallet?.dailyStreak ?? 0,
      wallet?.lastDailyRewardAt,
      now,
    );
    final todayDay = ((predictedStreak - 1) % 7) + 1; // 1-7 cycle
    final coinsToday = RewardCalculator.calculateDailyReward(predictedStreak);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF07101F),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: const Color(0xFFD4AF37).withOpacity(0.34),
          width: 1.2,
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 8,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          const Text('🎁', style: TextStyle(fontSize: 52, height: 1)),
          const SizedBox(height: 12),
          Text(
            'פרס יומי!',
            style: const TextStyle(
              color: Color(0xFFD4AF37),
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'היכנס כל יום וצבור בונוסים',
            style: TextStyle(
              color: Colors.white.withOpacity(0.62),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          // 7-day streak row
          _StreakRow(
            todayDay: todayDay,
            completedDays: todayDay - 1,
          ),
          const SizedBox(height: 20),
          // Coins preview / success
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _claimed
                ? _ClaimSuccess(coins: _earnedCoins, anim: _claimAnim)
                : _CoinsPreview(coins: coinsToday),
          ),
          const SizedBox(height: 22),
          // Claim button
          AnimatedOpacity(
            opacity: _claimed ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE082), Color(0xFFD4AF37), Color(0xFFA1811A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withOpacity(0.38),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: FilledButton(
                  onPressed: _claimed || _isClaiming ? null : _claim,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: const Color(0xFF07101F),
                    textStyle: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  child: _isClaiming
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Color(0xFF07101F),
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('קבל פרס!'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Streak row ────────────────────────────────────────────────────────────────

class _StreakRow extends StatelessWidget {
  final int todayDay;       // 1-7 — which slot is TODAY
  final int completedDays;  // how many slots before today are done

  const _StreakRow({required this.todayDay, required this.completedDays});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final day = i + 1;
        final isDone = day < todayDay || (completedDays >= 7 && day <= 7);
        final isToday = day == todayDay;
        final isSpecial = day == 7;

        return _DaySlot(
          day: day,
          isDone: isDone,
          isToday: isToday,
          isSpecial: isSpecial,
        );
      }),
    );
  }
}

class _DaySlot extends StatelessWidget {
  final int day;
  final bool isDone;
  final bool isToday;
  final bool isSpecial;

  const _DaySlot({
    required this.day,
    required this.isDone,
    required this.isToday,
    required this.isSpecial,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    Color bgColor;
    Widget inner;

    if (isDone) {
      borderColor = const Color(0xFFD4AF37);
      bgColor = const Color(0xFFD4AF37).withOpacity(0.18);
      inner = const Icon(Icons.check_rounded, color: Color(0xFFD4AF37), size: 20);
    } else if (isToday) {
      borderColor = const Color(0xFFD4AF37);
      bgColor = const Color(0xFFD4AF37).withOpacity(0.08);
      inner = Text(
        '$day',
        style: const TextStyle(
          color: Color(0xFFD4AF37),
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      borderColor = Colors.white.withOpacity(0.14);
      bgColor = Colors.white.withOpacity(0.04);
      inner = Text(
        isSpecial ? '🎁' : '$day',
        style: TextStyle(
          color: Colors.white.withOpacity(0.35),
          fontSize: isSpecial ? 18 : 14,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor,
              width: isToday ? 2.0 : 1.2,
            ),
            boxShadow: isToday
                ? [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withOpacity(0.30),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: Center(child: inner),
        ),
        const SizedBox(height: 5),
        Text(
          'יום $day',
          style: TextStyle(
            color: isToday
                ? const Color(0xFFD4AF37)
                : Colors.white.withOpacity(0.35),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── Coins preview / success ───────────────────────────────────────────────────

class _CoinsPreview extends StatelessWidget {
  final int coins;
  const _CoinsPreview({required this.coins});

  @override
  Widget build(BuildContext context) {
    final bonus = coins - EconomyConfig.dailyRewardBase;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.09)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'היום תקבל',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    '+$coins',
                    style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('🪙',
                      style: TextStyle(fontSize: 24, height: 1)),
                ],
              ),
            ],
          ),
          if (bonus > 0) ...[
            const SizedBox(width: 18),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFD4AF37).withOpacity(0.38)),
              ),
              child: Text(
                'כולל\nבונוס +$bonus',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClaimSuccess extends StatelessWidget {
  final int coins;
  final AnimationController anim;
  const _ClaimSuccess({required this.coins, required this.anim});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.6, end: 1.0)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
      child: FadeTransition(
        opacity: anim,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37).withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: const Color(0xFFD4AF37).withOpacity(0.50)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🪙', style: TextStyle(fontSize: 28, height: 1)),
              const SizedBox(width: 10),
              Text(
                '+$coins הופקדו!',
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
