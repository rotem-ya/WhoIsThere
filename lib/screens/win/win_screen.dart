import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../providers/providers.dart';
import '../../models/game_image_model.dart';
import '../../models/player_model.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/player_avatar.dart';

class WinScreen extends ConsumerStatefulWidget {
  final String roomId;

  const WinScreen({super.key, required this.roomId});

  @override
  ConsumerState<WinScreen> createState() => _WinScreenState();
}

class _WinScreenState extends ConsumerState<WinScreen>
    with TickerProviderStateMixin {
  late final AnimationController _counterController;
  late final AnimationController _shineController;
  GameImageModel? _gameImage;

  @override
  void initState() {
    super.initState();
    _counterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _loadImage();
    _awardPoints();
    // Counter + shine fire once after entrance stagger settles.
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _counterController.forward();
        _shineController.forward();
      }
    });
  }

  Future<void> _loadImage() async {
    final room = await ref.read(roomStreamProvider(widget.roomId).future);
    if (room?.selectedImageId == null) return;
    final img =
        await ref.read(roomServiceProvider).getImage(room!.selectedImageId!);
    if (mounted) setState(() => _gameImage = img);
  }

  Future<void> _awardPoints() async {
    final room = await ref.read(roomStreamProvider(widget.roomId).future);
    final currentUser = ref.read(currentUserProvider).value;
    if (room == null || currentUser == null) return;
    final myPlayer = room.players[currentUser.id];
    if (myPlayer != null) {
      await ref
          .read(authServiceProvider)
          .updateTotalPoints(currentUser.id, myPlayer.score);
    }
  }

  @override
  void dispose() {
    _counterController.dispose();
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));
    final currentUser = ref.watch(currentUserProvider).value;

    return roomAsync.when(
      data: (room) {
        if (room == null) return const SizedBox();

        final winner =
            room.winnerId != null ? room.players[room.winnerId] : null;
        final isWinner = currentUser?.id == room.winnerId;
        final sortedPlayers = room.sortedPlayers;
        final myScore =
            (currentUser != null ? room.players[currentUser.id] : null)
                    ?.score ??
                0;

        return AppScaffold(
          backgroundGradient:
              isWinner ? AppColors.primaryGradient : AppColors.pageBackground,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.md),

                // ── 1. Title entrance: fade + scale 0.96 → 1.0 ────────
                Text(
                  isWinner ? 'ניצחון!' : 'המשחק נגמר',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleLight.copyWith(fontSize: 34),
                )
                    .animate()
                    .fadeIn(duration: 280.ms, curve: Curves.easeOut)
                    .scaleXY(
                        begin: 0.96,
                        end: 1.0,
                        duration: 280.ms,
                        curve: Curves.easeOut),

                const SizedBox(height: AppSpacing.sm),

                // ── 2. Winner text fades in after title ────────────────
                Text(
                  winner == null
                      ? 'הנה התוצאות'
                      : isWinner
                          ? 'זיהית את המקום לפני כולם'
                          : '${winner.name.isNotEmpty ? winner.name : 'שחקן'} ניצח/ה בסיבוב',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitleLight,
                )
                    .animate()
                    .fadeIn(
                        delay: 160.ms,
                        duration: 260.ms,
                        curve: Curves.easeOut),

                const SizedBox(height: AppSpacing.lg),

                if (_gameImage != null)
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24)),
                          child: CachedNetworkImage(
                            imageUrl: _gameImage!.imageUrl,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            children: [
                              Text(
                                _gameImage!.answer,
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.titleDark,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                _gameImage!.category.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.subtitleDark,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: AppSpacing.lg),

                // ── 3. Score card with staggered rows ─────────────────
                AppCard(
                  child: Column(
                    children: [
                      Text('תוצאות', style: AppTextStyles.titleDark)
                          .animate()
                          .fadeIn(
                              delay: 240.ms,
                              duration: 260.ms,
                              curve: Curves.easeOut),
                      const SizedBox(height: AppSpacing.md),
                      ...sortedPlayers.asMap().entries.map(
                            (entry) => _ScoreRow(
                              rank: entry.key + 1,
                              player: entry.value,
                              isWinner: entry.value.id == room.winnerId,
                              isCurrentUser:
                                  entry.value.id == currentUser?.id,
                              delay: Duration(
                                  milliseconds: 320 + entry.key * 60),
                            ),
                          ),
                    ],
                  ),
                ),

                // ── 4. Total reward box (current user's score) ─────────
                if (myScore > 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  _TotalRewardBox(
                    score: myScore,
                    counterController: _counterController,
                    shineController: _shineController,
                  ),
                ],

                const SizedBox(height: AppSpacing.lg),

                // ── 6. Tactile home button ─────────────────────────────
                _HomeButton(
                  onTap: () {
                    ref.read(currentRoomIdProvider.notifier).state = null;
                    context.go('/home');
                  },
                ),
              ],
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('שגיאה: $e'))),
    );
  }
}

// ── Score row — stagger fade + moveY, coin icon scale pulse ───────────────

class _ScoreRow extends StatelessWidget {
  final int rank;
  final PlayerModel player;
  final bool isWinner;
  final bool isCurrentUser;
  final Duration delay;

  const _ScoreRow({
    required this.rank,
    required this.player,
    required this.isWinner,
    required this.isCurrentUser,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final medal = rank == 1
        ? '🥇'
        : rank == 2
            ? '🥈'
            : rank == 3
                ? '🥉'
                : '$rank.';
    final scoreColor =
        isWinner ? AppColors.primary : AppColors.darkBlue;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(medal, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: AppSpacing.sm),
          PlayerAvatar(
              name: player.name, photoUrl: player.photoUrl, radius: 16),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              player.name + (isCurrentUser ? ' (את/ה)' : ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                color: scoreColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          // ── 5. Coin icon: scale pulse once on row entrance ──────────
          const Icon(Icons.monetization_on_rounded,
                  color: AppColors.primary, size: 16)
              .animate(delay: delay + const Duration(milliseconds: 50))
              .scaleXY(
                  begin: 0.5,
                  end: 1.0,
                  duration: 240.ms,
                  curve: Curves.easeOut),
          const SizedBox(width: 4),
          Text(
            '${player.score}',
            style: AppTextStyles.body.copyWith(
              color: scoreColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: delay, duration: 280.ms, curve: Curves.easeOut)
        .moveY(
            begin: 8,
            end: 0,
            delay: delay,
            duration: 280.ms,
            curve: Curves.easeOut);
  }
}

// ── Total reward box: counter 0 → score, one-shot gold shine sweep ─────────

class _TotalRewardBox extends StatelessWidget {
  final int score;
  final AnimationController counterController;
  final AnimationController shineController;

  const _TotalRewardBox({
    required this.score,
    required this.counterController,
    required this.shineController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF12100A),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.primary.withOpacity(0.36), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // One-shot gold shine sweep (no loop)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: AnimatedBuilder(
                animation: shineController,
                builder: (context, _) {
                  return Align(
                    alignment:
                        Alignment(-1.8 + shineController.value * 4.0, 0),
                    child: FractionallySizedBox(
                      widthFactor: 0.32,
                      heightFactor: 1.4,
                      child: Transform.rotate(
                        angle: -0.28,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0),
                                Colors.white.withOpacity(0.11),
                                Colors.white.withOpacity(0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Content row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'נקודות בסיבוב:',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.primary.withOpacity(0.78),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: counterController,
                builder: (context, _) {
                  final t = Curves.easeOut.transform(counterController.value);
                  final displayed = (t * score).round();
                  return Text(
                    '+$displayed',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 520.ms, duration: 300.ms, curve: Curves.easeOut)
        .moveY(
            begin: 8,
            end: 0,
            delay: 520.ms,
            duration: 300.ms,
            curve: Curves.easeOut);
  }
}

// ── Tactile "חזור לבית" button: 0.985 press, shadow compression, no bounce ─

class _HomeButton extends StatefulWidget {
  final VoidCallback onTap;

  const _HomeButton({required this.onTap});

  @override
  State<_HomeButton> createState() => _HomeButtonState();
}

class _HomeButtonState extends State<_HomeButton> {
  bool _pressed = false;

  void _onDown(_) => setState(() => _pressed = true);
  void _onUp(_) => setState(() => _pressed = false);
  void _onCancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onDown,
      onTapUp: (e) {
        _onUp(e);
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      onTapCancel: _onCancel,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: _pressed
            ? const Duration(milliseconds: 90)
            : const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: _pressed
              ? const Duration(milliseconds: 90)
              : const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF181208),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.primary.withOpacity(0.38), width: 1),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, -1),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.home_rounded, color: AppColors.primary, size: 22),
              SizedBox(width: 8),
              Text(
                'חזור לבית',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 680.ms, duration: 280.ms, curve: Curves.easeOut);
  }
}
