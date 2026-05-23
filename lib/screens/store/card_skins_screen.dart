import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../models/card_skin.dart';
import '../../providers/providers.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/economy/coin_display.dart';

/// Provider that reads the current user's selected card skin from Firestore.
final selectedSkinProvider = StreamProvider.autoDispose<String>((ref) {
  final userAsync = ref.watch(firebaseUserProvider);
  return userAsync.maybeWhen(
    data: (user) {
      if (user == null) return Stream.value('default');
      return FirebaseFirestore.instance
          .doc('users/${user.uid}')
          .snapshots()
          .map((snap) => (snap.data()?['selectedCardSkin'] as String?) ?? 'default');
    },
    orElse: () => Stream.value('default'),
  );
});

/// Provider that reads the current user's owned skins list from Firestore.
final ownedSkinsProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final userAsync = ref.watch(firebaseUserProvider);
  return userAsync.maybeWhen(
    data: (user) {
      if (user == null) return Stream.value(['default']);
      return FirebaseFirestore.instance
          .doc('users/${user.uid}')
          .snapshots()
          .map((snap) {
            final owned = List<String>.from(snap.data()?['ownedSkins'] ?? ['default']);
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
    final walletAsync = ref.watch(walletProvider);
    final coins = walletAsync.valueOrNull?.coins ?? 0;
    final selectedSkinAsync = ref.watch(selectedSkinProvider);
    final ownedSkinsAsync = ref.watch(ownedSkinsProvider);

    final selectedSkin = selectedSkinAsync.valueOrNull ?? 'default';
    final ownedSkins = ownedSkinsAsync.valueOrNull ?? ['default'];

    return AppScaffold(
      backgroundGradient: AppColors.pageBackground,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          AppHeader(
            title: 'עיצובי קלפים',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.maybePop(context),
            ),
            trailing: const CoinDisplay(compact: true),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'בחר עיצוב לכרטיסיות המשחק',
            style: AppTextStyles.subtitleLight,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: 0.80,
              ),
              itemCount: kAvailableCardSkins.length,
              itemBuilder: (context, index) {
                final skin = kAvailableCardSkins[index];
                final isOwned = ownedSkins.contains(skin.id);
                final isSelected = selectedSkin == skin.id;
                final canAfford = coins >= skin.price;

                return _SkinCard(
                  skin: skin,
                  isOwned: isOwned,
                  isSelected: isSelected,
                  canAfford: canAfford,
                  coins: coins,
                  onBuy: () => _buySkin(context, ref, skin, coins),
                  onEquip: () => _equipSkin(context, ref, skin),
                );
              },
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
        final walletRef = FirebaseFirestore.instance.doc('users/$uid/economy/wallet');
        final userRef = FirebaseFirestore.instance.doc('users/$uid');

        final walletSnap = await tx.get(walletRef);
        final before = (walletSnap.data()?['coins'] as num?)?.toInt() ?? 0;
        if (before < skin.price) throw Exception('insufficient_coins');

        final userSnap = await tx.get(userRef);
        final owned = List<String>.from(userSnap.data()?['ownedSkins'] ?? ['default']);
        if (owned.contains(skin.id)) return; // already owned

        tx.set(walletRef, {'coins': before - skin.price}, SetOptions(merge: true));
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
      await FirebaseFirestore.instance.doc('users/$uid').set(
        {'selectedCardSkin': skin.id},
        SetOptions(merge: true),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${skin.name} הוצמד בהצלחה!')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('שגיאה בהצמדת העיצוב')),
      );
    }
  }
}

// ── Skin card widget ─────────────────────────────────────────────────────────

class _SkinCard extends StatelessWidget {
  final CardSkin skin;
  final bool isOwned;
  final bool isSelected;
  final bool canAfford;
  final int coins;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  const _SkinCard({
    required this.skin,
    required this.isOwned,
    required this.isSelected,
    required this.canAfford,
    required this.coins,
    required this.onBuy,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1A2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? const Color(0xFFD4AF37)
              : const Color(0xFF8B6FFF).withOpacity(0.35),
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withOpacity(0.25),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Skin preview ───────────────────────────────────────
            Expanded(
              child: _SkinPreview(skin: skin),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Name ───────────────────────────────────────────────
            Text(
              skin.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),

            // ── Status badge ───────────────────────────────────────
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'מוצמד',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              const SizedBox(height: AppSpacing.sm),

            // ── Action button ──────────────────────────────────────
            if (skin.price == 0 || isOwned)
              _ActionButton(
                label: isSelected ? 'מוצמד' : 'הצמד',
                enabled: !isSelected,
                onTap: isSelected ? null : onEquip,
                color: const Color(0xFF8B6FFF),
              )
            else
              _ActionButton(
                label: '🪙 ${skin.price}',
                enabled: canAfford,
                onTap: canAfford ? onBuy : null,
                color: canAfford
                    ? const Color(0xFFD4AF37)
                    : Colors.grey,
              ),
          ],
        ),
      ),
    );
  }
}

class _SkinPreview extends StatelessWidget {
  final CardSkin skin;
  const _SkinPreview({required this.skin});

  @override
  Widget build(BuildContext context) {
    // Show asset if available, otherwise show color swatch
    if (skin.assetPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          skin.assetPath!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _ColorSwatch(skinId: skin.id),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: _ColorSwatch(skinId: skin.id),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final String skinId;
  const _ColorSwatch({required this.skinId});

  Color get _baseColor {
    switch (skinId) {
      case 'blue':
        return const Color(0xFF1E3A5F);
      case 'red':
        return const Color(0xFF5F1E1E);
      case 'dark':
        return const Color(0xFF0D0D1A);
      default:
        return const Color(0xFF07101F);
    }
  }

  Color get _accentColor {
    switch (skinId) {
      case 'blue':
        return const Color(0xFF87CEEB);
      case 'red':
        return const Color(0xFFFF6B6B);
      case 'dark':
        return const Color(0xFF4A4A8A);
      default:
        return const Color(0xFFD4AF37);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_baseColor, _accentColor.withOpacity(0.4)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _accentColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.auto_awesome_rounded,
          color: _accentColor.withOpacity(0.7),
          size: 36,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onTap;
  final Color color;

  const _ActionButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? color.withOpacity(0.15) : Colors.grey.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled ? color.withOpacity(0.60) : Colors.grey.withOpacity(0.25),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: enabled ? color : Colors.grey,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
