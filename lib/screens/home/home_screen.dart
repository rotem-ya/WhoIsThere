import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../providers/providers.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_feedback.dart';
import '../../widgets/common/player_avatar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isCreating = false;

  Future<void> _createAndJoin() async {
    if (_isCreating) return;
    setState(() => _isCreating = true);
    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) return;
      final room = await ref.read(roomServiceProvider).createRoom(
            hostId: user.id,
            hostName: user.name,
            hostPhotoUrl: user.photoUrl,
          );
      ref.read(currentRoomIdProvider.notifier).state = room.id;
      if (mounted) context.push('/lobby/${room.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('יצירת המשחק נכשלה: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('לצאת מהאפליקציה?'),
            content: const Text('האם אתה בטוח שברצונך לצאת?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ביטול'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('יציאה'),
              ),
            ],
          ),
        );
        if (shouldExit == true && context.mounted) {
          Navigator.of(context).maybePop();
        }
      },
      child: AppScaffold(
        backgroundGradient: AppColors.pageBackground,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    userAsync.when(
                      data: (user) => _HomeTopBar(
                        name: user?.name ?? 'שחקן',
                        photoUrl: user?.photoUrl,
                        points: user?.totalPoints ?? 0,
                        onProfile: () => context.push('/profile'),
                      ),
                      loading: () => const SizedBox(height: 52),
                      error: (_, __) => const SizedBox(height: 52),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const _HomeHero(),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: _isCreating ? 'יוצר משחק...' : 'צור משחק',
                      icon: Icons.add_rounded,
                      onPressed: _isCreating ? null : _createAndJoin,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SecondaryAction(
                      label: 'הצטרף למשחק',
                      icon: Icons.login_rounded,
                      onPressed: () => context.push('/join-room'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniAction(
                            label: 'חנות',
                            icon: Icons.store_rounded,
                            onPressed: () => context.push('/store'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _MiniAction(
                            label: 'פרופיל',
                            icon: Icons.person_rounded,
                            onPressed: () => context.push('/profile'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HomeTopBar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final int points;
  final VoidCallback onProfile;

  const _HomeTopBar({
    required this.name,
    required this.photoUrl,
    required this.points,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'שלום, ${name.split(' ').first}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.titleLight,
              ),
              Text(
                'מוכן לחשוף מקום חדש?',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.subtitleLight,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text('⭐ $points',
              style: AppTextStyles.body.copyWith(color: Colors.white)),
        ),
        const SizedBox(width: AppSpacing.sm),
        GestureDetector(
          onTap: () {
            AppFeedback.selection();
            onProfile();
          },
          child: PlayerAvatar(name: name, photoUrl: photoUrl, radius: 22),
        ),
      ],
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Container(
            width: 168,
            height: 168,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(40),
            ),
            child:
                const Center(child: Text('🧩', style: TextStyle(fontSize: 76))),
          ),
          const SizedBox(height: AppSpacing.lg),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text('Guess the Place', style: AppTextStyles.titleDark),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'פתח חדר, חשוף חלקים, ונחש את המקום לפני כולם.',
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitleDark,
          ),
        ],
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _SecondaryAction(
      {required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withOpacity(0.28)),
        textStyle: AppTextStyles.button,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _MiniAction(
      {required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white70),
      label: Text(label, style: AppTextStyles.subtitleLight),
    );
  }
}
