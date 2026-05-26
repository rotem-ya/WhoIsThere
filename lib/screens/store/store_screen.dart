import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/economy_config.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../providers/providers.dart';
import '../../services/hint_economy_guard.dart';
import '../../widgets/common/app_feedback.dart';
import '../../widgets/common/pressable_scale.dart';
import '../../widgets/economy/coin_display.dart';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletProvider);
    final coins = walletAsync.valueOrNull?.coins ?? 0;

    return AppScaffold(
      backgroundGradient: AppColors.pageBackground,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.maybePop(context);
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'חנות',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const CoinDisplay(compact: true),
                ],
              ),
            ),
          ),

          // ── Tabs ──────────────────────────────────────────────────────────
          TabBar(
            controller: _tab,
            indicatorColor: const Color(0xFFD4AF37),
            labelColor: const Color(0xFFD4AF37),
            unselectedLabelColor: Colors.white54,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 13),
            tabs: const [
              Tab(text: '💎 רכישה'),
              Tab(text: '💡 רמזים'),
              Tab(text: '🎴 כרטיסים'),
              Tab(text: '🎨 עיצובים'),
            ],
          ),

          // ── Tab views ─────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _PurchaseTab(coins: coins, ref: ref),
                _HintsTab(coins: coins, ref: ref),
                _CardsTab(coins: coins, ref: ref),
                const _SkinsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: רכישה ──────────────────────────────────────────────────────────────

class _PurchaseTab extends StatelessWidget {
  final int coins;
  final WidgetRef ref;
  const _PurchaseTab({required this.coins, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        children: [
          // Starter Pack
          Expanded(
            flex: 3,
            child: _StarterPackCard(coins: coins)
                .animate(delay: 80.ms)
                .fadeIn(duration: 340.ms, curve: Curves.easeOut)
                .slideY(begin: 0.06, end: 0, duration: 340.ms, curve: Curves.easeOut),
          ),
          const SizedBox(height: AppSpacing.md),
          // Rewarded Ad
          Expanded(
            flex: 2,
            child: _RewardedAdTile(ref: ref)
                .animate(delay: 180.ms)
                .fadeIn(duration: 340.ms, curve: Curves.easeOut)
                .slideY(begin: 0.06, end: 0, duration: 340.ms, curve: Curves.easeOut),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: רמזים ──────────────────────────────────────────────────────────────

class _HintsTab extends StatelessWidget {
  final int coins;
  final WidgetRef ref;
  const _HintsTab({required this.coins, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'רמזים שנרכשו יוחלו במשחק הבא',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _HintCard(
                    icon: Icons.lightbulb_outline_rounded,
                    title: 'חשוף משבצת',
                    description: 'חשוף אזור נסתר בתמונה',
                    price: EconomyConfig.hintRevealTilePrice,
                    coins: coins,
                    onBuy: () => _buyHint(
                        context, ref, HintType.revealTile, coins),
                  )
                      .animate(delay: 80.ms)
                      .fadeIn(duration: 340.ms, curve: Curves.easeOut)
                      .slideY(begin: 0.06, end: 0, duration: 340.ms),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _HintCard(
                    icon: Icons.casino_outlined,
                    title: 'ניחוש נוסף',
                    description: 'הזדמנות ניחוש נוספת',
                    price: EconomyConfig.hintExtraGuessPrice,
                    coins: coins,
                    onBuy: () => _buyHint(
                        context, ref, HintType.extraGuess, coins),
                  )
                      .animate(delay: 160.ms)
                      .fadeIn(duration: 340.ms, curve: Curves.easeOut)
                      .slideY(begin: 0.06, end: 0, duration: 340.ms),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _buyHint(
    BuildContext context,
    WidgetRef ref,
    HintType hint,
    int currentCoins,
  ) async {
    HapticFeedback.lightImpact();
    AppFeedback.selection();
    final guard = ref.read(hintEconomyGuardProvider);
    final wallet = ref.read(walletProvider).valueOrNull;
    if (wallet == null) return;

    if (!guard.canAfford(wallet, hint)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('אין מספיק מטבעות!')),
      );
      return;
    }

    final uid = ref.read(firebaseUserProvider).valueOrNull?.uid;
    if (uid == null) return;

    final granted =
        await guard.useHint(uid: uid, hint: hint, wallet: wallet);
    if (!context.mounted) return;

    if (granted) {
      AppFeedback.success();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ הרמז נקנה ויוחל במשחק הבא')),
      );
    }
  }
}

// ── Tab 3: כרטיסים ────────────────────────────────────────────────────────────

class _CardsTab extends StatelessWidget {
  final int coins;
  final WidgetRef ref;
  const _CardsTab({required this.coins, required this.ref});

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final stunCount = user?.stunCardCount ?? 0;
    final canAfford = coins >= EconomyConfig.stunCardPrice;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'כרטיסים שנרכשו נשמרים ומשמשים מחוץ למשחק',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.lg),
          _StunCardTile(
            stunCount: stunCount,
            canAfford: canAfford,
            onBuy: () => _buyStunCard(context),
          )
              .animate(delay: 80.ms)
              .fadeIn(duration: 340.ms, curve: Curves.easeOut)
              .slideY(begin: 0.06, end: 0, duration: 340.ms),
        ],
      ),
    );
  }

  Future<void> _buyStunCard(BuildContext context) async {
    HapticFeedback.lightImpact();
    AppFeedback.selection();
    final uid = ref.read(firebaseUserProvider).valueOrNull?.uid;
    if (uid == null) return;

    if (coins < EconomyConfig.stunCardPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('אין מספיק מטבעות!')),
      );
      return;
    }

    final granted = await ref.read(economyServiceProvider).buyStunCard(uid);
    if (!context.mounted) return;

    if (granted) {
      AppFeedback.success();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ כרטיס עצור נרכש!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('הרכישה נכשלה, נסה שוב')),
      );
    }
  }
}

class _StunCardTile extends StatelessWidget {
  final int stunCount;
  final bool canAfford;
  final VoidCallback onBuy;
  const _StunCardTile({
    required this.stunCount,
    required this.canAfford,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1A30), Color(0xFF1A0A20)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF8B4FBF).withOpacity(0.55),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B4FBF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(child: Text('🔒', style: TextStyle(fontSize: 28))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'כרטיס עצור',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'חסום שחקן אחר מניחוש לתור אחד',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B4FBF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF8B4FBF).withOpacity(0.35)),
                ),
                child: Text(
                  'ברשותך: $stunCount',
                  style: const TextStyle(
                    color: Color(0xFFCF9FFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              PressableScale(
                onTap: canAfford ? onBuy : null,
                scale: 0.93,
                child: AnimatedOpacity(
                  opacity: canAfford ? 1.0 : 0.45,
                  duration: const Duration(milliseconds: 160),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: canAfford
                          ? const LinearGradient(
                              colors: [Color(0xFF8B4FBF), Color(0xFF5A1A8A)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            )
                          : null,
                      color: canAfford ? null : Colors.white12,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${EconomyConfig.stunCardPrice} 🪙',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tab 4: עיצובים ────────────────────────────────────────────────────────────

class _SkinsTab extends StatelessWidget {
  const _SkinsTab();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          // Card skins banner
          PressableScale(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/store/skins');
            },
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0A1A2E), Color(0xFF1A0A2E)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF8B6FFF).withOpacity(0.55),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B6FFF).withOpacity(0.12),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B6FFF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF8B6FFF).withOpacity(0.40),
                      ),
                    ),
                    child: const Icon(Icons.style_rounded,
                        color: Color(0xFF8B6FFF), size: 32),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('עיצובי קלפים',
                            style: AppTextStyles.titleLight
                                .copyWith(fontSize: 18)),
                        const SizedBox(height: 4),
                        const Text(
                          'בחר עיצוב לכרטיסיות המשחק',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left_rounded,
                      color: Colors.white38, size: 26),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Starter Pack ──────────────────────────────────────────────────────────────

class _StarterPackCard extends StatelessWidget {
  final int coins;
  const _StarterPackCard({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1060), Color(0xFF0D0730)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: const Color(0xFFD4AF37).withOpacity(0.55), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.14),
            blurRadius: 22,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '🔥 הצעה מיוחדת',
              style: TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Text(
            'Starter Pack',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          Column(
            children: [
              _PackFeature(text: '500 🪙 מטבעות'),
              _PackFeature(text: 'כל תמונות הפרמיום לחודש'),
              _PackFeature(text: 'הסרת פרסומות'),
            ],
          ),
          PressableScale(
            onTap: () => HapticFeedback.lightImpact(),
            child: SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFE082),
                      Color(0xFFD4AF37),
                      Color(0xFFA1811A)
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: FilledButton(
                  onPressed: () => HapticFeedback.lightImpact(),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: const Color(0xFF07101F),
                    textStyle: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('רכישה — 9.99₪'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackFeature extends StatelessWidget {
  final String text;
  const _PackFeature({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFFD4AF37), size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Rewarded Ad ───────────────────────────────────────────────────────────────

class _RewardedAdTile extends ConsumerWidget {
  final WidgetRef ref;
  const _RewardedAdTile({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider).valueOrNull;
    final adsToday = wallet?.adRewardsTodayCount ?? 0;
    final remaining = (EconomyConfig.maxAdRewardsPerDay - adsToday)
        .clamp(0, EconomyConfig.maxAdRewardsPerDay);
    final canWatch = remaining > 0;

    return GestureDetector(
      onTap: canWatch
          ? () {
              HapticFeedback.lightImpact();
              _watchAd(context, ref);
            }
          : null,
      child: AnimatedOpacity(
        opacity: canWatch ? 1.0 : 0.48,
        duration: const Duration(milliseconds: 180),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF07101F).withOpacity(0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: const Color(0xFF87CEEB).withOpacity(0.30)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF87CEEB).withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF87CEEB).withOpacity(0.30)),
                ),
                child: const Icon(Icons.play_circle_outline_rounded,
                    color: Color(0xFF87CEEB), size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'צפה וקבל ${EconomyConfig.adRewardCoins} 🪙',
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      canWatch
                          ? 'נותרו $remaining/${EconomyConfig.maxAdRewardsPerDay} צפיות היום'
                          : 'המכסה היומית הושלמה',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.52),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white38, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _watchAd(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(firebaseUserProvider).valueOrNull?.uid;
    if (uid == null) return;

    final granted =
        await ref.read(economyServiceProvider).applyAdReward(uid);
    if (!context.mounted) return;

    if (granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('+${EconomyConfig.adRewardCoins} מטבעות הופקדו! 🪙'),
          backgroundColor: const Color(0xFF0A3880),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('המכסה היומית הושלמה')),
      );
    }
  }
}

// ── Hint card ─────────────────────────────────────────────────────────────────

class _HintCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final int price;
  final int coins;
  final VoidCallback onBuy;

  const _HintCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.price,
    required this.coins,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final canAfford = coins >= price;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF07101F).withOpacity(0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFD4AF37).withOpacity(0.25),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primary, size: 36),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body
                .copyWith(fontWeight: FontWeight.w900),
          ),
          Text(
            description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.subtitleLight
                .copyWith(fontSize: 12),
          ),
          PressableScale(
            onTap: canAfford ? onBuy : null,
            child: AnimatedOpacity(
              opacity: canAfford ? 1.0 : 0.45,
              duration: const Duration(milliseconds: 180),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: canAfford
                      ? const LinearGradient(
                          colors: [Color(0xFFFFE082), Color(0xFFD4AF37)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : null,
                  color: canAfford ? null : Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '🪙 $price',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: canAfford
                        ? const Color(0xFF07101F)
                        : Colors.white38,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
