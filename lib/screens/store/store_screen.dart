import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/ad_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/economy_config.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../providers/providers.dart';
import '../../widgets/common/app_feedback.dart';
import '../../widgets/common/pressable_scale.dart';
import '../../widgets/economy/coin_display.dart';
import '../../widgets/economy/coin_icon.dart';

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
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // Resilient back: pop if there's something to pop (store was pushed),
  // otherwise fall back to /home. The store can be reached via context.go
  // (e.g. the "insufficient coins" dialog), which replaces the stack and leaves
  // nothing to pop — Navigator.maybePop would then silently do nothing, trapping
  // the user on the store screen.
  void _handleBack() {
    HapticFeedback.lightImpact();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletProvider);
    final coins = walletAsync.valueOrNull?.coins ?? 0;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _handleBack();
      },
      child: AppScaffold(
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
                    onPressed: _handleBack,
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
              Tab(text: '🃏 כרטיסים'),
              Tab(text: '🎨 עיצובים'),
            ],
          ),

          // ── Tab views ─────────────────────────────────────────────────────
          Expanded(
            child: SafeArea(
              top: false,
              child: TabBarView(
                controller: _tab,
                children: [
                  _PurchaseTab(coins: coins, ref: ref),
                  _CardsTab(coins: coins, ref: ref),
                  const _SkinsTab(),
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

// ── Tab 1: רכישה ──────────────────────────────────────────────────────────────

class _PurchaseTab extends StatelessWidget {
  final int coins;
  final WidgetRef ref;
  const _PurchaseTab({required this.coins, required this.ref});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
      children: [
        // ── Coin packages ─────────────────────────────────────────────────
        _SectionLabel(label: 'קנה מטבעות', iconWidget: const CoinIcon(size: 16)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _CoinPackageTile(
                coins: 40,
                priceIls: '₪0.99',
                color: const Color(0xFF4A9EFF),
              ).animate(delay: 60.ms).fadeIn(duration: 280.ms).slideY(begin: 0.07, end: 0, duration: 280.ms),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CoinPackageTile(
                coins: 90,
                priceIls: '₪1.99',
                color: const Color(0xFF3DCCAA),
                badge: 'פופולרי',
              ).animate(delay: 100.ms).fadeIn(duration: 280.ms).slideY(begin: 0.07, end: 0, duration: 280.ms),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CoinPackageTile(
                coins: 200,
                priceIls: '₪3.99',
                color: const Color(0xFFD4AF37),
                badge: 'מומלץ',
              ).animate(delay: 140.ms).fadeIn(duration: 280.ms).slideY(begin: 0.07, end: 0, duration: 280.ms),
            ),
          ],
        ),
        // Ad-related store items (ad-removal pack + rewarded-ad tile) are shown
        // only when ads are enabled. With ads off at launch, advertising
        // shouldn't be referenced anywhere in the UI (and would fail review).
        if (AdConstants.adsEnabled) ...[
          const SizedBox(height: AppSpacing.lg),

          // ── Ad removal pack ─────────────────────────────────────────────
          _SectionLabel(label: 'חבילות', icon: '🎁'),
          const SizedBox(height: 10),
          _AdRemovalCard()
              .animate(delay: 180.ms)
              .fadeIn(duration: 340.ms, curve: Curves.easeOut)
              .slideY(begin: 0.06, end: 0, duration: 340.ms, curve: Curves.easeOut),
          const SizedBox(height: AppSpacing.md),

          // ── Rewarded Ad ─────────────────────────────────────────────────
          _RewardedAdTile(ref: ref)
              .animate(delay: 260.ms)
              .fadeIn(duration: 300.ms, curve: Curves.easeOut)
              .slideY(begin: 0.06, end: 0, duration: 300.ms, curve: Curves.easeOut),
        ],
      ],
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final String? icon;
  final Widget? iconWidget;
  const _SectionLabel({required this.label, this.icon, this.iconWidget});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        iconWidget ?? Text(icon ?? '', style: const TextStyle(fontSize: 15, height: 1)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: Colors.white12)),
      ],
    );
  }
}

// ── Coin package tile ─────────────────────────────────────────────────────────

class _CoinPackageTile extends StatelessWidget {
  final int coins;
  final String priceIls;
  final Color color;
  final String? badge;

  const _CoinPackageTile({
    required this.coins,
    required this.priceIls,
    required this.color,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => HapticFeedback.lightImpact(),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withOpacity(0.22), const Color(0xFF04091A)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.60), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.20),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withOpacity(0.5), width: 0.8),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            const CoinIcon(size: 26),
            const SizedBox(height: 6),
            Text(
              '$coins',
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'מטבעות',
              style: TextStyle(
                color: Colors.white.withOpacity(0.50),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                priceIls,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF07101F),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab 2: כרטיסים ────────────────────────────────────────────────────────────

class _CardsTab extends StatelessWidget {
  final int coins;
  final WidgetRef ref;
  const _CardsTab({required this.coins, required this.ref});

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final stunCount = user?.stunCardCount ?? 0;
    final block5Count = user?.guessBlock5Count ?? 0;
    final block10Count = user?.guessBlock10Count ?? 0;
    final blackoutCount = user?.blackoutCardCount ?? 0;
    final discovered = user?.discoveredImageIds.length ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'לחץ על שחקן במשחק כדי להפעיל כרטיס',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.62,
              children: [
                _PlayingCard(
                  title: 'חסימה 5 שניות',
                  description: 'מונע ניחוש מיריב למשך 5 שניות',
                  emoji: '⏱️',
                  iconData: Icons.timer_outlined,
                  illustrationGradient: const [Color(0xFF1890D0), Color(0xFF0060A0)],
                  accentColor: const Color(0xFF1890D0),
                  owned: block5Count,
                  price: EconomyConfig.guessBlock5Price,
                  canAfford: coins >= EconomyConfig.guessBlock5Price,
                  locked: discovered < 10,
                  requiredDiscoveries: 10,
                  onBuy: () => _buyCard(context, 'block5'),
                ).animate(delay: 60.ms).fadeIn(duration: 300.ms).slideY(begin: 0.07, end: 0, duration: 300.ms),
                _PlayingCard(
                  title: 'החשכה',
                  description: 'מחשיך את הלוח של יריב ל-5 שניות',
                  emoji: '🕶️',
                  iconData: Icons.visibility_off_outlined,
                  illustrationGradient: const [Color(0xFF3A3A4A), Color(0xFF1A1A2E)],
                  accentColor: const Color(0xFF5A1A8A),
                  owned: blackoutCount,
                  price: EconomyConfig.blackoutCardPrice,
                  canAfford: coins >= EconomyConfig.blackoutCardPrice,
                  locked: discovered < 20,
                  requiredDiscoveries: 20,
                  onBuy: () => _buyCard(context, 'blackout'),
                ).animate(delay: 120.ms).fadeIn(duration: 300.ms).slideY(begin: 0.07, end: 0, duration: 300.ms),
                _PlayingCard(
                  title: 'חסימה 10 שניות',
                  description: 'מונע ניחוש מיריב למשך 10 שניות',
                  emoji: '⏰',
                  iconData: Icons.timer,
                  illustrationGradient: const [Color(0xFF1060A0), Color(0xFF003080)],
                  accentColor: const Color(0xFF0060A0),
                  owned: block10Count,
                  price: EconomyConfig.guessBlock10Price,
                  canAfford: coins >= EconomyConfig.guessBlock10Price,
                  locked: discovered < 30,
                  requiredDiscoveries: 30,
                  onBuy: () => _buyCard(context, 'block10'),
                ).animate(delay: 180.ms).fadeIn(duration: 300.ms).slideY(begin: 0.07, end: 0, duration: 300.ms),
                _PlayingCard(
                  title: 'כרטיס עצור',
                  description: 'חוסם שחקן אחד מניחוש לתור שלם',
                  emoji: '🔒',
                  iconData: Icons.lock_outline,
                  illustrationGradient: const [Color(0xFF8B4FBF), Color(0xFF5A1A8A)],
                  accentColor: const Color(0xFF8B4FBF),
                  owned: stunCount,
                  price: EconomyConfig.stunCardPrice,
                  canAfford: coins >= EconomyConfig.stunCardPrice,
                  locked: discovered < 40,
                  requiredDiscoveries: 40,
                  onBuy: () => _buyCard(context, 'stun'),
                ).animate(delay: 240.ms).fadeIn(duration: 300.ms).slideY(begin: 0.07, end: 0, duration: 300.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _buyCard(BuildContext context, String type) async {
    HapticFeedback.lightImpact();
    AppFeedback.selection();
    final uid = ref.read(firebaseUserProvider).valueOrNull?.uid;
    if (uid == null) return;

    final economy = ref.read(economyServiceProvider);
    final Future<bool> Function() buyFn;
    final String label;
    final int price;

    if (type == 'stun') {
      price = EconomyConfig.stunCardPrice;
      buyFn = () => economy.buyStunCard(uid);
      label = 'כרטיס עצור';
    } else if (type == 'block5') {
      price = EconomyConfig.guessBlock5Price;
      buyFn = () => economy.buyGuessBlock5Card(uid);
      label = 'חסימת ניחוש 5s';
    } else if (type == 'block10') {
      price = EconomyConfig.guessBlock10Price;
      buyFn = () => economy.buyGuessBlock10Card(uid);
      label = 'חסימת ניחוש 10s';
    } else if (type == 'blackout') {
      price = EconomyConfig.blackoutCardPrice;
      buyFn = () => economy.buyBlackoutCard(uid);
      label = 'כרטיס החשכה';
    } else {
      return;
    }

    if (coins < price) {
      if (context.mounted) _showNoCoins(context);
      return;
    }

    final granted = await buyFn();
    if (!context.mounted) return;

    if (granted) {
      AppFeedback.success();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ $label נרכש!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('הרכישה נכשלה, נסה שוב')),
      );
    }
  }

  void _showNoCoins(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('אין מספיק מטבעות!')),
    );
  }
}

// ── Playing card widget ───────────────────────────────────────────────────────

class _PlayingCard extends StatelessWidget {
  final String title;
  final String description;
  final String emoji;
  final IconData iconData;
  final List<Color> illustrationGradient;
  final Color accentColor;
  final int owned;
  final int price;
  final bool canAfford;
  final bool locked;
  final int requiredDiscoveries;
  final VoidCallback onBuy;

  const _PlayingCard({
    required this.title,
    required this.description,
    required this.emoji,
    required this.iconData,
    required this.illustrationGradient,
    required this.accentColor,
    required this.owned,
    required this.price,
    required this.canAfford,
    required this.onBuy,
    this.locked = false,
    this.requiredDiscoveries = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (locked) {
      return _LockedCard(
        title: title,
        emoji: emoji,
        requiredDiscoveries: requiredDiscoveries,
      );
    }

    return PressableScale(
      onTap: canAfford ? onBuy : null,
      scale: 0.95,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: canAfford ? 1.0 : 0.55,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                accentColor.withOpacity(0.30),
                const Color(0xFF04091A),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accentColor.withOpacity(0.70), width: 1.8),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.22),
                blurRadius: 14,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Coloured top bar ─────────────────────────────────────────
              Container(
                height: 7,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Title
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      // Card illustration
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: illustrationGradient,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: illustrationGradient.first.withOpacity(0.45),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(iconData, color: Colors.white.withOpacity(0.25), size: 38),
                            Text(emoji, style: const TextStyle(fontSize: 22, height: 1)),
                          ],
                        ),
                      ),
                      // Description
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.60),
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                      // Owned badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: accentColor.withOpacity(0.45), width: 1),
                        ),
                        child: Text(
                          'ברשותך: $owned',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Buy button ───────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: canAfford ? accentColor : Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text.rich(
                  TextSpan(
                    text: '$price ',
                    children: [coinSpan(size: 14, color: canAfford ? const Color(0xFFFFC107) : Colors.white38)],
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: canAfford ? Colors.white : Colors.white38,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
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

class _LockedCard extends StatelessWidget {
  final String title;
  final String emoji;
  final int requiredDiscoveries;

  const _LockedCard({
    required this.title,
    required this.emoji,
    required this.requiredDiscoveries,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A2A), Color(0xFF0A0A14)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 7,
            decoration: const BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        emoji,
                        style: const TextStyle(
                            fontSize: 44, height: 1, color: Color(0x33FFFFFF)),
                      ),
                      const Icon(Icons.lock_rounded,
                          color: Colors.white54, size: 30),
                    ],
                  ),
                  Text(
                    'גלה $requiredDiscoveries מקומות\nלפתיחה',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_rounded, color: Colors.white24, size: 14),
                SizedBox(width: 4),
                Text(
                  'נעול',
                  style: TextStyle(
                      color: Colors.white24,
                      fontSize: 13,
                      fontWeight: FontWeight.w900),
                ),
              ],
            ),
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
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.md),
        const _DesignBanner(
          title: 'עיצובי קלפים',
          subtitle: 'בחר עיצוב לכרטיסיות המשחק',
          icon: Icons.style_rounded,
          accent: Color(0xFF8B6FFF),
          route: '/store/skins',
        ),
        const SizedBox(height: AppSpacing.md),
        const _DesignBanner(
          title: 'מסגרות אווטר',
          subtitle: 'מסגרת שתופיע סביב האווטר שלך',
          icon: Icons.account_circle_rounded,
          accent: Color(0xFFD4AF37),
          route: '/store/frames',
        ),
        const SizedBox(height: AppSpacing.md),
        const _DesignBanner(
          title: 'צבעי שם',
          subtitle: 'צבע או גרדיאנט לשם שלך',
          icon: Icons.text_fields_rounded,
          accent: Color(0xFF4DD0A0),
          route: '/store/names',
        ),
        const SizedBox(height: AppSpacing.md),
        const _DesignBanner(
          title: 'אפקטי ניצחון',
          subtitle: 'חגיגה במסך הזכייה כשתנצח',
          icon: Icons.celebration_rounded,
          accent: Color(0xFFFF8A65),
          route: '/store/effects',
        ),
      ],
    );
  }
}

class _DesignBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String route;

  const _DesignBanner({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push(route);
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
          border: Border.all(color: accent.withOpacity(0.55), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.12),
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
                color: accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withOpacity(0.40)),
              ),
              child: Icon(icon, color: accent, size: 32),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.titleLight.copyWith(fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded,
                color: Colors.white38, size: 26),
          ],
        ),
      ),
    );
  }
}

// ── Ad Removal Pack ───────────────────────────────────────────────────────────

class _AdRemovalCard extends StatelessWidget {
  const _AdRemovalCard();

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.35)),
                ),
                child: const Center(
                  child: Text('🚫', style: TextStyle(fontSize: 22, height: 1)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'הסרת פרסומות',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _PackFeature(text: '500 מטבעות'),
          const SizedBox(height: 2),
          _PackFeature(text: 'ללא פרסומות לצמיתות'),
          const SizedBox(height: 14),
          // Full-width buy button
          PressableScale(
            onTap: () => HapticFeedback.lightImpact(),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFE082), Color(0xFFD4AF37), Color(0xFFA1811A)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: FilledButton(
                onPressed: () => HapticFeedback.lightImpact(),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: const Color(0xFF07101F),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size.fromHeight(46),
                ),
                child: const Text('רכישה • ₪9.99'),
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
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFFD4AF37), size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.78),
              fontSize: 13,
              fontWeight: FontWeight.w600,
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
                    Text.rich(
                      TextSpan(
                        text: 'צפה וקבל ${EconomyConfig.adRewardCoins} ',
                        children: [coinSpan(size: 16)],
                      ),
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

    // Show the real rewarded ad first; only credit coins if the user watched
    // long enough to earn the reward.
    final watched = await ref.read(adServiceProvider).showRewarded();
    if (!context.mounted) return;
    if (!watched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('הפרסומת לא זמינה כרגע, נסה שוב בעוד רגע')),
      );
      return;
    }

    final granted =
        await ref.read(economyServiceProvider).applyAdReward(uid);
    if (!context.mounted) return;

    if (granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('+${EconomyConfig.adRewardCoins} מטבעות הופקדו!'),
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
