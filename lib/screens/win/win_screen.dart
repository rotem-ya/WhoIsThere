import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/game_constants.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../providers/providers.dart';
import '../../models/game_image_model.dart';
import '../../models/player_model.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/player_avatar.dart';

class WinScreen extends ConsumerStatefulWidget {
  final String roomId;

  const WinScreen({super.key, required this.roomId});

  @override
  ConsumerState<WinScreen> createState() => _WinScreenState();
}

class _WinScreenState extends ConsumerState<WinScreen> {
  late ConfettiController _confettiController;
  GameImageModel? _gameImage;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 5));
    _confettiController.play();
    _loadImage();
    _awardPoints();
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
    _confettiController.dispose();
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

        return Stack(
          children: [
            AppScaffold(
              backgroundGradient: isWinner
                  ? AppColors.primaryGradient
                  : AppColors.pageBackground,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      isWinner ? 'ניצחת!' : 'המשחק נגמר',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.titleLight.copyWith(fontSize: 34),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      winner == null
                          ? 'הנה התוצאות'
                          : isWinner
                              ? 'זיהית את המקום לפני כולם'
                              : '${winner.name.isNotEmpty ? winner.name : 'שחקן'} ניצח/ה בסיבוב',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.subtitleLight,
                    ),
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
                    AppCard(
                      child: Column(
                        children: [
                          Text('תוצאות', style: AppTextStyles.titleDark),
                          const SizedBox(height: AppSpacing.md),
                          ...sortedPlayers.asMap().entries.map(
                                (entry) => _ScoreRow(
                                  rank: entry.key + 1,
                                  player: entry.value,
                                  isWinner: entry.value.id == room.winnerId,
                                  isCurrentUser:
                                      entry.value.id == currentUser?.id,
                                ),
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'חזור לבית',
                      icon: Icons.home_rounded,
                      onPressed: () {
                        ref.read(currentRoomIdProvider.notifier).state = null;
                        context.go('/home');
                      },
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 30,
                colors: const [
                  AppColors.primary,
                  AppColors.secondary,
                  AppColors.accent,
                  AppColors.warning,
                ],
              ),
            ),
          ],
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('שגיאה: $e'))),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final int rank;
  final PlayerModel player;
  final bool isWinner;
  final bool isCurrentUser;

  const _ScoreRow({
    required this.rank,
    required this.player,
    required this.isWinner,
    required this.isCurrentUser,
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
                color: isWinner ? AppColors.primary : AppColors.darkBlue,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            '${player.score} נק׳',
            style: AppTextStyles.body.copyWith(
              color: isWinner ? AppColors.primary : AppColors.darkBlue,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
