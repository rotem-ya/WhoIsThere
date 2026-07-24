import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/share_util.dart';
import '../../core/theme/candy_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/build_info.dart';
import 'our_apps_screen.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../core/utils/display_name_sanitizer.dart';
import '../../providers/providers.dart';
import '../../services/qa_logger_service.dart';
import '../../services/report_service.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/player_avatar.dart';
import '../../widgets/common/rank_ladder_sheet.dart';
import 'discovered_images_screen.dart';
import '../store/card_skins_screen.dart' show ownedSkinsProvider;
import '../store/avatars_screen.dart' show selectedAvatarProvider;
import '../../widgets/common/player_name_text.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _upgrading = false;
  bool _deleting = false;

  /// App Store 5.1.1(v): lets the user permanently delete their account and
  /// data from within the app. Confirms first (destructive + irreversible),
  /// then deletes and returns to the auth screen.
  Future<void> _confirmDeleteAccount() async {
    HapticFeedback.lightImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Candy.surfaceLow,
        title: const Text('מחיקת חשבון', style: TextStyle(color: Colors.white)),
        content: const Text(
          'הפעולה תמחק לצמיתות את החשבון שלך וכל הנתונים (מטבעות, פריטים, '
          'התקדמות, חברים). לא ניתן לשחזר. להמשיך?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ביטול', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('מחק לצמיתות',
                style: TextStyle(
                    color: Color(0xFFE06B6B), fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await ref.read(authServiceProvider).deleteAccount();
      if (!mounted) return;
      context.go('/auth');
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('מחיקת החשבון נכשלה. התחבר מחדש ונסה שוב.'),
          backgroundColor: Color(0xFF8A2A2A),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// Free-text feedback dialog → ReportService writes it to Firestore.
  Future<void> _showFeedbackDialog(BuildContext context, String userName) async {
    HapticFeedback.lightImpact();
    final controller = TextEditingController();
    var sending = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Candy.surfaceLow,
          title: const Text('שלח משוב', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('ספר לנו מה אהבת, מה חסר, או על תקלה שנתקלת בה:',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                maxLength: 2000,
                autofocus: true,
                textDirection: TextDirection.rtl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'המשוב שלך…',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  counterStyle: const TextStyle(color: Colors.white24),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.of(ctx).pop(),
              child: const Text('ביטול', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: sending
                  ? null
                  : () async {
                      if (controller.text.trim().isEmpty) return;
                      setLocal(() => sending = true);
                      final ok = await ReportService.instance
                          .submitFeedback(text: controller.text, name: userName);
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok ? 'תודה! המשוב נשלח 🙏' : 'שליחת המשוב נכשלה, נסה שוב'),
                            backgroundColor:
                                ok ? const Color(0xFF1B5E20) : const Color(0xFF8A2A2A),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
              child: Text(sending ? 'שולח…' : 'שלח',
                  style: const TextStyle(
                      color: Candy.blue, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  /// Shares the app with a friend via the OS share sheet. Uses the remote
  /// store links (app_config/app) when present, falling back to the derivable
  /// Play URL — so it always works, even before the App Store link is set.
  Future<void> _shareApp() async {
    HapticFeedback.lightImpact();
    QaLoggerService.instance.log('SHARE', 'SHARE_APP_TAP');
    final info = ref.read(appUpdateInfoProvider).valueOrNull;
    final message = AppConstants.shareMessage(
      androidUrl: info?.androidUrl,
      iosUrl: info?.iosUrl,
    );
    try {
      await shareText(context, message, subject: 'מה בתמונה?');
    } catch (e) {
      QaLoggerService.instance.log('SHARE', 'SHARE_APP_ERROR $e');
    }
  }

  Future<void> _showEditNameDialog(BuildContext context, String userId, String currentName) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _EditNameDialog(userId: userId, currentName: currentName, ref: ref),
    );
  }

  Future<void> _upgradeWithGoogle() async {
    if (_upgrading) return;
    HapticFeedback.lightImpact();
    setState(() => _upgrading = true);
    try {
      final user = await ref.read(authServiceProvider).signInWithGoogle();
      if (!mounted) return;
      if (user != null && !user.isGuest) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('מחובר כ-${user.name} ✓', textDirection: TextDirection.rtl,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            backgroundColor: const Color(0xFF1B5E20),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      // null = user cancelled or sign-in failed silently — no snackbar needed
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('שגיאה: $e'), duration: const Duration(seconds: 3)),
      );
    } finally {
      if (mounted) setState(() => _upgrading = false);
    }
  }

  Future<void> _upgradeWithApple() async {
    if (_upgrading) return;
    HapticFeedback.lightImpact();
    QaLoggerService.instance.log('AUTH', 'PROFILE_APPLE_UPGRADE_ATTEMPT');
    setState(() => _upgrading = true);
    try {
      final user = await ref.read(authServiceProvider).signInWithApple();
      if (!mounted) return;
      if (user != null && !user.isGuest) {
        QaLoggerService.instance.log('AUTH', 'PROFILE_APPLE_UPGRADE_OK uid=${user.id}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('מחובר כ-${user.name} ✓', textDirection: TextDirection.rtl,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            backgroundColor: const Color(0xFF1B5E20),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      // null = user cancelled or sign-in failed silently — no snackbar needed
    } catch (e) {
      final msg = e.toString();
      QaLoggerService.instance.log('AUTH',
          'PROFILE_APPLE_UPGRADE_ERROR ${msg.length > 80 ? msg.substring(0, 80) : msg}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('שגיאה: $e'), duration: const Duration(seconds: 3)),
      );
    } finally {
      if (mounted) setState(() => _upgrading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final selectedAvatar =
        ref.watch(selectedAvatarProvider).valueOrNull ?? 'auto';

    return AppScaffold(
      padding: EdgeInsets.zero,
      child: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: CircularProgressIndicator(color: Candy.teal));

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
                    icon: const Icon(Icons.logout_rounded, color: Colors.white70),
                    tooltip: 'יציאה',
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      await ref.read(authServiceProvider).signOut();
                      if (context.mounted) context.go('/auth');
                    },
                  ),
                ),
              ),

              // ── Body ─────────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  // Scroll + clear the Android system nav bar so the last
                  // card (guest Google upgrade) isn't hidden underneath it.
                  padding: EdgeInsets.only(
                      bottom: AppSpacing.lg +
                          MediaQuery.of(context).viewPadding.bottom),
                  child: Column(
                    children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Candy.surface, Candy.surfaceLow],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Candy.teal.withOpacity(0.8), width: 1),
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      PlayerAvatar(
                          name: user.name,
                          photoUrl: user.photoUrl,
                          radius: 34,
                          avatarId: selectedAvatar),
                      const SizedBox(width: 16),
                      // Name + edit
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  // Scale the nickname down to fit instead of
                                  // truncating it, so the whole name stays visible.
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: AlignmentDirectional.centerStart,
                                    child: PlayerNameText(
                                      text: user.name,
                                      base: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    _showEditNameDialog(context, user.id, user.name);
                                  },
                                  child: Icon(Icons.edit_rounded, size: 15, color: Candy.gold.withOpacity(0.7)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            _ProviderBadge(provider: user.provider, isGuest: user.isGuest),
                            const SizedBox(height: 4),
                            // Wallet coins display inline
                            _WalletCoinsInline(userId: user.id),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Discovered count big display
                      Column(
                        children: [
                          Text(
                            '$discoveredCount',
                            style: const TextStyle(
                              color: Candy.teal,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const Text(
                            'גילויים',
                            style: TextStyle(
                              color: Candy.inkMuted,
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

              // ── Rank card (tap → full ladder of all 7 tiers) ─────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: RankBadgeCard(totalPoints: user.totalPoints),
              ),

              const SizedBox(height: AppSpacing.sm),

              // ── Stats row ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Builder(builder: (context) {
                  final wallet = ref.watch(walletProvider).valueOrNull;
                  final ownedSkins = ref.watch(ownedSkinsProvider).valueOrNull ?? ['default'];
                  final purchasedSkins = ownedSkins.where((s) => s != 'default').length;
                  final gamesPlayed = wallet?.totalMatchesPlayed ?? 0;
                  final gamesWon = wallet?.totalMatchesWon ?? 0;
                  return Row(
                    children: [
                      Expanded(child: _MiniStat(icon: Icons.sports_esports_rounded, value: '$gamesPlayed', label: 'משחקים')),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: _MiniStat(icon: Icons.emoji_events_rounded, value: '$gamesWon', label: 'ניצחונות')),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: _MiniStat(icon: Icons.palette_rounded, value: '$purchasedSkins', label: 'ערכות')),
                    ],
                  );
                }),
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
                      color: Candy.surfaceLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Candy.teal.withOpacity(0.25), width: 0.8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Candy.teal.withOpacity(0.1),
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
                                style: const TextStyle(color: Candy.inkMuted, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Candy.inkMuted, size: 22),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // ── Account section ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _AccountSection(
                  provider: user.provider,
                  isGuest: user.isGuest,
                  onSignOut: () async {
                    HapticFeedback.lightImpact();
                    await ref.read(authServiceProvider).signOut();
                    if (context.mounted) context.go('/auth');
                  },
                  onUpgrade: _upgrading ? null : _upgradeWithGoogle,
                  onUpgradeApple: _upgrading ? null : _upgradeWithApple,
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // ── Delete account (App Store 5.1.1(v) — in-app deletion) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Center(
                  child: TextButton.icon(
                    onPressed: _deleting ? null : _confirmDeleteAccount,
                    icon: const Icon(Icons.delete_forever_rounded,
                        size: 16, color: Color(0xFFE06B6B)),
                    label: Text(
                      _deleting ? 'מוחק…' : 'מחק חשבון',
                      style: const TextStyle(
                          color: Color(0xFFE06B6B),
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // ── Update available (always reachable, even after "later") ──
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _UpdateBanner(),
              ),

              // ── Support code — what the player gives the admin to be found ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _SupportCodeCard(
                  value: (user.email != null && user.email!.isNotEmpty)
                      ? user.email!
                      : user.id,
                  isEmail: user.email != null && user.email!.isNotEmpty,
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // ── Settings (moved here from the home top bar) ──────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Center(
                  child: TextButton.icon(
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(Icons.settings_rounded,
                        size: 18, color: Colors.white70),
                    label: const Text('הגדרות',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // ── Send feedback ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Center(
                  child: TextButton.icon(
                    onPressed: () => _showFeedbackDialog(context, user.name),
                    icon: const Icon(Icons.chat_bubble_outline_rounded,
                        size: 18, color: Candy.blue),
                    label: const Text('שלח משוב',
                        style: TextStyle(
                            color: Candy.blue,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // ── Share the app ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Center(
                  child: TextButton.icon(
                    onPressed: _shareApp,
                    icon: const Icon(Icons.ios_share_rounded,
                        size: 18, color: Color(0xFF3DCCAA)),
                    label: const Text('שתף את האפליקציה',
                        style: TextStyle(
                            color: Color(0xFF3DCCAA),
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),

              // ── Our other apps (admin-controlled list) ───────────────
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _OurAppsRow(),
              ),

              const SizedBox(height: AppSpacing.sm),

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

            ],
          ),
        ),
      ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Candy.teal)),
        error: (e, _) => Center(child: Text('שגיאה: $e', style: AppTextStyles.subtitleLight)),
      ),
    );
  }
}

/// Permanent "update available" row — shows whenever the remote config
/// advertises a newer build than this one, so the player can always update
/// even after dismissing the home-screen popup with "later".
class _UpdateBanner extends ConsumerWidget {
  const _UpdateBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(appUpdateInfoProvider).valueOrNull;
    if (info == null || !info.enabled || kBuildNumber >= info.latestBuild) {
      return const SizedBox.shrink();
    }
    final storeUrl = Platform.isIOS ? info.iosUrl : info.androidUrl;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF34D399).withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF34D399).withOpacity(0.40)),
      ),
      child: Row(
        children: [
          const Icon(Icons.system_update_rounded, color: Color(0xFF34D399)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('גרסה חדשה זמינה',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
          ),
          FilledButton(
            onPressed: storeUrl.isEmpty
                ? null
                : () async {
                    final uri = Uri.tryParse(storeUrl);
                    if (uri != null) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF34D399),
              foregroundColor: Candy.bgBottom,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('עדכן',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

/// "האפליקציות שלנו" entry — only appears when the admin has configured at
/// least one other app (app_config/app → ourApps). Tapping opens the list.
class _OurAppsRow extends ConsumerWidget {
  const _OurAppsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(appUpdateInfoProvider).valueOrNull?.ourApps ?? const [];
    if (apps.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          QaLoggerService.instance.log('OUR_APPS', 'OPEN count=${apps.length}');
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OurAppsScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Candy.surfaceLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Candy.gold.withOpacity(0.25), width: 0.8),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Candy.gold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                    child: Text('✨', style: TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('האפליקציות שלנו',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800)),
                    Text('עוד משחקים שיצרנו בשבילכם',
                        style: TextStyle(
                            color: Candy.inkMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Candy.inkMuted, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderBadge extends StatelessWidget {
  final String provider;
  final bool isGuest;
  const _ProviderBadge({required this.provider, required this.isGuest});

  @override
  Widget build(BuildContext context) {
    if (isGuest) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.person_outline_rounded, size: 12, color: Colors.white38),
          SizedBox(width: 4),
          Text('אורח', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      );
    }
    final email = FirebaseAuth.instance.currentUser?.email;
    final isGoogle = provider == 'google.com';
    final isApple = provider == 'apple.com';
    if (!isGoogle && !isApple) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isGoogle)
          const Text('G', style: TextStyle(color: Color(0xFF4285F4), fontSize: 13, fontWeight: FontWeight.w900))
        else
          const Icon(Icons.apple_rounded, size: 13, color: Colors.white70),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            email ?? (isGoogle ? 'Google' : 'Apple'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isGoogle ? const Color(0xFF4285F4) : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// "קוד תמיכה" — the value a player gives the admin so they can be found.
/// Copies the login email when present (best for the admin's email lookup),
/// otherwise the UID (works for guests). Tap to copy.
class _SupportCodeCard extends StatelessWidget {
  final String value;
  final bool isEmail;

  const _SupportCodeCard({required this.value, required this.isEmail});

  @override
  Widget build(BuildContext context) {
    // Show emails in full; shorten long UIDs for display (full value is copied).
    final shown = isEmail || value.length <= 16
        ? value
        : '${value.substring(0, 14)}…';
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('קוד התמיכה הועתק, שלח אותו לתמיכה'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green.shade800,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Row(
          children: [
            const Icon(Icons.badge_outlined, color: Colors.white54, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'קוד תמיכה',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    shown,
                    textDirection: TextDirection.ltr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.content_copy_rounded,
                color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  final String provider;
  final bool isGuest;
  final VoidCallback onSignOut;
  final VoidCallback? onUpgrade;
  final VoidCallback? onUpgradeApple;
  const _AccountSection({
    required this.provider,
    required this.isGuest,
    required this.onSignOut,
    required this.onUpgrade,
    required this.onUpgradeApple,
  });

  @override
  Widget build(BuildContext context) {
    if (isGuest) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Candy.surfaceLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Candy.tangerine.withOpacity(0.7), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: (Platform.isIOS ? Colors.white : const Color(0xFF4285F4)).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Platform.isIOS
                        ? const Icon(Icons.apple_rounded, color: Colors.white, size: 22)
                        : const Text('G', style: TextStyle(color: Color(0xFF4285F4), fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Platform.isIOS ? 'התחבר עם Apple' : 'התחבר עם Google',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                      const Text('שמור את ההתקדמות שלך', style: TextStyle(color: Candy.inkMuted, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              '⚠️ אתה משחק כאורח, מחיקת האפליקציה תמחק את כל ההתקדמות!',
              style: TextStyle(color: Candy.tangerine, fontSize: 11, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            // Google sign-in is not configured for iOS (no OAuth client in
            // GoogleService-Info.plist), so on iOS we offer Apple only.
            if (!Platform.isIOS)
              GestureDetector(
                onTap: onUpgrade,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4285F4).withOpacity(onUpgrade != null ? 0.25 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF4285F4).withOpacity(0.5), width: 0.8),
                  ),
                  alignment: Alignment.center,
                  child: onUpgrade == null
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4285F4)))
                      : const Text('התחבר עם Google עכשיו', style: TextStyle(color: Color(0xFF4285F4), fontSize: 13, fontWeight: FontWeight.w800)),
                ),
              ),
            if (Platform.isIOS)
              GestureDetector(
                onTap: onUpgradeApple,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(onUpgradeApple != null ? 0.92 : 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 0.8),
                  ),
                  alignment: Alignment.center,
                  child: onUpgradeApple == null
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.apple_rounded, size: 17, color: Colors.black),
                            SizedBox(width: 6),
                            Text('התחבר עם Apple עכשיו', style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w800)),
                          ],
                        ),
                ),
              ),
          ],
        ),
      );
    }

    final email = FirebaseAuth.instance.currentUser?.email;
    final isGoogle = provider == 'google.com';
    final isApple = provider == 'apple.com';
    final providerName = isGoogle ? 'Google' : isApple ? 'Apple' : provider;
    final providerColor = isGoogle ? const Color(0xFF4285F4) : Colors.white70;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Candy.surfaceLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Candy.surface.withOpacity(0.6), width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: providerColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: isGoogle
                  ? Text('G', style: TextStyle(color: providerColor, fontSize: 18, fontWeight: FontWeight.w900))
                  : Icon(Icons.apple_rounded, color: providerColor, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('מחובר עם $providerName', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                if (email != null)
                  Text(email, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: providerColor.withOpacity(0.7), fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onSignOut,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('החלף', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
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
        color: Candy.surfaceLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Candy.surface.withOpacity(0.6), width: 0.8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Candy.gold, size: 22),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900), textDirection: TextDirection.ltr),
          Text(label, style: const TextStyle(color: Candy.inkMuted, fontSize: 10, fontWeight: FontWeight.w600)),
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
        backgroundColor: Candy.surfaceLow,
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
                      color: Candy.gold.withOpacity(0.7), width: 1.5),
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
                        color: Candy.gold,
                        fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}
