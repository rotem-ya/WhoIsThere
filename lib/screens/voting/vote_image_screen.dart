import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/game_constants.dart';
import '../../providers/providers.dart';
import '../../models/room_model.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/premium_scaffold.dart';

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

        const availableCategories = [
          ImageCategory.israeliLandmark,
          ImageCategory.landmark,
        ];

        return PremiumScaffold(
          showBeams: true,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PremiumScreenHeader(
                eyebrow: 'שלב 1 מתוך 2',
                title: 'איזה עולם נחשוף?',
                subtitle:
                    isHost ? 'הצבעת המארח שווה פי 2' : 'בחר קטגוריה לפאזל הבא',
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
              ).animate().fadeIn().slideY(begin: -0.12),
              const SizedBox(height: 18),
              Expanded(
                child: Column(
                  children: availableCategories.asMap().entries.map((entry) {
                    final i = entry.key;
                    final cat = entry.value;
                    final isSelected = _selectedCategory == cat.name;
                    final voteCount = room.imageVotes.values
                        .where((v) => v == cat.name)
                        .length;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: i == availableCategories.length - 1 ? 0 : 12,
                        ),
                        child: GestureDetector(
                          onTap: myVote == null
                              ? () =>
                                  setState(() => _selectedCategory = cat.name)
                              : null,
                          child: _CategoryCard(
                            category: cat,
                            isSelected: isSelected,
                            voteCount: voteCount,
                            isLocked: myVote != null,
                          ),
                        )
                            .animate(delay: (i * 90).ms)
                            .fadeIn(duration: 350.ms)
                            .slideX(begin: 0.16),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              if (myVote == null)
                GradientButton(
                  text: _selectedCategory != null
                      ? 'נעול על הבחירה'
                      : 'בחר קטגוריה',
                  icon: Icons.how_to_vote_rounded,
                  onPressed: _selectedCategory != null && !_hasVoted
                      ? () => _confirmVote(room)
                      : null,
                ).animate(delay: 200.ms).fadeIn()
              else
                const PremiumStatusPill(
                  icon: Icons.check_circle_rounded,
                  text: 'הצבעה נשלחה! מכינים את השלב הבא...',
                ).animate().fadeIn(),
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
  final bool isSelected;
  final int voteCount;
  final bool isLocked;

  const _CategoryCard({
    required this.category,
    required this.isSelected,
    required this.voteCount,
    required this.isLocked,
  });

  LinearGradient get _gradient {
    if (category == ImageCategory.israeliLandmark) {
      return const LinearGradient(
        colors: [Color(0xFF0057B7), Color(0xFF003580)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return AppColors.primaryGradient;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        gradient: isSelected ? _gradient : null,
        color: isSelected ? null : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSelected ? Colors.transparent : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? _gradient.colors.first.withOpacity(0.35)
                : Colors.black.withOpacity(0.06),
            blurRadius: isSelected ? 20 : 8,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Emoji container
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withOpacity(0.18)
                          : AppColors.primary.withOpacity(0.07),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        category.emoji,
                        style: const TextStyle(fontSize: 42),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    category.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : AppColors.darkBlue,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (voteCount > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.25)
                            : AppColors.secondary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '🗳️  $voteCount',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color:
                              isSelected ? Colors.white : AppColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isSelected)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
