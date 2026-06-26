import 'dart:async';

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
import '../../core/constants/game_constants.dart';
import '../../core/constants/economy_config.dart';
import '../../providers/providers.dart';
import '../../models/game_image_model.dart';
import '../../models/player_model.dart';
import '../../models/room_model.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/banner_ad_widget.dart';
import '../../widgets/common/player_avatar.dart';
import '../../widgets/common/win_effect_overlay.dart';

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
  // Friends games: coins gifted for placing 1st (20) / 2nd (5). null until resolved.
  int? _placementReward;
  // True while a "play again" tap is in flight (creating / joining the rematch).
  bool _busyRematch = false;

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
    if (myPlayer == null) return;
    if (room.isFriendsGame) {
      // Friends games are per-match: score is NOT added to lifetime points.
      // Instead, the top-2 finishers receive a coin gift (20 / 5).
      final reward = await ref
          .read(roomServiceProvider)
          .claimPlacementReward(widget.roomId, currentUser.id);
      if (mounted) setState(() => _placementReward = reward);
      // Record this match for the friends leaderboard + per-game history.
      // Each client records only its own result (idempotent per player/room).
      unawaited(ref
          .read(friendsServiceProvider)
          .recordMyResult(room: room, myUid: currentUser.id));
    } else {
      await ref
          .read(authServiceProvider)
          .updateTotalPoints(currentUser.id, myPlayer.score);
    }
  }

  // "Play again" (friends games): the first tapper creates a fresh room and the
  // others see the button flip to "join rematch" via the room stream. Either way
  // we land in the new lobby.
  Future<void> _onRematch(RoomModel room) async {
    if (_busyRematch) return;
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    setState(() => _busyRematch = true);
    try {
      final svc = ref.read(roomServiceProvider);
      var targetId = room.rematchRoomId;
      if (targetId == null || targetId.isEmpty) {
        targetId = await svc.createRematch(
          oldRoomId: widget.roomId,
          hostId: user.id,
          hostName: user.name,
          hostPhotoUrl: user.photoUrl,
        );
      } else {
        await svc.joinRematch(
          rematchRoomId: targetId,
          userId: user.id,
          userName: user.name,
          userPhotoUrl: user.photoUrl,
        );
      }
      if (targetId == null || targetId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('לא ניתן לפתוח משחק חוזר')),
          );
          setState(() => _busyRematch = false);
        }
        return;
      }
      ref.read(currentRoomIdProvider.notifier).state = targetId;
      if (mounted) context.go('/lobby/$targetId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('שגיאה במשחק חוזר: $e')),
        );
        setState(() => _busyRematch = false);
      }
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

        return PopScope(
          canPop: false,
          onPopInvoked: (didPop) {
            if (!didPop) {
              ref.read(currentRoomIdProvider.notifier).state = null;
              context.go('/home');
            }
          },
          child: AppScaffold(
          backgroundGradient:
              isWinner ? AppColors.primaryGradient : AppColors.pageBackground,
          padding: EdgeInsets.zero,
          safeArea: false,
          child: Stack(
            children: [
              SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.sm),

                  // ── 1. Title entrance: fade + scale 0.96 → 1.0 ────────
                  Text(
                    isWinner ? '🏆 ניצחון!' : 'המשחק נגמר',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleLight.copyWith(fontSize: 30),
                  )
                      .animate()
                      .fadeIn(duration: 280.ms, curve: Curves.easeOut)
                      .scaleXY(
                          begin: 0.96,
                          end: 1.0,
                          duration: 280.ms,
                          curve: Curves.easeOut),

                  const SizedBox(height: AppSpacing.xs),

                  // ── 2. Winner text fades in after title ────────────────
                  Text(
                    winner == null
                        ? 'הנה התוצאות'
                        : isWinner
                            ? 'זיהית את המקום לפני כולם'
                            : '${winner.name.isNotEmpty ? winner.name : 'שחקן'} ניצח/ה בסיבוב',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.subtitleLight,
                  )
                      .animate()
                      .fadeIn(
                          delay: 160.ms,
                          duration: 260.ms,
                          curve: Curves.easeOut),

                  const SizedBox(height: AppSpacing.sm),

                  // ── Image + answer card ────────────────────────────────
                  if (_gameImage != null)
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(24)),
                            child: _gameImage!.imageUrl.startsWith('assets/')
                                ? Image.asset(
                                    _gameImage!.imageUrl,
                                    height: 140,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  )
                                : CachedNetworkImage(
                                    imageUrl: _gameImage!.imageUrl,
                                    height: 140,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                            child: Column(
                              children: [
                                Text(
                                  _gameImage!.answer,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.titleDark,
                                ),
                                const SizedBox(height: 2),
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

                  const SizedBox(height: AppSpacing.sm),

                  // ── 3. Score card with staggered rows ─────────────────
                  Flexible(
                    child: AppCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('תוצאות', style: AppTextStyles.titleDark)
                              .animate()
                              .fadeIn(
                                  delay: 240.ms,
                                  duration: 260.ms,
                                  curve: Curves.easeOut),
                          const SizedBox(height: AppSpacing.sm),
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
                  ),

                  // ── 4. Total reward box (current user's score) ─────────
                  if (myScore > 0) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _TotalRewardBox(
                      score: myScore,
                      counterController: _counterController,
                      shineController: _shineController,
                    ),
                  ],

                  // ── Friends placement coin gift (1st = 20, 2nd = 5) ────
                  if (room.isFriendsGame && (_placementReward ?? 0) > 0) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _PlacementRewardBox(coins: _placementReward!),
                  ],

                  const SizedBox(height: AppSpacing.sm),

                  // ── Friends "play again": rematch the same group ───────
                  if (room.isFriendsGame) ...[
                    _RematchButton(
                      label: (room.rematchRoomId == null ||
                              room.rematchRoomId!.isEmpty)
                          ? '🔄 שחק שוב'
                          : '➡️ הצטרף למשחק חוזר',
                      busy: _busyRematch,
                      onTap: () => _onRematch(room),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],

                  // ── 6. Tactile home button ─────────────────────────────
                  _HomeButton(
                    onTap: () async {
                      // Interstitial "between games" — only fires if one is
                      // ready and the min-gap has elapsed; otherwise no-op.
                      await ref.read(adServiceProvider).maybeShowInterstitial();
                      if (!context.mounted) return;
                      ref.read(currentRoomIdProvider.notifier).state = null;
                      context.go('/home');
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const BannerAdWidget(),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),
              if (winner != null && winner.winEffectId != 'none')
                Positioned.fill(
                  child: WinEffectOverlay(effectId: winner.winEffectId),
                ),
            ],
          ),
        ), // AppScaffold
        ); // PopScope
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
              name: player.name,
              photoUrl: player.photoUrl,
              radius: 16,
              frameId: player.frameId,
              avatarId: player.avatarId),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                color: scoreColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          // Keep the "(את/ה)" marker outside the ellipsis so it's never clipped.
          if (isCurrentUser)
            Text(
              ' (את/ה)',
              style: AppTextStyles.body.copyWith(
                color: scoreColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          const Spacer(),
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

// ── Friends placement coin gift box (1st place = 20, 2nd place = 5) ────────

class _PlacementRewardBox extends StatelessWidget {
  final int coins;

  const _PlacementRewardBox({required this.coins});

  @override
  Widget build(BuildContext context) {
    // 1st place gets the larger gift; anything else shown here is 2nd place.
    final isFirst = coins >= EconomyConfig.friendsFirstPlaceReward;
    final label = isFirst ? '🥇 מקום ראשון' : '🥈 מקום שני';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1A12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF34D399).withOpacity(0.40), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF34D399).withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎁', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(
            '$label · פרס:',
            style: AppTextStyles.body.copyWith(
              color: const Color(0xFF34D399),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+$coins',
            style: const TextStyle(
              color: Color(0xFF34D399),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.monetization_on_rounded,
              color: Color(0xFFFFD54F), size: 20),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 560.ms, duration: 300.ms, curve: Curves.easeOut)
        .moveY(
            begin: 8,
            end: 0,
            delay: 560.ms,
            duration: 300.ms,
            curve: Curves.easeOut);
  }
}

// ── "שחק שוב" / "הצטרף למשחק חוזר": primary gold action above the home button ─

class _RematchButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onTap;

  const _RematchButton({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: busy ? null : onTap,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: const Color(0xFF12100A),
            disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.4),
          ),
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF12100A)),
                )
              : Text(label),
        ),
      )
          .animate()
          .fadeIn(delay: 640.ms, duration: 280.ms, curve: Curves.easeOut);
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
