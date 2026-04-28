import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/providers.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/premium_scaffold.dart';

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
    return PremiumScaffold(
      showBeams: true,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Column(
        children: [
          PremiumHeader(
            eyebrow: 'חדר חדש',
            title: _roomCode == null ? 'בונים במה למשחק' : 'החדר מוכן',
            subtitle: _roomCode == null
                ? 'בחרו כמות שחקנים, אני אכין קוד ואת הבוטים'
                : 'שתפו את הקוד ועברו ללובי',
            icon: Icons.add_home_work_rounded,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
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
          const SizedBox(height: 18),
          Expanded(
            child: Center(
              child: _isLoading
                  ? const CircularProgressIndicator(color: AppColors.accent)
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
          const SizedBox(height: 14),
          GradientButton(
            text: _roomCode != null ? 'כניסה ללובי' : 'צור חדר',
            icon: _roomCode != null
                ? Icons.meeting_room_rounded
                : Icons.add_rounded,
            onPressed: _roomCode != null
                ? () => context.go('/lobby/$_roomId')
                : _createRoom,
          ),
        ],
      ),
    );
  }
}

class _PlayerCountPicker extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _PlayerCountPicker({required this.selected, required this.onChanged});

  static const _descriptions = {
    2: 'דו־קרב קצר, חד ומהיר.',
    3: 'שלישייה עם מספיק כאוס.',
    4: 'הפורמט הקלאסי למסיבה.',
    5: 'הרבה רעש, הרבה צחוקים.',
  };

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PremiumPuzzlePreview(size: 94),
          const SizedBox(height: 16),
          const Text(
            'כמה משתתפים?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'הכמות קובעת כמה מקומות יהיו סביב השולחן',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.68),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              for (final count in [2, 3, 4, 5]) ...[
                Expanded(
                  child: _CountChip(
                    count: count,
                    isSelected: selected == count,
                    onTap: () => onChanged(count),
                  ),
                ),
                if (count != 5) const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: StatusPill(
              key: ValueKey(selected),
              icon: Icons.auto_awesome_rounded,
              text: _descriptions[selected] ?? '',
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _CountChip({
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 66,
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: isSelected ? null : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.18),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomCreatedCard extends StatefulWidget {
  final String roomCode;
  final int playerCount;

  const _RoomCreatedCard({required this.roomCode, required this.playerCount});

  @override
  State<_RoomCreatedCard> createState() => _RoomCreatedCardState();
}

class _RoomCreatedCardState extends State<_RoomCreatedCard> {
  bool _copied = false;

  void _copyCode() async {
    if (_copied) return;
    await Clipboard.setData(ClipboardData(text: widget.roomCode));
    setState(() => _copied = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            'החדר נוצר!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.playerCount} שחקנים • שתף את הקוד עם החברים',
            style: TextStyle(
              color: Colors.white.withOpacity(0.68),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _copyCode,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: _copied
                    ? AppColors.accentGradient
                    : AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (_copied ? AppColors.accent : AppColors.primary)
                        .withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _copied
                        ? const Icon(Icons.check_rounded,
                            key: ValueKey('check'),
                            color: Colors.white,
                            size: 22)
                        : const Icon(Icons.copy_rounded,
                            key: ValueKey('copy'),
                            color: Colors.white70,
                            size: 20),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          _copied ? 'הועתק!' : widget.roomCode,
                          key: ValueKey(_copied),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 6,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          AnimatedOpacity(
            opacity: _copied ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: const Text(
              'לחץ להעתקה',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
