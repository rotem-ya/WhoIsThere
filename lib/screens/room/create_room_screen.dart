import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/providers.dart';
import '../../widgets/common/gradient_button.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  bool _isLoading = false;
  String? _roomCode;
  String? _roomId;
  int _playerCount = 2;

  Future<void> _createRoom() async {
    setState(() => _isLoading = true);
    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) return;

      final room = await ref.read(roomServiceProvider).createRoom(
            hostId: user.id,
            hostName: user.name,
            hostPhotoUrl: user.photoUrl,
            playerCount: _playerCount,
          );

      ref.read(currentRoomIdProvider.notifier).state = room.id;
      setState(() {
        _roomCode = room.code;
        _roomId = room.id;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('יצירת החדר נכשלה: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('צור חדר'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_roomId != null) {
              final userId = ref.read(currentUserProvider).value?.id;
              if (userId != null) {
                ref.read(roomServiceProvider).leaveRoom(_roomId!, userId);
              }
            }
            context.pop();
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: _isLoading
                      ? const CircularProgressIndicator(color: AppColors.primary)
                      : _roomCode != null
                          ? _RoomCreatedCard(
                              roomCode: _roomCode!,
                              playerCount: _playerCount,
                            ).animate().scale(curve: Curves.elasticOut)
                          : _PlayerCountPicker(
                              selected: _playerCount,
                              onChanged: (v) => setState(() => _playerCount = v),
                            ).animate().fadeIn(),
                ),
              ),
              if (_roomCode != null) ...[
                const SizedBox(height: 12),
                GradientButton(
                  text: 'עבור ללובי',
                  icon: Icons.meeting_room_rounded,
                  onPressed: () => context.go('/lobby/$_roomId'),
                ),
                const SizedBox(height: 8),
              ] else ...[
                const SizedBox(height: 12),
                GradientButton(
                  text: 'צור חדר',
                  icon: Icons.add_rounded,
                  onPressed: _createRoom,
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerCountPicker extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _PlayerCountPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('👥', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            'כמה שחקנים?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.darkBlue,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'השחקנים הנוספים יצטרפו בהמשך',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          // LTR direction so numbers read 2→5 left to right
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [2, 3, 4, 5].map((count) {
                final isSelected = selected == count;
                return GestureDetector(
                    onTap: () => onChanged(count),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: isSelected ? AppColors.primaryGradient : null,
                        color: isSelected ? null : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color:
                                isSelected ? Colors.white : AppColors.darkBlue,
                          ),
                        ),
                      ),
                    ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomCreatedCard extends StatelessWidget {
  final String roomCode;
  final int playerCount;

  const _RoomCreatedCard({required this.roomCode, required this.playerCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            'החדר נוצר!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.darkBlue,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$playerCount שחקנים • שתף את הקוד עם החברים',
            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: roomCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('הקוד הועתק!')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        roomCode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.copy_rounded, color: Colors.white70, size: 20),
                ],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.02, 1.02),
                duration: 1200.ms,
              ),
          const SizedBox(height: 10),
          const Text(
            'לחץ להעתקה',
            style: TextStyle(
                color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
