import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../models/win_effect.dart';
import '../../providers/providers.dart';
import '../../services/sfx_service.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/win_effect_overlay.dart';
import '../../widgets/economy/coin_display.dart';
import '../../widgets/economy/coin_icon.dart';

/// The win effect the current user has equipped (defaults to 'none').
final selectedWinEffectProvider = StreamProvider.autoDispose<String>((ref) {
  final userAsync = ref.watch(firebaseUserProvider);
  return userAsync.maybeWhen(
    data: (user) {
      if (user == null) return Stream.value('none');
      return FirebaseFirestore.instance
          .doc('users/${user.uid}')
          .snapshots()
          .map((snap) =>
              (snap.data()?['selectedWinEffect'] as String?) ?? 'none');
    },
    orElse: () => Stream.value('none'),
  );
});

/// Win effect ids the current user owns ('none' is always implicitly owned).
final ownedWinEffectsProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final userAsync = ref.watch(firebaseUserProvider);
  return userAsync.maybeWhen(
    data: (user) {
      if (user == null) return Stream.value(['none']);
      return FirebaseFirestore.instance
          .doc('users/${user.uid}')
          .snapshots()
          .map((snap) {
        final owned = List<String>.from(
            snap.data()?['ownedWinEffects'] ?? const <String>[]);
        if (!owned.contains('none')) owned.insert(0, 'none');
        return owned;
      });
    },
    orElse: () => Stream.value(['none']),
  );
});

class WinEffectsScreen extends ConsumerWidget {
  const WinEffectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(walletProvider).valueOrNull?.coins ?? 0;
    final selected = ref.watch(selectedWinEffectProvider).valueOrNull ?? 'none';
    final owned = ref.watch(ownedWinEffectsProvider).valueOrNull ?? ['none'];

    // Rebuild when the admin edits the live cosmetics catalog.
    ref.watch(cosmeticsRevisionProvider);
    final catalog = allWinEffects.where((e) => e.active).toList();

    final none = catalog.firstWhere((e) => e.id == 'none',
        orElse: () => kWinEffects.first);
    final basic =
        catalog.where((e) => e.tier == WinEffectTier.basic).toList();
    final rare = catalog.where((e) => e.tier == WinEffectTier.rare).toList();
    final prem =
        catalog.where((e) => e.tier == WinEffectTier.premium).toList();

    return AppScaffold(
      backgroundGradient: AppColors.pageBackground,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
            child: AppHeader(
              title: 'אפקטי ניצחון',
              leading: IconButton(
                icon:
                    const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.maybePop(context),
              ),
              trailing: const CoinDisplay(compact: true),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
            child: Text(
              'אפקט שיתנגן במסך הזכייה כשתנצח, כולם יראו',
              style: AppTextStyles.subtitleLight,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
              children: [
                const _SectionHeader(
                    label: 'חינמי',
                    icon: Icons.star_outline_rounded,
                    color: Color(0xFF8090B0)),
                const SizedBox(height: AppSpacing.sm),
                _EffectGrid(
                  effects: [none],
                  coins: coins,
                  selected: selected,
                  owned: owned,
                  onBuy: (e) => _buyEffect(context, ref, e, coins),
                  onEquip: (e) => _equipEffect(context, ref, e),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionHeader(
                    label: 'בסיסי  50–150',
                    trailingCoin: true,
                    icon: Icons.palette_outlined,
                    color: Color(0xFF4CA1AF)),
                const SizedBox(height: AppSpacing.sm),
                _EffectGrid(
                  effects: basic,
                  coins: coins,
                  selected: selected,
                  owned: owned,
                  onBuy: (e) => _buyEffect(context, ref, e, coins),
                  onEquip: (e) => _equipEffect(context, ref, e),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionHeader(
                    label: 'נדיר  300–500',
                    trailingCoin: true,
                    icon: Icons.auto_awesome_outlined,
                    color: Color(0xFF00FFFF)),
                const SizedBox(height: AppSpacing.sm),
                _EffectGrid(
                  effects: rare,
                  coins: coins,
                  selected: selected,
                  owned: owned,
                  onBuy: (e) => _buyEffect(context, ref, e, coins),
                  onEquip: (e) => _equipEffect(context, ref, e),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionHeader(
                    label: 'פרימיום  1000',
                    trailingCoin: true,
                    icon: Icons.diamond_outlined,
                    color: Color(0xFFFFD700)),
                const SizedBox(height: AppSpacing.sm),
                _EffectGrid(
                  effects: prem,
                  coins: coins,
                  selected: selected,
                  owned: owned,
                  onBuy: (e) => _buyEffect(context, ref, e, coins),
                  onEquip: (e) => _equipEffect(context, ref, e),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _buyEffect(
    BuildContext context,
    WidgetRef ref,
    WinEffect effect,
    int currentCoins,
  ) async {
    HapticFeedback.lightImpact();
    if (currentCoins < effect.price) {
      SfxService.instance.denied();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('אין מספיק מטבעות!')),
      );
      return;
    }

    final uid = ref.read(firebaseUserProvider).valueOrNull?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final walletRef =
            FirebaseFirestore.instance.doc('users/$uid/economy/wallet');
        final userRef = FirebaseFirestore.instance.doc('users/$uid');

        final walletSnap = await tx.get(walletRef);
        final before = (walletSnap.data()?['coins'] as num?)?.toInt() ?? 0;
        if (before < effect.price) throw Exception('insufficient_coins');

        final userSnap = await tx.get(userRef);
        final owned = List<String>.from(
            userSnap.data()?['ownedWinEffects'] ?? const <String>[]);
        if (owned.contains(effect.id)) return;

        tx.set(
            walletRef,
            {
              'coins': before - effect.price,
              'totalSpent': FieldValue.increment(effect.price),
            },
            SetOptions(merge: true));
        tx.set(
            userRef,
            {
              'ownedWinEffects': FieldValue.arrayUnion([effect.id]),
            },
            SetOptions(merge: true));
      });

      if (!context.mounted) return;
      SfxService.instance.purchase();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${effect.name} נרכש! לחץ "הצמד" כדי להפעיל')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('הרכישה נכשלה, נסה שוב')),
      );
    }
  }

  Future<void> _equipEffect(
    BuildContext context,
    WidgetRef ref,
    WinEffect effect,
  ) async {
    HapticFeedback.lightImpact();
    final uid = ref.read(firebaseUserProvider).valueOrNull?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance
          .doc('users/$uid')
          .set({'selectedWinEffect': effect.id}, SetOptions(merge: true));
      SfxService.instance.equip();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(effect.isNone ? 'האפקט הוסר' : '${effect.name} הוצמד!')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('שגיאה בהצמדת האפקט')),
      );
    }
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool trailingCoin;

  const _SectionHeader({
    required this.label,
    required this.icon,
    this.color = const Color(0xFFD4AF37),
    this.trailingCoin = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 14,
            letterSpacing: 0.3,
          ),
        ),
        if (trailingCoin) ...[
          const SizedBox(width: 3),
          const CoinIcon(size: 14),
        ],
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: color.withOpacity(0.22))),
      ],
    );
  }
}

// ── Effect grid ───────────────────────────────────────────────────────────────

class _EffectGrid extends StatelessWidget {
  final List<WinEffect> effects;
  final int coins;
  final String selected;
  final List<String> owned;
  final void Function(WinEffect) onBuy;
  final void Function(WinEffect) onEquip;

  const _EffectGrid({
    required this.effects,
    required this.coins,
    required this.selected,
    required this.owned,
    required this.onBuy,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.92,
      ),
      itemCount: effects.length,
      itemBuilder: (context, index) {
        final effect = effects[index];
        final isOwned = effect.isFree || owned.contains(effect.id);
        final isSelected = selected == effect.id;
        final canAfford = coins >= effect.price;

        return _EffectTile(
          effect: effect,
          isOwned: isOwned,
          isSelected: isSelected,
          canAfford: canAfford,
          onTap: () {
            if (isOwned) {
              if (!isSelected) onEquip(effect);
            } else {
              onBuy(effect);
            }
          },
        );
      },
    );
  }
}

// ── Effect tile (with live preview) ───────────────────────────────────────────

class _EffectTile extends StatelessWidget {
  final WinEffect effect;
  final bool isOwned;
  final bool isSelected;
  final bool canAfford;
  final VoidCallback onTap;

  const _EffectTile({
    required this.effect,
    required this.isOwned,
    required this.isSelected,
    required this.canAfford,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    final accent = effect.accent;

    final borderColor = isSelected
        ? gold
        : isOwned
            ? accent.withOpacity(0.55)
            : accent.withOpacity(0.22);

    return GestureDetector(
      onTap: isSelected ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1228),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isSelected ? 2.2 : 1.2),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(
                  isSelected ? 0.40 : isOwned ? 0.16 : 0.07),
              blurRadius: isSelected ? 14 : 8,
              spreadRadius: isSelected ? 1 : 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(13)),
                child: Container(
                  color: const Color(0xFF050A16),
                  child: effect.isNone
                      ? const Center(
                          child: Icon(Icons.block_rounded,
                              color: Colors.white24, size: 30),
                        )
                      : WinEffectOverlay(
                          effectId: effect.id, particleCount: 18),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                effect.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: _StatusChip(
                effect: effect,
                isOwned: isOwned,
                isSelected: isSelected,
                canAfford: canAfford,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final WinEffect effect;
  final bool isOwned;
  final bool isSelected;
  final bool canAfford;

  const _StatusChip({
    required this.effect,
    required this.isOwned,
    required this.isSelected,
    required this.canAfford,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    final accent = effect.accent;

    if (isSelected) {
      return const _Chip(label: 'מוצמד ✓', color: gold);
    }
    if (isOwned) {
      return _Chip(
          label: 'הצמד', color: accent, icon: Icons.touch_app_rounded);
    }
    return _Chip(
      label: '${effect.price}',
      trailingCoin: true,
      color: canAfford ? gold : Colors.grey,
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool trailingCoin;

  const _Chip({
    required this.label,
    required this.color,
    this.icon,
    this.trailingCoin = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 10),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ),
          if (trailingCoin) ...[
            const SizedBox(width: 2),
            const CoinIcon(size: 11),
          ],
        ],
      ),
    );
  }
}
