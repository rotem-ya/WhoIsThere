import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/build_info.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../core/utils/display_name_sanitizer.dart';
import '../../providers/providers.dart';
import '../../services/qa_logger_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/player_avatar.dart';
import 'discovered_images_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _showEditNameDialog(BuildContext context, WidgetRef ref, String userId, String currentName) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _EditNameDialog(userId: userId, currentName: currentName, ref: ref),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return AppScaffold(
      backgroundGradient: AppColors.pageBackground,
      padding: EdgeInsets.zero,
      child: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: CircularProgressIndicator(color: AppColors.accent));

          final discoveredCount = user.discoveredImageIds.length;

          return Column(
            children: [
              // ── Header ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                child: AppHeader(
                  title: 'פרופיל',
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () { HapticFeedback.lightImpact(); Navigator.maybePop(context); },
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Colors.white),
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      await ref.read(authServiceProvider).signOut();
                      if (context.mounted) context.go('/auth');
                    },
                  ),
                ),
              ),

              // ── Hero card ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0D2137), Color(0xFF091828)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF1E4060).withOpacity(0.8), width: 1),
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      PlayerAvatar(name: user.name, photoUrl: user.photoUrl, radius: 34),
                      const SizedBox(width: 16),
                      // Name + edit
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    _showEditNameDialog(context, ref, user.id, user.name);
                                  },
                                  child: Icon(Icons.edit_rounded, size: 15, color: AppColors.primary.withOpacity(0.7)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Wallet coins display inline
                            _WalletCoinsInline(userId: user.id),
                          ],
                        ),
                      ),
                      // Discovered count big display
                      Column(
                        children: [
                          Text(
                            '$discoveredCount',
                            style: const TextStyle(
                              color: Color(0xFF87CEEB),
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const Text(
                            'גילויים',
                            style: TextStyle(
                              color: Color(0xFF4A8BAA),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // ── Stats row ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(child: _MiniStat(icon: Icons.star_rounded, value: '${user.totalPoints}', label: 'נקודות')),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: _MiniStat(icon: Icons.palette_rounded, value: '${user.purchasedThemeIds.length}', label: 'ערכות')),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: _MiniStat(icon: Icons.image_rounded, value: '${user.purchasedImageIds.length}', label: 'תמונות')),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // ── Discoveries CTA ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DiscoveredImagesScreen(
                          discoveredImageIds: user.discoveredImageIds,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1828),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF87CEEB).withOpacity(0.25), width: 0.8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF87CEEB).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(child: Text('🌍', style: TextStyle(fontSize: 22))),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'המקומות שגיליתי',
                                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                discoveredCount == 0 ? 'עדיין לא גילית מקומות' : '$discoveredCount מקומות ברחבי העולם',
                                style: const TextStyle(color: Color(0xFF4A8BAA), fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF4A8BAA), size: 22),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // ── Economy info ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1828),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E3A5A).withOpacity(0.6), width: 0.8),
                  ),
                  child: Column(
                    children: const [
                      _PointRow('🧩 הנח חתיכה', '+1 עד +4 נק׳'),
                      _PointRow('🏆 ניחוש נכון', '+10 עד +40 נק׳'),
                      _PointRow('❌ ניחוש שגוי', '−1 נק׳, −2 מטבעות'),
                      _PointRow('👑 כרטיס מארח', '×2 בונוס'),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // ── QA row ───────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      await QaLoggerService.instance.copyToClipboard();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('הועתקו ${QaLoggerService.instance.eventCount} אירועים'),
                            duration: const Duration(seconds: 2),
                            backgroundColor: Colors.green.shade800,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.content_copy_rounded, size: 13),
                    label: const Text('QA'),
                    style: TextButton.styleFrom(foregroundColor: Colors.white24, textStyle: const TextStyle(fontSize: 11)),
                  ),
                  const Text(kBuildLabel, style: TextStyle(color: Colors.white24, fontSize: 10)),
                ],
              ),

              // ── Store button ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                child: AppButton(
                  label: 'עבור לחנות',
                  icon: Icons.store_rounded,
                  onPressed: () => context.push('/store'),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(child: Text('שגיאה: $e', style: AppTextStyles.subtitleLight)),
      ),
    );
  }
}

class _WalletCoinsInline extends ConsumerWidget {
  final String userId;
  const _WalletCoinsInline({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider).valueOrNull;
    final coins = wallet?.coins ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.monetization_on, color: Colors.amber, size: 14),
        const SizedBox(width: 4),
        Text(
          '$coins מטבעות',
          style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _MiniStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1828),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E3A5A).withOpacity(0.6), width: 0.8),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900), textDirection: TextDirection.ltr),
          Text(label, style: const TextStyle(color: Color(0xFF4A8BAA), fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PointRow extends StatelessWidget {
  final String label;
  final String value;
  const _PointRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600))),
          Text(value, style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w800), textDirection: TextDirection.ltr),
        ],
      ),
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  final String userId;
  final String currentName;
  final WidgetRef ref;

  const _EditNameDialog({
    required this.userId,
    required this.currentName,
    required this.ref,
  });

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _controller;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _controller.text.trim();
    final sanitized = DisplayNameSanitizer.sanitize(raw);
    if (sanitized == null) {
      setState(() => _error = '2–16 תווים, אותיות ומספרים בלבד');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await widget.ref
          .read(authServiceProvider)
          .updateDisplayName(widget.userId, sanitized);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = 'שמירה נכשלה, נסה שוב');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: const Color(0xFF1A1F3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'שינוי שם',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              maxLength: 16,
              autofocus: true,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: Colors.white.withOpacity(0.07),
                errorText: _error,
                errorMaxLines: 2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: AppColors.primary.withOpacity(0.7), width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('ביטול',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text('שמור',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}
