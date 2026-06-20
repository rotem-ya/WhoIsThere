import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../models/name_style.dart';
import '../../providers/providers.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/player_name_text.dart';
import '../../widgets/economy/coin_display.dart';
import '../../widgets/economy/coin_icon.dart';

/// The name style the current user has equipped (defaults to 'none').
final selectedNameStyleProvider = StreamProvider.autoDispose<String>((ref) {
  final userAsync = ref.watch(firebaseUserProvider);
  return userAsync.maybeWhen(
    data: (user) {
      if (user == null) return Stream.value('none');
      return FirebaseFirestore.instance
          .doc('users/${user.uid}')
          .snapshots()
          .map((snap) =>
              (snap.data()?['selectedNameStyle'] as String?) ?? 'none');
    },
    orElse: () => Stream.value('none'),
  );
});

/// Name style ids the current user owns ('none' is always implicitly owned).
final ownedNameStylesProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final userAsync = ref.watch(firebaseUserProvider);
  return userAsync.maybeWhen(
    data: (user) {
      if (user == null) return Stream.value(['none']);
      return FirebaseFirestore.instance
          .doc('users/${user.uid}')
          .snapshots()
          .map((snap) {
        final owned = List<String>.from(
            snap.data()?['ownedNameStyles'] ?? const <String>[]);
        if (!owned.contains('none')) owned.insert(0, 'none');
        return owned;
      });
    },
    orElse: () => Stream.value(['none']),
  );
});

class NameStylesScreen extends ConsumerWidget {
  const NameStylesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(walletProvider).valueOrNull?.coins ?? 0;
    final selected = ref.watch(selectedNameStyleProvider).valueOrNull ?? 'none';
    final owned = ref.watch(ownedNameStylesProvider).valueOrNull ?? ['none'];
    final userName = ref.watch(currentUserProvider).valueOrNull?.name ?? 'את/ה';

    final none = kNameStyles.firstWhere((s) => s.id == 'none');
    final basic =
        kNameStyles.where((s) => s.tier == NameStyleTier.basic).toList();
    final rare =
        kNameStyles.where((s) => s.tier == NameStyleTier.rare).toList();
    final prem =
        kNameStyles.where((s) => s.tier == NameStyleTier.premium).toList();

    return AppScaffold(
      backgroundGradient: AppColors.pageBackground,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
            child: AppHeader(
              title: 'צבעי שם',
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
              'בחר צבע לשם שלך — שאר השחקנים יראו אותו בלובי',
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
                _NameGrid(
                  styles: [none],
                  coins: coins,
                  userName: userName,
                  selected: selected,
                  owned: owned,
                  onBuy: (s) => _buyStyle(context, ref, s, coins),
                  onEquip: (s) => _equipStyle(context, ref, s),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionHeader(
                    label: 'בסיסי  50–150',
                    trailingCoin: true,
                    icon: Icons.palette_outlined,
                    color: Color(0xFF4CA1AF)),
                const SizedBox(height: AppSpacing.sm),
                _NameGrid(
                  styles: basic,
                  coins: coins,
                  userName: userName,
                  selected: selected,
                  owned: owned,
                  onBuy: (s) => _buyStyle(context, ref, s, coins),
                  onEquip: (s) => _equipStyle(context, ref, s),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionHeader(
                    label: 'נדיר  300–500',
                    trailingCoin: true,
                    icon: Icons.auto_awesome_outlined,
                    color: Color(0xFF00FFFF)),
                const SizedBox(height: AppSpacing.sm),
                _NameGrid(
                  styles: rare,
                  coins: coins,
                  userName: userName,
                  selected: selected,
                  owned: owned,
                  onBuy: (s) => _buyStyle(context, ref, s, coins),
                  onEquip: (s) => _equipStyle(context, ref, s),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionHeader(
                    label: 'פרימיום  1000',
                    trailingCoin: true,
                    icon: Icons.diamond_outlined,
                    color: Color(0xFFFFD700)),
                const SizedBox(height: AppSpacing.sm),
                _NameGrid(
                  styles: prem,
                  coins: coins,
                  userName: userName,
                  selected: selected,
                  owned: owned,
                  onBuy: (s) => _buyStyle(context, ref, s, coins),
                  onEquip: (s) => _equipStyle(context, ref, s),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _buyStyle(
    BuildContext context,
    WidgetRef ref,
    NameStyle style,
    int currentCoins,
  ) async {
    HapticFeedback.lightImpact();
    if (currentCoins < style.price) {
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
        if (before < style.price) throw Exception('insufficient_coins');

        final userSnap = await tx.get(userRef);
        final owned = List<String>.from(
            userSnap.data()?['ownedNameStyles'] ?? const <String>[]);
        if (owned.contains(style.id)) return;

        tx.set(
            walletRef,
            {
              'coins': before - style.price,
              'totalSpent': FieldValue.increment(style.price),
            },
            SetOptions(merge: true));
        tx.set(
            userRef,
            {
              'ownedNameStyles': FieldValue.arrayUnion([style.id]),
            },
            SetOptions(merge: true));
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${style.name} נרכש! לחץ "הצמד" כדי להפעיל')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('הרכישה נכשלה, נסה שוב')),
      );
    }
  }

  Future<void> _equipStyle(
    BuildContext context,
    WidgetRef ref,
    NameStyle style,
  ) async {
    HapticFeedback.lightImpact();
    final uid = ref.read(firebaseUserProvider).valueOrNull?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance
          .doc('users/$uid')
          .set({'selectedNameStyle': style.id}, SetOptions(merge: true));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                style.isNone ? 'הצבע הוסר' : '${style.name} הוצמד!')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('שגיאה בהצמדת הצבע')),
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

// ── Name style grid ───────────────────────────────────────────────────────────

class _NameGrid extends StatelessWidget {
  final List<NameStyle> styles;
  final int coins;
  final String userName;
  final String selected;
  final List<String> owned;
  final void Function(NameStyle) onBuy;
  final void Function(NameStyle) onEquip;

  const _NameGrid({
    required this.styles,
    required this.coins,
    required this.userName,
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
        childAspectRatio: 1.9,
      ),
      itemCount: styles.length,
      itemBuilder: (context, index) {
        final style = styles[index];
        final isOwned = style.isFree || owned.contains(style.id);
        final isSelected = selected == style.id;
        final canAfford = coins >= style.price;

        return _NameTile(
          style: style,
          userName: userName,
          isOwned: isOwned,
          isSelected: isSelected,
          canAfford: canAfford,
          onTap: () {
            if (isOwned) {
              if (!isSelected) onEquip(style);
            } else {
              onBuy(style);
            }
          },
        );
      },
    );
  }
}

// ── Name style tile ───────────────────────────────────────────────────────────

class _NameTile extends StatelessWidget {
  final NameStyle style;
  final String userName;
  final bool isOwned;
  final bool isSelected;
  final bool canAfford;
  final VoidCallback onTap;

  const _NameTile({
    required this.style,
    required this.userName,
    required this.isOwned,
    required this.isSelected,
    required this.canAfford,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    final accent = style.accent;

    final borderColor = isSelected
        ? gold
        : isOwned
            ? accent.withOpacity(0.55)
            : accent.withOpacity(0.22);

    return GestureDetector(
      onTap: isSelected ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(10),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Live name preview
            Center(
              child: PlayerNameText(
                text: userName,
                styleId: style.id,
                base: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _StatusChip(
              style: style,
              isOwned: isOwned,
              isSelected: isSelected,
              canAfford: canAfford,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final NameStyle style;
  final bool isOwned;
  final bool isSelected;
  final bool canAfford;

  const _StatusChip({
    required this.style,
    required this.isOwned,
    required this.isSelected,
    required this.canAfford,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    final accent = style.accent;

    if (isSelected) {
      return const _Chip(label: 'מוצמד ✓', color: gold);
    }
    if (isOwned) {
      return _Chip(
          label: 'הצמד', color: accent, icon: Icons.touch_app_rounded);
    }
    return _Chip(
      label: '${style.price}',
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
                fontSize: 11,
              ),
            ),
          ),
          if (trailingCoin) ...[
            const SizedBox(width: 2),
            const CoinIcon(size: 12),
          ],
        ],
      ),
    );
  }
}
