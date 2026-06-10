import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../models/card_skin.dart';
import '../../providers/providers.dart';
import '../../providers/skin_providers.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/economy/coin_display.dart';
import '../../widgets/economy/coin_icon.dart';
import '../../widgets/game/vault_cover.dart'; // CardSkinPreview

final selectedSkinProvider = StreamProvider.autoDispose<String>((ref) {
  final userAsync = ref.watch(firebaseUserProvider);
  return userAsync.maybeWhen(
    data: (user) {
      if (user == null) return Stream.value('default');
      return FirebaseFirestore.instance
          .doc('users/${user.uid}')
          .snapshots()
          .map((snap) =>
              (snap.data()?['selectedCardSkin'] as String?) ?? 'default');
    },
    orElse: () => Stream.value('default'),
  );
});

final ownedSkinsProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final userAsync = ref.watch(firebaseUserProvider);
  return userAsync.maybeWhen(
    data: (user) {
      if (user == null) return Stream.value(['default']);
      return FirebaseFirestore.instance
          .doc('users/${user.uid}')
          .snapshots()
          .map((snap) {
        final owned =
            List<String>.from(snap.data()?['ownedSkins'] ?? ['default']);
        if (!owned.contains('default')) owned.insert(0, 'default');
        return owned;
      });
    },
    orElse: () => Stream.value(['default']),
  );
});

class CardSkinsScreen extends ConsumerWidget {
  const CardSkinsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(walletProvider).valueOrNull?.coins ?? 0;
    final selectedSkin =
        ref.watch(selectedSkinProvider).valueOrNull ?? 'default';
    final ownedSkins =
        ref.watch(ownedSkinsProvider).valueOrNull ?? ['default'];
    final allSkins = ref.watch(allSkinsProvider);

    final freeSkins   = allSkins.where((s) => s.tier == SkinTier.free).toList();
    final basicSkins  = allSkins.where((s) => s.tier == SkinTier.basic).toList();
    final rareSkins   = allSkins.where((s) => s.tier == SkinTier.rare).toList();
    final premSkins   = allSkins.where((s) => s.tier == SkinTier.premium).toList();

    return AppScaffold(
      backgroundGradient: AppColors.pageBackground,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
            child: AppHeader(
              title: 'עיצובי קלפים',
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
              'בחר עיצוב לכרטיסיות המשחק',
              style: AppTextStyles.subtitleLight,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
              children: [
                _SectionHeader(
                    label: 'חינמי',
                    icon: Icons.star_outline_rounded,
                    color: const Color(0xFF8090B0)),
                const SizedBox(height: AppSpacing.sm),
                _SkinGrid(
                  skins: freeSkins,
                  coins: coins,
                  selectedSkin: selectedSkin,
                  ownedSkins: ownedSkins,
                  onBuy: (skin) => _buySkin(context, ref, skin, coins),
                  onEquip: (skin) => _equipSkin(context, ref, skin),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionHeader(
                    label: 'בסיסי  50–150',
                    trailingCoin: true,
                    icon: Icons.palette_outlined,
                    color: const Color(0xFF4CA1AF)),
                const SizedBox(height: AppSpacing.sm),
                _SkinGrid(
                  skins: basicSkins,
                  coins: coins,
                  selectedSkin: selectedSkin,
                  ownedSkins: ownedSkins,
                  onBuy: (skin) => _buySkin(context, ref, skin, coins),
                  onEquip: (skin) => _equipSkin(context, ref, skin),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionHeader(
                    label: 'נדיר  300–500',
                    trailingCoin: true,
                    icon: Icons.auto_awesome_outlined,
                    color: const Color(0xFF00FFFF)),
                const SizedBox(height: AppSpacing.sm),
                _SkinGrid(
                  skins: rareSkins,
                  coins: coins,
                  selectedSkin: selectedSkin,
                  ownedSkins: ownedSkins,
                  onBuy: (skin) => _buySkin(context, ref, skin, coins),
                  onEquip: (skin) => _equipSkin(context, ref, skin),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionHeader(
                    label: 'פרימיום  1000',
                    trailingCoin: true,
                    icon: Icons.diamond_outlined,
                    color: const Color(0xFFFFD700)),
                const SizedBox(height: AppSpacing.sm),
                _SkinGrid(
                  skins: premSkins,
                  coins: coins,
                  selectedSkin: selectedSkin,
                  ownedSkins: ownedSkins,
                  onBuy: (skin) => _buySkin(context, ref, skin, coins),
                  onEquip: (skin) => _equipSkin(context, ref, skin),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _buySkin(
    BuildContext context,
    WidgetRef ref,
    CardSkin skin,
    int currentCoins,
  ) async {
    if (currentCoins < skin.price) {
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
        final before =
            (walletSnap.data()?['coins'] as num?)?.toInt() ?? 0;
        if (before < skin.price) throw Exception('insufficient_coins');

        final userSnap = await tx.get(userRef);
        final owned = List<String>.from(
            userSnap.data()?['ownedSkins'] ?? ['default']);
        if (owned.contains(skin.id)) return;

        tx.set(walletRef, {'coins': before - skin.price},
            SetOptions(merge: true));
        tx.set(userRef, {
          'ownedSkins': FieldValue.arrayUnion([skin.id]),
        }, SetOptions(merge: true));
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${skin.name} נרכש! לחץ "הצמד" כדי להפעיל')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('שגיאה: ${e.toString()}')),
      );
    }
  }

  Future<void> _equipSkin(
    BuildContext context,
    WidgetRef ref,
    CardSkin skin,
  ) async {
    final uid = ref.read(firebaseUserProvider).valueOrNull?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance
          .doc('users/$uid')
          .set({'selectedCardSkin': skin.id}, SetOptions(merge: true));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${skin.name} הוצמד!')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('שגיאה בהצמדת העיצוב')),
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
        Expanded(
          child: Container(height: 1, color: color.withOpacity(0.22)),
        ),
      ],
    );
  }
}

// ── Skin grid ─────────────────────────────────────────────────────────────────

class _SkinGrid extends StatelessWidget {
  final List<CardSkin> skins;
  final int coins;
  final String selectedSkin;
  final List<String> ownedSkins;
  final void Function(CardSkin) onBuy;
  final void Function(CardSkin) onEquip;

  const _SkinGrid({
    required this.skins,
    required this.coins,
    required this.selectedSkin,
    required this.ownedSkins,
    required this.onBuy,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.72,
      ),
      itemCount: skins.length,
      itemBuilder: (context, index) {
        final skin = skins[index];
        final isOwned = ownedSkins.contains(skin.id);
        final isSelected = selectedSkin == skin.id;
        final canAfford = coins >= skin.price;

        return _SkinTile(
          skin: skin,
          isOwned: isOwned,
          isSelected: isSelected,
          canAfford: canAfford,
          onTap: () {
            if (isOwned || skin.isFree) {
              if (!isSelected) onEquip(skin);
            } else {
              onBuy(skin);
            }
          },
        );
      },
    );
  }
}

// ── Compact skin tile ─────────────────────────────────────────────────────────

Color _skinAccentColor(String id) {
  switch (id) {
    // legacy
    case 'classic':   return const Color(0xFFB0B0C8);
    case 'ocean':     return const Color(0xFF00BCD4);
    case 'forest':    return const Color(0xFF4CAF50);
    case 'sand':      return const Color(0xFFD4A54A);
    case 'blue':      return const Color(0xFF87CEEB);
    case 'red':       return const Color(0xFFFF6B6B);
    case 'copper':    return const Color(0xFFB87333);
    case 'dark':      return const Color(0xFF8B6FFF);
    case 'emerald':   return const Color(0xFF00C853);
    case 'ruby':      return const Color(0xFFE91E63);
    case 'rose_gold': return const Color(0xFFFFAABB);
    case 'galaxy':    return const Color(0xFF9C27B0);
    case 'obsidian':  return const Color(0xFF909090);
    // basic
    case 'mediterranean_blue': return const Color(0xFF4CA1AF);
    case 'valley_green':       return const Color(0xFF00C9FF);
    case 'negev_sands':        return const Color(0xFFFFAA80);
    case 'quiet_night':        return const Color(0xFF8090C8);
    case 'dawn_light':         return const Color(0xFFFF9A9E);
    case 'urban_concrete':     return const Color(0xFF90A0B0);
    case 'default':            return const Color(0xFF4472C8);
    case 'classic_zionist':    return const Color(0xFF4472C8);
    case 'summer_pastel':      return const Color(0xFFF0A0C0);
    case 'simple_gold_basic':  return const Color(0xFFFFD700);
    case 'terracotta_earth':   return const Color(0xFFE07A5F);
    // rare
    case 'jerusalem_neon':     return const Color(0xFFFF00FF);
    case 'steel_armor':        return const Color(0xFFC0C0C0);
    case 'space_cluster':      return const Color(0xFF00FFFF);
    case 'blue_fire':          return const Color(0xFF00FFFF);
    case 'hermon_glacier':     return const Color(0xFF81D4FA);
    case 'oriental_arabesque': return const Color(0xFFD4AF37);
    case 'ancient_gold_rare':  return const Color(0xFFFF8C00);
    case 'brushed_titanium':   return const Color(0xFF39FF14);
    case 'eilat_coral':        return const Color(0xFF00FFFF);
    case 'meteor_shower':      return const Color(0xFFE0E0FF);
    // premium
    case 'royal_throne':         return const Color(0xFFFFD700);
    case 'ancient_scroll':       return const Color(0xFFC4A47C);
    case 'jerusalem_of_gold':    return const Color(0xFFFFD700);
    case 'kotel_stones':         return const Color(0xFFFFD700);
    case 'anemone_red':          return const Color(0xFFFF6060);
    case 'salt_sunset':          return const Color(0xFFFF00FF);
    case 'royal_sapphire':       return const Color(0xFF88AAFF);
    case 'lava_core':            return const Color(0xFFFF4500);
    case 'diamond_shield':       return const Color(0xFF00E5FF);
    case 'cyber_future_israel':  return const Color(0xFF00FFFF);
    default:                     return const Color(0xFFD4AF37);
  }
}

class _SkinTile extends StatelessWidget {
  final CardSkin skin;
  final bool isOwned;
  final bool isSelected;
  final bool canAfford;
  final VoidCallback onTap;

  const _SkinTile({
    required this.skin,
    required this.isOwned,
    required this.isSelected,
    required this.canAfford,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    final accent = _skinAccentColor(skin.id);

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
              color: accent.withOpacity(isSelected ? 0.45 : isOwned ? 0.18 : 0.08),
              blurRadius: isSelected ? 14 : 8,
              spreadRadius: isSelected ? 1 : 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview square
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(13)),
                child: _SkinPreview(skin: skin),
              ),
            ),

            // Name + badge row
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                skin.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),

            // Status chip
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: _StatusChip(
                skin: skin,
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
  final CardSkin skin;
  final bool isOwned;
  final bool isSelected;
  final bool canAfford;

  const _StatusChip({
    required this.skin,
    required this.isOwned,
    required this.isSelected,
    required this.canAfford,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    final accent = _skinAccentColor(skin.id);

    if (isSelected) {
      return _Chip(label: 'מוצמד ✓', color: gold, icon: null);
    }
    if (isOwned || skin.isFree) {
      return _Chip(label: 'הצמד', color: accent, icon: Icons.touch_app_rounded);
    }
    return _Chip(
      label: '${skin.price}',
      trailingCoin: true,
      color: canAfford ? gold : Colors.grey,
      icon: null,
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool trailingCoin;

  const _Chip({required this.label, required this.color, this.icon, this.trailingCoin = false});

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

// ── Skin preview ──────────────────────────────────────────────────────────────

class _SkinPreview extends StatelessWidget {
  final CardSkin skin;
  const _SkinPreview({required this.skin});

  @override
  Widget build(BuildContext context) {
    return CardSkinPreview(cardSkinId: skin.id, skin: skin);
  }
}
