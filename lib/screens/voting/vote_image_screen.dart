import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/game_constants.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../providers/providers.dart';
import '../../models/room_model.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_header.dart';

class VoteImageScreen extends ConsumerStatefulWidget {
  final String roomId;

  const VoteImageScreen({super.key, required this.roomId});

  @override
  ConsumerState<VoteImageScreen> createState() => _VoteImageScreenState();
}

class _VoteImageScreenState extends ConsumerState<VoteImageScreen> {
  String? _selectedCategory;
  bool _hasVoted = false;

  Future<void> _confirmVote(RoomModel room) async {
    if (_selectedCategory == null || _hasVoted) return;
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    setState(() => _hasVoted = true);

    try {
      await ref.read(roomServiceProvider).castImageVote(
            roomId: widget.roomId,
            userId: user.id,
            categoryName: _selectedCategory!,
          );

      final virtualPlayers = room.players.values.where((p) => p.isBot);
      for (final player in virtualPlayers) {
        await ref.read(roomServiceProvider).castImageVote(
              roomId: widget.roomId,
              userId: player.id,
              categoryName: _selectedCategory!,
            );
      }

      if (mounted) {
        await ref
            .read(roomServiceProvider)
            .resolveImageVote(widget.roomId, user.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hasVoted = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('שגיאה בהצבעה: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));

    return roomAsync.when(
      data: (room) {
        if (room == null) return const SizedBox();

        if (room.phase == GamePhase.votingDifficulty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/vote-difficulty/${widget.roomId}');
          });
        }

        final currentUser = ref.read(currentUserProvider).value;
        if (currentUser == null) return const SizedBox();
        final isHost = currentUser.id == room.hostId;
        final myVote = room.imageVotes[currentUser.id];

        const categories = [
          ImageCategory.israeliLandmark,
          ImageCategory.landmark,
        ];

        return AppScaffold(
          backgroundGradient: AppColors.pageBackground,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              AppHeader(
                title: 'בחירת עולם',
                leading: IconButton(
                  icon: const Icon(Icons.exit_to_app_rounded,
                      color: Colors.white),
                  onPressed: () async {
                    await ref
                        .read(roomServiceProvider)
                        .leaveRoom(widget.roomId, currentUser.id);
                    if (context.mounted) context.go('/home');
                  },
                ),
              ),
              Text(
                isHost
                    ? 'הצבעת המארח שווה פי 2'
                    : 'בחרו איזו תמונה תופיע בפאזל',
                textAlign: TextAlign.center,
                style: AppTextStyles.subtitleLight,
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: Column(
                  children: categories.map((category) {
                    final selected = _selectedCategory == category.name;
                    final votes = room.imageVotes.values
                        .where((v) => v == category.name)
                        .length;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _CategoryCard(
                          category: category,
                          selected: selected,
                          votes: votes,
                          locked: myVote != null,
                          onTap: myVote == null
                              ? () => setState(
                                  () => _selectedCategory = category.name)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (myVote == null)
                AppButton(
                  label:
                      _selectedCategory == null ? 'בחר קטגוריה' : 'אשר בחירה',
                  icon: Icons.how_to_vote_rounded,
                  onPressed: _selectedCategory != null && !_hasVoted
                      ? () => _confirmVote(room)
                      : null,
                )
              else
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'הצבעה נשלחה. עוברים לשלב הבא...',
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

class _CategoryCard extends StatelessWidget {
  final ImageCategory category;
  final bool selected;
  final int votes;
  final bool locked;
  final VoidCallback? onTap;

  const _CategoryCard({
    required this.category,
    required this.selected,
    required this.votes,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(selected ? 0.24 : 0.14),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(category.emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: AppSpacing.md),
            Text(
              category.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: (selected
                  ? AppTextStyles.titleLight
                  : AppTextStyles.titleDark),
            ),
            if (votes > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '$votes הצבעות',
                style: selected
                    ? AppTextStyles.subtitleLight
                    : AppTextStyles.subtitleDark,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
