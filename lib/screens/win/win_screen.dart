import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/game_constants.dart';
import '../../providers/providers.dart';
import '../../models/game_image_model.dart';
import '../../models/player_model.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/player_avatar.dart';
import '../../widgets/common/premium_scaffold.dart';

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
            PremiumScaffold(
              showBeams: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  children: [
                    PremiumScreenHeader(
                      eyebrow: isWinner ? 'VICTORY' : 'GAME OVER',
                      title: isWinner ? 'ניצחת בענק' : 'המשחק נגמר',
                      subtitle: winner == null
                          ? 'הנה התוצאות'
                          : isWinner
                              ? 'זיהית את המקום לפני כולם'
                              : '${winner.name} לקח/ה את הסיבוב',
                      icon: isWinner
                          ? Icons.emoji_events_rounded
                          : Icons.flag_rounded,
                    ).animate().fadeIn().slideY(begin: -0.08),
                    const SizedBox(height: 18),
                    if (_gameImage != null)
                      PremiumGlassCard(
                        padding: const EdgeInsets.all(12),
                        radius: 30,
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: CachedNetworkImage(
                                imageUrl: _gameImage!.imageUrl,
                                height: 220,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _gameImage!.answer,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              _gameImage!.category.label,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.62),
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ).animate(delay: 180.ms).fadeIn().scale(
                            begin: const Offset(0.96, 0.96),
                            curve: Curves.easeOutBack,
                          ),
                    const SizedBox(height: 18),
                    PremiumGlassCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          const Text(
                            'לוח תוצאות',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 14),
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
                    ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.12),
                    const SizedBox(height: 18),
                    GradientButton(
                      text: 'חזור לבית',
                      icon: Icons.home_rounded,
                      gradient: isWinner
                          ? AppColors.accentGradient
                          : AppColors.primaryGradient,
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            medal,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 12),
          PlayerAvatar(
            name: player.name,
            photoUrl: player.photoUrl,
            radius: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              player.name + (isCurrentUser ? ' (את/ה)' : ''),
              style: TextStyle(
                color: isCurrentUser ? AppColors.warning : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          if (isWinner) const Text('👑 ', style: TextStyle(fontSize: 14)),
          Text(
            '${player.score} נק׳',
            style: TextStyle(
              color: isWinner ? AppColors.warning : Colors.white70,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
