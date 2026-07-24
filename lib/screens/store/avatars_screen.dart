import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/candy_theme.dart';
import '../../widgets/common/pressable.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../models/avatar_choice.dart';
import '../../providers/providers.dart';
import '../../services/sfx_service.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/player_avatar.dart';
import '../../widgets/common/player_name_text.dart';
import '../../widgets/economy/coin_display.dart';
import '../../widgets/economy/coin_icon.dart';
import '../../widgets/store/premium_unlock.dart';

/// The avatar the current user has equipped (defaults to 'auto').
final selectedAvatarProvider = StreamProvider.autoDispose<String>((ref) {
  final userAsync = ref.watch(firebaseUserProvider);
  return userAsync.maybeWhen(
    data: (user) {
      if (user == null) return Stream.value('auto');
      return FirebaseFirestore.instance
          .doc('users/${user.uid}')
          .snapshots()
          .map((snap) => (snap.data()?['selectedAvatar'] as String?) ?? 'auto');
    },
    orElse: () => Stream.value('auto'),
  );
});

/// Avatar ids the current user owns ('auto' + free avatars are always owned).
final ownedAvatarsProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final userAsync = ref.watch(firebaseUserProvider);
  return userAsync.maybeWhen(
    data: (user) {
      if (user == null) return Stream.value(const <String>['auto']);
      return FirebaseFirestore.instance
          .doc('users/${user.uid}')
          .snapshots()
          .map((snap) =>
              List<String>.from(snap.data()?['ownedAvatars'] ?? const <String>[]));
    },
    orElse: () => Stream.value(const <String>['auto']),
  );
});

class AvatarsScreen extends ConsumerWidget {
  const AvatarsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(walletProvider).valueOrNull?.coins ?? 0;
    final selected = ref.watch(selectedAvatarProvider).valueOrNull ?? 'auto';
    final owned = ref.watch(ownedAvatarsProvider).valueOrNull ?? const ['auto'];
    final userName = ref.watch(currentUserProvider).valueOrNull?.name ?? '';

    // קטלוג חי: דריסות/תוספות מהאדמין, active:false מוסתר, ורענון חי דרך
    // cosmeticsRevisionProvider (כמו שאר מסכי הקוסמטיקה).
    ref.watch(cosmeticsRevisionProvider);
    final catalog =
        allAvatarChoices.where((a) => a.active || a.isAuto).toList();
    final free = catalog.where((a) => a.tier == AvatarTier.free).toList();
    final basic =
        catalog.where((a) => a.tier == AvatarTier.basic).toList();
    final rare = catalog.where((a) => a.tier == AvatarTier.rare).toList();
    final prem =
        catalog.where((a) => a.tier == AvatarTier.premium).toList();

    return AppScaffold(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
            child: AppHeader(
              title: 'אווטרים',
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
              'בחר אווטר, יופיע ליד השם שלך במשחק',
              style: AppTextStyles.subtitleLight,
              textAlign: TextAlign.center,
            ),
          ),
          _AvatarHero(avatarId: selected, userName: userName),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
              children: [
                const _SectionHeader(
                    label: 'חינמי',
                    icon: Icons.star_outline_rounded,
                    color: Candy.inkMuted),
                const SizedBox(height: AppSpacing.sm),
                _AvatarGrid(
                  avatars: free,
                  coins: coins,
                  userName: userName,
                  selected: selected,
                  owned: owned,
                  onBuy: (a) => _buy(context, ref, a, coins),
                  onEquip: (a) => _equip(context, ref, a),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionHeader(
                    label: 'בסיסי  50–150',
                    trailingCoin: true,
                    icon: Icons.palette_outlined,
                    color: Candy.teal),
                const SizedBox(height: AppSpacing.sm),
                _AvatarGrid(
                  avatars: basic,
                  coins: coins,
                  userName: userName,
                  selected: selected,
                  owned: owned,
                  onBuy: (a) => _buy(context, ref, a, coins),
                  onEquip: (a) => _equip(context, ref, a),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionHeader(
                    label: 'נדיר  300–500',
                    trailingCoin: true,
                    icon: Icons.auto_awesome_outlined,
                    color: Candy.teal),
                const SizedBox(height: AppSpacing.sm),
                _AvatarGrid(
                  avatars: rare,
                  coins: coins,
                  userName: userName,
                  selected: selected,
                  owned: owned,
                  onBuy: (a) => _buy(context, ref, a, coins),
                  onEquip: (a) => _equip(context, ref, a),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionHeader(
                    label: 'פרימיום  1000',
                    trailingCoin: true,
                    icon: Icons.diamond_outlined,
                    color: Candy.gold),
                const SizedBox(height: AppSpacing.sm),
                _AvatarGrid(
                  avatars: prem,
                  coins: coins,
                  userName: userName,
                  selected: selected,
                  owned: owned,
                  onBuy: (a) => _buy(context, ref, a, coins),
                  onEquip: (a) => _equip(context, ref, a),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _buy(
    BuildContext context,
    WidgetRef ref,
    AvatarChoice avatar,
    int currentCoins,
  ) async {
    HapticFeedback.lightImpact();
    if (currentCoins < avatar.price) {
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
        if (before < avatar.price) throw Exception('insufficient_coins');

        final userSnap = await tx.get(userRef);
        final owned = List<String>.from(
            userSnap.data()?['ownedAvatars'] ?? const <String>[]);
        if (owned.contains(avatar.id)) return;

        tx.set(
            walletRef,
            {
              'coins': before - avatar.price,
              'totalSpent': FieldValue.increment(avatar.price),
            },
            SetOptions(merge: true));
        tx.set(
            userRef,
            {
              'ownedAvatars': FieldValue.arrayUnion([avatar.id]),
            },
            SetOptions(merge: true));
      });

      SfxService.instance.purchase();
      if (!context.mounted) return;
      if (avatar.tier == AvatarTier.premium) {
        PremiumUnlock.celebrate(context, avatar.name);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${avatar.name} נרכש! לחץ "הצמד" כדי להפעיל')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('הרכישה נכשלה, נסה שוב')),
      );
    }
  }

  Future<void> _equip(
    BuildContext context,
    WidgetRef ref,
    AvatarChoice avatar,
  ) async {
    HapticFeedback.lightImpact();
    final uid = ref.read(firebaseUserProvider).valueOrNull?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance
          .doc('users/$uid')
          .set({'selectedAvatar': avatar.id}, SetOptions(merge: true));
      SfxService.instance.equip();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${avatar.name} הוצמד!')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('שגיאה בהצמדת האווטר')),
      );
    }
  }
}

// ── Live hero preview ───────────────────────────────────────────────────────────

class _AvatarHero extends StatelessWidget {
  final String avatarId;
  final String userName;

  const _AvatarHero({required this.avatarId, required this.userName});

  @override
  Widget build(BuildContext context) {
    final choice = avatarChoiceFor(avatarId);
    final accent = choice.accent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent.withOpacity(0.22), Candy.surfaceLow],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withOpacity(0.45), width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The avatar gently pulses + glows — a live, premium preview.
            PlayerAvatar(
              name: userName.isEmpty ? '🙂' : userName,
              seed: userName,
              radius: 42,
              avatarId: avatarId,
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 1.0, end: 1.06, duration: 1100.ms, curve: Curves.easeInOut)
                .boxShadow(
                  begin: BoxShadow(
                      color: accent.withOpacity(0.0), blurRadius: 0, spreadRadius: 0),
                  end: BoxShadow(
                      color: accent.withOpacity(0.55), blurRadius: 22, spreadRadius: 2),
                  duration: 1100.ms,
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: 10),
            PlayerNameText(
              text: choice.name,
              styleId: 'none',
              base: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            const Text('תצוגה חיה',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
    );
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
    this.color = Candy.gold,
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

// ── Avatar grid ───────────────────────────────────────────────────────────────

class _AvatarGrid extends StatelessWidget {
  final List<AvatarChoice> avatars;
  final int coins;
  final String userName;
  final String selected;
  final List<String> owned;
  final void Function(AvatarChoice) onBuy;
  final void Function(AvatarChoice) onEquip;

  const _AvatarGrid({
    required this.avatars,
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
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.78,
      ),
      itemCount: avatars.length,
      itemBuilder: (context, index) {
        final avatar = avatars[index];
        final isOwned = avatar.isFree || owned.contains(avatar.id);
        final isSelected = selected == avatar.id;
        final canAfford = coins >= avatar.price;

        return _AvatarTile(
          avatar: avatar,
          userName: userName,
          isOwned: isOwned,
          isSelected: isSelected,
          canAfford: canAfford,
          onTap: () {
            if (isOwned) {
              if (!isSelected) onEquip(avatar);
            } else {
              onBuy(avatar);
            }
          },
        );
      },
    );
  }
}

// ── Avatar tile (live preview) ────────────────────────────────────────────────

class _AvatarTile extends StatelessWidget {
  final AvatarChoice avatar;
  final String userName;
  final bool isOwned;
  final bool isSelected;
  final bool canAfford;
  final VoidCallback onTap;

  const _AvatarTile({
    required this.avatar,
    required this.userName,
    required this.isOwned,
    required this.isSelected,
    required this.canAfford,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Candy.gold;
    final accent = avatar.accent;

    final borderColor = isSelected
        ? gold
        : isOwned
            ? accent.withOpacity(0.55)
            : accent.withOpacity(0.22);

    return Pressable(
      onTap: isSelected ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Candy.surfaceLow,
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
          children: [
            Expanded(
              child: Center(
                child: PlayerAvatar(
                  name: userName,
                  seed: userName,
                  radius: 26,
                  avatarId: avatar.id,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                avatar.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _StatusChip(
                avatar: avatar,
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
  final AvatarChoice avatar;
  final bool isOwned;
  final bool isSelected;
  final bool canAfford;

  const _StatusChip({
    required this.avatar,
    required this.isOwned,
    required this.isSelected,
    required this.canAfford,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Candy.gold;
    final accent = avatar.accent;

    if (isSelected) {
      return const _Chip(label: 'מוצמד ✓', color: gold);
    }
    if (isOwned) {
      return _Chip(
          label: 'הצמד', color: accent, icon: Icons.touch_app_rounded);
    }
    return _Chip(
      label: '${avatar.price}',
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
