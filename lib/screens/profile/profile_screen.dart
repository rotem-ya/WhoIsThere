import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/build_info.dart';
import '../../core/ui/app_scaffold.dart';
// TEMP DEBUG — remove before shipping vault visual to production
import '../debug/cartographic_vault_preview_screen.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../core/utils/display_name_sanitizer.dart';
import '../../providers/providers.dart';
import '../../services/qa_logger_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/player_avatar.dart';
import '../../widgets/common/pressable_scale.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _showEditNameDialog(
      BuildContext context, WidgetRef ref, String userId, String currentName) async {
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.accent));
          }

          return Column(
            children: [
              AppHeader(
                title: 'פרופיל',
                leading: IconButton(
                  icon:
                      const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.maybePop(context),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  onPressed: () async {
                    await ref.read(authServiceProvider).signOut();
                    if (context.mounted) context.go('/auth');
                  },
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          children: [
                            PlayerAvatar(
                              name: user.name,
                              photoUrl: user.photoUrl,
                              radius: 50,
                            ).animate().fadeIn(duration: 300.ms).scaleXY(begin: 0.93, duration: 300.ms, curve: Curves.easeOut),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    user.name,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.titleDark,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                InkWell(
                                  onTap: () => _showEditNameDialog(
                                      context, ref, user.id, user.name),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.edit_rounded,
                                      size: 18,
                                      color: AppColors.primary.withOpacity(0.75),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text('שחקן פעיל',
                                style: AppTextStyles.subtitleDark),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                              child: _StatCard(
                                  label: 'נקודות',
                                  value: '${user.totalPoints}',
                                  icon: Icons.star_rounded)
                                  .animate().fadeIn(delay: 60.ms, duration: 250.ms)
                                  .scaleXY(begin: 0.96, delay: 60.ms, duration: 250.ms, curve: Curves.easeOut)),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                              child: _StatCard(
                                  label: 'תמונות',
                                  value: '${user.purchasedImageIds.length}',
                                  icon: Icons.image_rounded)
                                  .animate().fadeIn(delay: 110.ms, duration: 250.ms)
                                  .scaleXY(begin: 0.96, delay: 110.ms, duration: 250.ms, curve: Curves.easeOut)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                              child: _StatCard(
                                  label: 'ערכות',
                                  value: '${user.purchasedThemeIds.length}',
                                  icon: Icons.palette_rounded)
                                  .animate().fadeIn(delay: 160.ms, duration: 250.ms)
                                  .scaleXY(begin: 0.96, delay: 160.ms, duration: 250.ms, curve: Curves.easeOut)),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                              child: _StatCard(
                                  label: 'ניצחון',
                                  value: '+10~40',
                                  icon: Icons.emoji_events_rounded)
                                  .animate().fadeIn(delay: 210.ms, duration: 250.ms)
                                  .scaleXY(begin: 0.96, delay: 210.ms, duration: 250.ms, curve: Curves.easeOut)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            _PointInfo('🧩 הנח חתיכה', '+1 עד +4 נק׳'),
                            _PointInfo('🏆 ניחוש נכון', '+10 עד +40 נק׳'),
                            _PointInfo('❌ ניחוש שגוי', '-1 עד -4 נק׳'),
                            _PointInfo('👑 הצבעת מארח', '×2'),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // ── QA tools (inside scroll — no sticky overlap) ──
                      TextButton.icon(
                        onPressed: () async {
                          await QaLoggerService.instance.copyToClipboard();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'הועתקו ${QaLoggerService.instance.eventCount} אירועים ללוחית'),
                                duration: const Duration(seconds: 2),
                                backgroundColor: Colors.green.shade800,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.content_copy_rounded, size: 16),
                        label: const Text('העתק לוג QA'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white38,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      // TEMP DEBUG — Cartographic Vault visual prototype entry point.
                      // Remove this button before shipping vault visuals to production.
                      TextButton.icon(
                        onPressed: () {
                          QaLoggerService.instance.log('VISUAL_PREVIEW', 'VISUAL_PREVIEW_OPENED');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CartographicVaultPreviewScreen(),
                            ),
                          ).then((_) {
                            QaLoggerService.instance.log('VISUAL_PREVIEW', 'VISUAL_PREVIEW_BACK');
                          });
                        },
                        icon: const Icon(Icons.map_outlined, size: 16),
                        label: const Text('Vault Preview [debug]'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white24,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const Text(
                        kBuildLabel,
                        style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),
              Stack(
                children: [
                  Positioned.fill(
                    child: SoftPulse(
                      minOpacity: 0.0,
                      maxOpacity: 0.20,
                      period: const Duration(milliseconds: 2800),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFFD4AF37),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  AppButton(
                    label: 'עבור לחנות',
                    icon: Icons.store_rounded,
                    onPressed: () => context.push('/store'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(
            child: Text('שגיאה: $e', style: AppTextStyles.subtitleLight)),
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
                  borderSide: BorderSide(color: Colors.white24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white24),
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(height: AppSpacing.sm),
          Text(value,
              textDirection: TextDirection.ltr, style: AppTextStyles.titleDark),
          Text(label, style: AppTextStyles.subtitleDark),
        ],
      ),
    );
  }
}

class _PointInfo extends StatelessWidget {
  final String label;
  final String value;

  const _PointInfo(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.body)),
          Text(value,
              textDirection: TextDirection.ltr,
              style: AppTextStyles.body.copyWith(color: AppColors.primary)),
        ],
      ),
    );
  }
}
