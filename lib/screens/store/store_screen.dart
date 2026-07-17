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
import '../../services/analytics_service.dart';
import '../../services/sfx_service.dart';
import '../../widgets/common/app_feedback.dart';
import '../../widgets/common/board_skin_background.dart';
import '../../widgets/common/player_avatar.dart';
import '../../widgets/common/player_name_text.dart';
import '../../widgets/common/pressable_scale.dart';
import '../../widgets/economy/coin_display.dart';
import '../../widgets/economy/coin_icon.dart';
import 'avatars_screen.dart' show selectedAvatarProvider;
import 'board_skins_screen.dart' show selectedBoardSkinProvider;

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
    _tab.addListener(() {
      if (_tab.indexIsChanging) SfxService.instance.tabChange();
    });
    AnalyticsService.instance.storeView();
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
              Tab(text: '🎁 מטבעות'),
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
        // Coins are earned in-game (daily reward, wins, discoveries) — never
        // sold for real money. How to earn:
        _SectionLabel(label: 'איך מרוויחים מטבעות', iconWidget: const CoinIcon(size: 16)),
        const SizedBox(height: 10),
        const _EarnCoinsInfo()
            .animate(delay: 60.ms)
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.06, end: 0, duration: 300.ms),

        // Rewarded ad (free coins for watching) — the only "get more" option,
        // shown when ads are enabled. No real-money purchase anywhere.
        if (AdConstants.adsEnabled) ...[
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel(label: 'צפה והרווח', icon: '🎬'),
          const SizedBox(height: 10),
          _RewardedAdTile(ref: ref)
              .animate(delay: 160.ms)
              .fadeIn(duration: 300.ms, curve: Curves.easeOut)
              .slideY(begin: 0.06, end: 0, duration: 300.ms, curve: Curves.easeOut),
        ],
      ],
    );
  }
}

// Short "how to earn coins" card — replaces the removed real-money packages.
class _EarnCoinsInfo extends StatelessWidget {
  const _EarnCoinsInfo();

  @override
  Widget build(BuildContext context) {
    Widget row(String emoji, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text,
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          row('🎁', 'פרס יומי, התחבר כל יום'),
          row('🏆', 'ניצחונות ונקודות במשחקים'),
          row('🗺️', 'גילוי מקומות חדשים'),
        ],
      ),
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
    final peekCount = user?.peekCardCount ?? 0;
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
              'כרטיסי התקפה: לחץ על שחקן במשחק · כרטיסי עזר: בתפריט הכלים',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 9,
              mainAxisSpacing: 9,
              childAspectRatio: 0.74,
              children: [
                _PlayingCard(
                  title: 'חסימה 5 שניות',
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
                _PlayingCard(
                  title: 'הצצה',
                  emoji: '👁️',
                  iconData: Icons.visibility_outlined,
                  illustrationGradient: const [Color(0xFF26A69A), Color(0xFF00695C)],
                  accentColor: const Color(0xFF26A69A),
                  owned: peekCount,
                  price: EconomyConfig.peekCardPrice,
                  canAfford: coins >= EconomyConfig.peekCardPrice,
                  locked: discovered < EconomyConfig.peekCardUnlockDiscoveries,
                  requiredDiscoveries: EconomyConfig.peekCardUnlockDiscoveries,
                  onBuy: () => _buyCard(context, 'peek'),
                ).animate(delay: 300.ms).fadeIn(duration: 300.ms).slideY(begin: 0.07, end: 0, duration: 300.ms),
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
    } else if (type == 'peek') {
      price = EconomyConfig.peekCardPrice;
      buyFn = () => economy.buyPeekCard(uid);
      label = 'כרטיס הצצה';
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
      SfxService.instance.purchase();
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
    SfxService.instance.denied();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('אין מספיק מטבעות!')),
    );
  }
}

// ── Playing card widget ───────────────────────────────────────────────────────

class _PlayingCard extends StatelessWidget {
  final String title;
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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withOpacity(0.45), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.12),
                blurRadius: 9,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Coloured top bar ─────────────────────────────────────────
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(15)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Card illustration
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: illustrationGradient,
                          ),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(iconData,
                                color: Colors.white.withOpacity(0.22), size: 24),
                            Text(emoji,
                                style: const TextStyle(fontSize: 17, height: 1)),
                          ],
                        ),
                      ),
                      // Title
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      // Owned count (compact)
                      Text(
                        'ברשותך $owned',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Buy button ───────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: canAfford ? accentColor : Colors.white12,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text.rich(
                  TextSpan(
                    text: '$price ',
                    children: [coinSpan(size: 12, color: canAfford ? const Color(0xFFFFC107) : Colors.white38)],
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: canAfford ? Colors.white : Colors.white38,
                    fontSize: 12.5,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 4,
            decoration: const BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        emoji,
                        style: const TextStyle(
                            fontSize: 32, height: 1, color: Color(0x33FFFFFF)),
                      ),
                      const Icon(Icons.lock_rounded,
                          color: Colors.white54, size: 22),
                    ],
                  ),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  Text(
                    'גלה $requiredDiscoveries מקומות',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(6, 0, 6, 6),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_rounded, color: Colors.white24, size: 12),
                SizedBox(width: 3),
                Text(
                  'נעול',
                  style: TextStyle(
                      color: Colors.white24,
                      fontSize: 11,
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

class _SkinsTab extends ConsumerWidget {
  const _SkinsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(currentUserProvider).valueOrNull?.name ?? 'שחקן';
    final avatarId = ref.watch(selectedAvatarProvider).valueOrNull ?? 'auto';
    final boardSkinId =
        ref.watch(selectedBoardSkinProvider).valueOrNull ?? 'none';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
      children: [
        // ── Live "my look" preview ────────────────────────────────────────
        _MyLookPreview(
          name: name,
          avatarId: avatarId,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            const Icon(Icons.brush_rounded, color: Colors.white54, size: 16),
            const SizedBox(width: 6),
            Text('כלי העיצוב',
                style: AppTextStyles.titleLight.copyWith(fontSize: 15)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // ── Category cards grid ───────────────────────────────────────────
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.18,
          children: [
            _DesignCard(
              title: 'אווטרים',
              accent: const Color(0xFF4FC3F7),
              route: '/store/avatars',
              preview: PlayerAvatar(
                  name: name, seed: name, radius: 22, avatarId: avatarId),
            ),
            _DesignCard(
              title: 'עיצובי קלפים',
              accent: const Color(0xFF8B6FFF),
              route: '/store/skins',
              preview: const Icon(Icons.style_rounded,
                  color: Color(0xFF8B6FFF), size: 34),
            ),
            _DesignCard(
              title: 'רקע לוח',
              accent: const Color(0xFF4CA1AF),
              route: '/store/board',
              preview: _BoardSwatch(skinId: boardSkinId),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Live combined-look preview ──────────────────────────────────────────────────

class _MyLookPreview extends StatelessWidget {
  final String name;
  final String avatarId;

  const _MyLookPreview({
    required this.name,
    required this.avatarId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E2A4A), Color(0xFF1A0A2E)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: const Color(0xFF4FC3F7).withOpacity(0.40), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1890D0).withOpacity(0.18),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          PlayerAvatar(
            name: name,
            seed: name,
            radius: 32,
            avatarId: avatarId,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('המראה שלי',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                PlayerNameText(
                  text: name,
                  base: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                const Text('כך שאר השחקנים רואים אותך',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Board skin colour swatch ────────────────────────────────────────────────────

class _BoardSwatch extends StatelessWidget {
  final String skinId;
  const _BoardSwatch({required this.skinId});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 40,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24, width: 0.8),
          ),
          child: BoardSkinBackground(skinId: skinId),
        ),
      ),
    );
  }
}

// ── Design category card (grid tile) ────────────────────────────────────────────

class _DesignCard extends StatelessWidget {
  final String title;
  final Color accent;
  final String route;
  final Widget preview;

  const _DesignCard({
    required this.title,
    required this.accent,
    required this.route,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () {
        AppFeedback.tap();
        context.push(route);
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1A2E), Color(0xFF120A24)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withOpacity(0.45), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.10),
              blurRadius: 14,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Center(child: preview),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_left_rounded,
                    color: accent.withOpacity(0.8), size: 18),
              ],
            ),
          ],
        ),
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
    final watched = await ref.read(adServiceProvider).showRewarded(placement: 'store_coins');
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
