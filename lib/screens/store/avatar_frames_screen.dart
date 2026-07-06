import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../models/avatar_frame.dart';
import '../../providers/providers.dart';
import '../../services/sfx_service.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/player_avatar.dart';
import '../../widgets/economy/coin_display.dart';
import '../../widgets/economy/coin_icon.dart';

/// The frame the current user has equipped (defaults to 'none').
final selectedFrameProvider = StreamProvider.autoDispose<String>((ref) {
  final userAsync = ref.watch(firebaseUserProvider);
  return userAsync.maybeWhen(
    data: (user) {
      if (user == null) return Stream.value('none');
      return FirebaseFirestore.instance
          .doc('users/${user.uid}')
          .snapshots()
          .map((snap) =>
              (snap.data()?['selectedAvatarFrame'] as String?) ?? 'none');
    },
    orElse: () => Stream.value('none'),
  );
});

/// Frame ids the current user owns ('none' is always implicitly owned).
final ownedFramesProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final userAsync = ref.watch(firebaseUserProvider);
  return userAsync.maybeWhen(
    data: (user) {
      if (user == null) return Stream.value(['none']);
      return FirebaseFirestore.instance
          .doc('users/${user.uid}')
          .snapshots()
          .map((snap) {
        final owned =
            List<String>.from(snap.data()?['ownedFrames'] ?? const <String>[]);
        if (!owned.contains('none')) owned.insert(0, 'none');
        return owned;
      });
    },
    orElse: () => Stream.value(['none']),
  );
});

class AvatarFramesScreen extends ConsumerWidget {
  const AvatarFramesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(walletProvider).valueOrNull?.coins ?? 0;
    final selected = ref.watch(selectedFrameProvider).valueOrNull ?? 'none';
    final owned = ref.watch(ownedFramesProvider).valueOrNull ?? ['none'];
    final userName = ref.watch(currentUserProvider).valueOrNull?.name ?? 'את/ה';

    // Rebuild when the admin edits the live cosmetics catalog.
    ref.watch(cosmeticsRevisionProvider);
    final catalog = allAvatarFrames.where((f) => f.active).toList();

    final basic = catalog.where((f) => f.tier == FrameTier.basic).toList();
    final rare = catalog.where((f) => f.tier == FrameTier.rare).toList();
    final prem =
        catalog.where((f) => f.tier == FrameTier.premium).toList();
    final none = catalog.firstWhere((f) => f.id == 'none',
        orElse: () => kAvatarFrames.first);

    return AppScaffold(
      backgroundGradient: AppColors.pageBackground,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
            child: AppHeader(
              title: 'מסגרות אווטר',
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
              'בחר מסגרת לאווטר שלך — שאר השחקנים יראו אותה',
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
                    color: const Color(0xFF8090B0)),
                const SizedBox(height: AppSpacing.sm),
                _FrameGrid(
                  frames: [none],
                  coins: coins,
                  userName: userName,
                  selected: selected,
                  owned: owned,
                  onBuy: (f) => _buyFrame(context, ref, f, coins),
                  onEquip: (f) => _equipFrame(context, ref, f),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionHeader(
                    label: 'בסיסי  50–150',
                    trailingCoin: true,
                    icon: Icons.palette_outlined,
                    color: const Color(0xFF4CA1AF)),
                const SizedBox(height: AppSpacing.sm),
                _FrameGrid(
                  frames: basic,
                  coins: coins,
                  userName: userName,
                  selected: selected,
                  owned: owned,
                  onBuy: (f) => _buyFrame(context, ref, f, coins),
                  onEquip: (f) => _equipFrame(context, ref, f),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionHeader(
                    label: 'נדיר  300–500',
                    trailingCoin: true,
                    icon: Icons.auto_awesome_outlined,
                    color: const Color(0xFF00FFFF)),
                const SizedBox(height: AppSpacing.sm),
                _FrameGrid(
                  frames: rare,
                  coins: coins,
                  userName: userName,
                  selected: selected,
                  owned: owned,
                  onBuy: (f) => _buyFrame(context, ref, f, coins),
                  onEquip: (f) => _equipFrame(context, ref, f),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionHeader(
                    label: 'פרימיום  1000',
                    trailingCoin: true,
                    icon: Icons.diamond_outlined,
                    color: const Color(0xFFFFD700)),
                const SizedBox(height: AppSpacing.sm),
                _FrameGrid(
                  frames: prem,
                  coins: coins,
                  userName: userName,
                  selected: selected,
                  owned: owned,
                  onBuy: (f) => _buyFrame(context, ref, f, coins),
                  onEquip: (f) => _equipFrame(context, ref, f),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _buyFrame(
    BuildContext context,
    WidgetRef ref,
    AvatarFrame frame,
    int currentCoins,
  ) async {
    HapticFeedback.lightImpact();
    if (currentCoins < frame.price) {
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
        if (before < frame.price) throw Exception('insufficient_coins');

        final userSnap = await tx.get(userRef);
        final owned = List<String>.from(
            userSnap.data()?['ownedFrames'] ?? const <String>[]);
        if (owned.contains(frame.id)) return;

        tx.set(
            walletRef,
            {
              'coins': before - frame.price,
              'totalSpent': FieldValue.increment(frame.price),
            },
            SetOptions(merge: true));
        tx.set(
            userRef,
            {
              'ownedFrames': FieldValue.arrayUnion([frame.id]),
            },
            SetOptions(merge: true));
      });

      if (!context.mounted) return;
      SfxService.instance.purchase();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${frame.name} נרכשה! לחץ "הצמד" כדי להפעיל')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('הרכישה נכשלה, נסה שוב')),
      );
    }
  }

  Future<void> _equipFrame(
    BuildContext context,
    WidgetRef ref,
    AvatarFrame frame,
  ) async {
    HapticFeedback.lightImpact();
    final uid = ref.read(firebaseUserProvider).valueOrNull?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance
          .doc('users/$uid')
          .set({'selectedAvatarFrame': frame.id}, SetOptions(merge: true));
      SfxService.instance.equip();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                frame.isNone ? 'המסגרת הוסרה' : '${frame.name} הוצמדה!')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('שגיאה בהצמדת המסגרת')),
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

// ── Frame grid ────────────────────────────────────────────────────────────────

class _FrameGrid extends StatelessWidget {
  final List<AvatarFrame> frames;
  final int coins;
  final String userName;
  final String selected;
  final List<String> owned;
  final void Function(AvatarFrame) onBuy;
  final void Function(AvatarFrame) onEquip;

  const _FrameGrid({
    required this.frames,
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
        childAspectRatio: 0.72,
      ),
      itemCount: frames.length,
      itemBuilder: (context, index) {
        final frame = frames[index];
        final isOwned = frame.isFree || owned.contains(frame.id);
        final isSelected = selected == frame.id;
        final canAfford = coins >= frame.price;

        return _FrameTile(
          frame: frame,
          userName: userName,
          isOwned: isOwned,
          isSelected: isSelected,
          canAfford: canAfford,
          onTap: () {
            if (isOwned) {
              if (!isSelected) onEquip(frame);
            } else {
              onBuy(frame);
            }
          },
        );
      },
    );
  }
}

// ── Compact frame tile ────────────────────────────────────────────────────────

class _FrameTile extends StatelessWidget {
  final AvatarFrame frame;
  final String userName;
  final bool isOwned;
  final bool isSelected;
  final bool canAfford;
  final VoidCallback onTap;

  const _FrameTile({
    required this.frame,
    required this.userName,
    required this.isOwned,
    required this.isSelected,
    required this.canAfford,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    final accent = frame.accent;

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
                  isSelected ? 0.45 : isOwned ? 0.18 : 0.08),
              blurRadius: isSelected ? 14 : 8,
              spreadRadius: isSelected ? 1 : 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Live preview of the frame around an avatar
            Expanded(
              child: Center(
                child: PlayerAvatar(
                  name: userName,
                  radius: 26,
                  frameId: frame.id,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                frame.name,
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
                frame: frame,
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
  final AvatarFrame frame;
  final bool isOwned;
  final bool isSelected;
  final bool canAfford;

  const _StatusChip({
    required this.frame,
    required this.isOwned,
    required this.isSelected,
    required this.canAfford,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    final accent = frame.accent;

    if (isSelected) {
      return const _Chip(label: 'מוצמד ✓', color: gold);
    }
    if (isOwned) {
      return _Chip(
          label: 'הצמד', color: accent, icon: Icons.touch_app_rounded);
    }
    return _Chip(
      label: '${frame.price}',
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
