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
    final room = ref.read(currentRoomProvider).value;
    if (room?.selectedImageId == null) return;
    final img =
        await ref.read(roomServiceProvider).getImage(room!.selectedImageId!);
    if (mounted) setState(() => _gameImage = img);
  }

  Future<void> _awardPoints() async {
    final room = ref.read(currentRoomProvider).value;
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
    final roomAsync = ref.watch(currentRoomProvider);
    final currentUser = ref.watch(currentUserProvider).value;

    return roomAsync.when(
      data: (room) {
        if (room == null) return const SizedBox();

        final winner = room.winnerId != null ? room.players[room.winnerId] : null;
        final isWinner = currentUser?.id == room.winnerId;
        final sortedPlayers = room.sortedPlayers;

        return Scaffold(
          body: Stack(
            children: [
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

              Container(
                decoration: BoxDecoration(
                  gradient: isWinner
                      ? AppColors.primaryGradient
                      : const LinearGradient(
                          colors: [Color(0xFF2D3561), Color(0xFF1A1F3A)]),
                ),
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                        Text(
                          isWinner ? '🏆 ניצחת!' : '🎉 המשחק נגמר!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                          ),
                        ).animate().scale(curve: Curves.elasticOut),

                        const SizedBox(height: 8),

                        if (winner != null)
                          Text(
                            isWinner
                                ? 'מדהים! זיהית אותו!'
                                : '${winner.name} צדק/ה!',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ).animate(delay: 200.ms).fadeIn(),

                        const SizedBox(height: 24),

                        if (_gameImage != null) ...[
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: CachedNetworkImage(
                                imageUrl: _gameImage!.imageUrl,
                                height: 220,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                              .animate(delay: 400.ms)
                              .fadeIn()
                              .scale(curve: Curves.elasticOut),
                          const SizedBox(height: 12),
                          Text(
                            _gameImage!.answer,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ).animate(delay: 600.ms).fadeIn(),
                          Text(
                            _gameImage!.category.label,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ).animate(delay: 700.ms).fadeIn(),
                        ],

                        const SizedBox(height: 28),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'ניקוד סופי',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ...sortedPlayers
                                  .asMap()
                                  .entries
                                  .map((entry) => _ScoreRow(
                                        rank: entry.key + 1,
                                        player: entry.value,
                                        isWinner: entry.value.id ==
                                            room.winnerId,
                                        isCurrentUser: entry.value.id ==
                                            currentUser?.id,
                                      ))
                                  .toList(),
                            ],
                          ),
                        ).animate(delay: 800.ms).fadeIn().slideY(begin: 0.3),

                        const SizedBox(height: 24),

                        GradientButton(
                          text: 'חזור לבית',
                          icon: Icons.home_rounded,
                          gradient: isWinner
                              ? AppColors.accentGradient
                              : AppColors.primaryGradient,
                          onPressed: () {
                            ref.read(currentRoomIdProvider.notifier).state =
                                null;
                            context.go('/home');
                          },
                        ).animate(delay: 900.ms).fadeIn(),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
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
          if (isWinner)
            const Text('👑 ', style: TextStyle(fontSize: 14)),
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
