import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/game_constants.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../providers/providers.dart';
import '../../models/player_model.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_feedback.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/player_avatar.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  final String roomId;

  const LobbyScreen({super.key, required this.roomId});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  bool _isStarting = false;
  bool _codeCopied = false;

  Future<void> _copyCode(String code) async {
    if (_codeCopied) return;
    AppFeedback.success();
    await Clipboard.setData(ClipboardData(text: code));
    setState(() => _codeCopied = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _codeCopied = false);
  }

  Future<void> _startGame() async {
    if (_isStarting) return;
    AppFeedback.success();
    setState(() => _isStarting = true);
    try {
      await ref.read(roomServiceProvider).startVotingImage(widget.roomId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('שגיאה בהתחלת משחק: $e')),
        );
        setState(() => _isStarting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));
    final currentUser = ref.watch(currentUserProvider).value;

    return roomAsync.when(
      data: (room) {
        if (room == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/home');
          });
          return const SizedBox();
        }

        if (room.phase == GamePhase.votingImage) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/vote-image/${widget.roomId}');
          });
        }

        final isHost = currentUser?.id == room.hostId;
        final canStart = room.players.length >= GameConstants.minPlayers;

        return AppScaffold(
          backgroundGradient: AppColors.pageBackground,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              AppHeader(
                title: 'לובי',
                trailing: IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  onPressed: () async {
                    if (currentUser != null) {
                      await ref
                          .read(roomServiceProvider)
                          .leaveRoom(widget.roomId, currentUser.id);
                    }
                    if (context.mounted) context.go('/home');
                  },
                ),
              ),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: InkWell(
                  onTap: () => _copyCode(room.code),
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    children: [
                      Text(_codeCopied ? 'הקוד הועתק' : 'קוד חדר',
                          style: AppTextStyles.subtitleDark),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        room.code,
                        textDirection: TextDirection.ltr,
                        style: AppTextStyles.titleDark.copyWith(
                          fontSize: 36,
                          letterSpacing: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'שחקנים (${room.players.length}/${GameConstants.maxPlayers})',
                  style: AppTextStyles.subtitleLight,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: GridView.builder(
                  itemCount: room.players.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 3.2,
                  ),
                  itemBuilder: (context, index) {
                    final player = room.players.values.elementAt(index);
                    return _PlayerTile(
                      player: player,
                      isCurrentUser: player.id == currentUser?.id,
                    );
                  },
                ),
              ),
              if (isHost)
                AppButton(
                  label: _isStarting
                      ? 'מתחיל...'
                      : canStart
                          ? 'התחל משחק'
                          : 'ממתין לשחקנים',
                  icon: Icons.play_arrow_rounded,
                  onPressed: canStart && !_isStarting ? _startGame : null,
                )
              else
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'ממתין למארח להתחיל...',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body,
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

class _PlayerTile extends StatelessWidget {
  final PlayerModel player;
  final bool isCurrentUser;

  const _PlayerTile({required this.player, required this.isCurrentUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isCurrentUser ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          PlayerAvatar(
              name: player.name, photoUrl: player.photoUrl, radius: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              player.name + (player.isBot ? ' 🎮' : ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                color: isCurrentUser ? Colors.white : AppColors.darkBlue,
              ),
            ),
          ),
          if (player.isHost) const Text('👑'),
        ],
      ),
    );
  }
}
