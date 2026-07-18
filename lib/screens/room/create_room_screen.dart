import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/candy_theme.dart';
import '../../core/constants/economy_config.dart';
import '../../core/theme/app_styles.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../providers/providers.dart';
import '../../services/qa_logger_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_feedback.dart';
import '../../widgets/common/app_header.dart';

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
  int _entryFee = 0;

  @override
  void initState() {
    super.initState();
    QaLoggerService.instance.log('ROOM', 'CREATE_ROOM_SCREEN_OPENED');
  }

  Future<void> _createRoom() async {
    QaLoggerService.instance.log('ROOM', 'CREATE_ROOM_ATTEMPT players=$_playerCount');
    AppFeedback.confirm();
    setState(() => _isLoading = true);
    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) return;

      final room = await ref.read(roomServiceProvider).createRoom(
            hostId: user.id,
            hostName: user.name,
            hostPhotoUrl: user.photoUrl,
            playerCount: _playerCount,
            entryFee: _entryFee,
          );

      final shortId = room.id.substring(0, room.id.length.clamp(0, 6));
      QaLoggerService.instance.log('ROOM', 'CREATE_ROOM_SUCCESS code=${room.code} id=$shortId');
      ref.read(currentRoomIdProvider.notifier).state = room.id;
      setState(() {
        _roomCode = room.code;
        _roomId = room.id;
      });
    } catch (e) {
      final msg = e.toString();
      QaLoggerService.instance.log(
          'ROOM', 'CREATE_ROOM_ERROR ${msg.length > 80 ? msg.substring(0, 80) : msg}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('יצירת החדר נכשלה: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _leaveDraftAndPop() {
    HapticFeedback.lightImpact();
    if (_roomId != null) {
      final userId = ref.read(currentUserProvider).value?.id;
      if (userId != null) {
        ref.read(roomServiceProvider).leaveRoom(_roomId!, userId);
      }
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundGradient: AppStyles.backgroundGradient,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          AppHeader(
            title: _roomCode == null ? 'חדר חדש' : 'החדר מוכן',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: _leaveDraftAndPop,
            ),
          ),
          Expanded(
            child: Center(
              child: _isLoading
                  ? const CircularProgressIndicator(color: Candy.teal)
                  : _roomCode == null
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PlayerCountCard(
                              selected: _playerCount,
                              onChanged: (value) =>
                                  setState(() => _playerCount = value),
                            ),
                            const SizedBox(height: 12),
                            _EntryFeeCard(
                              selected: _entryFee,
                              playerCount: _playerCount,
                              onChanged: (value) =>
                                  setState(() => _entryFee = value),
                            ),
                          ],
                        )
                      : _RoomCodeCard(
                          roomCode: _roomCode!,
                          playerCount: _playerCount,
                        ),
            ),
          ),
          AppButton(
            label: _roomCode == null ? 'צור חדר' : 'כניסה ללובי',
            icon: _roomCode == null
                ? Icons.add_rounded
                : Icons.meeting_room_rounded,
            onPressed: _isLoading
                ? null
                : _roomCode == null
                    ? _createRoom
                    : () => context.go('/lobby/$_roomId'),
          ),
        ],
      ),
    );
  }
}

class _PlayerCountCard extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _PlayerCountCard({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('כמה שחקנים?', style: AppTextStyles.titleDark),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'בחרו כמה משתתפים יהיו סביב הלוח.',
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitleDark,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              for (final count in [2, 3, 4, 5]) ...[
                Expanded(
                  child: _CountButton(
                    count: count,
                    selected: selected == count,
                    onTap: () => onChanged(count),
                  ),
                ),
                if (count != 5) const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CountButton extends StatelessWidget {
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _CountButton(
      {required this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        AppFeedback.tap();
        onTap();
      },
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 62,
        decoration: BoxDecoration(
          color: selected
              ? Candy.gold
              : Candy.gold.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Text(
            '$count',
            style: AppTextStyles.titleDark.copyWith(
              color: selected ? Colors.white : Candy.gold,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomCodeCard extends StatefulWidget {
  final String roomCode;
  final int playerCount;

  const _RoomCodeCard({required this.roomCode, required this.playerCount});

  @override
  State<_RoomCodeCard> createState() => _RoomCodeCardState();
}

class _RoomCodeCardState extends State<_RoomCodeCard> {
  bool _copied = false;

  Future<void> _copyCode() async {
    if (_copied) return;
    AppFeedback.success();
    await Clipboard.setData(ClipboardData(text: widget.roomCode));
    setState(() => _copied = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('שתפו את הקוד', style: AppTextStyles.titleDark),
          const SizedBox(height: AppSpacing.sm),
          Text('${widget.playerCount} שחקנים בחדר',
              style: AppTextStyles.subtitleDark),
          const SizedBox(height: AppSpacing.lg),
          InkWell(
            onTap: _copyCode,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              decoration: BoxDecoration(
                color: Candy.gold,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Text(
                  _copied ? 'הועתק' : widget.roomCode,
                  textDirection: TextDirection.ltr,
                  style: AppTextStyles.titleLight.copyWith(
                    fontSize: 34,
                    letterSpacing: _copied ? 0 : 7,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'לחץ על הקוד להעתקה',
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitleDark,
          ),
        ],
      ),
    );
  }
}

class _EntryFeeCard extends StatelessWidget {
  final int selected;
  final int playerCount;
  final ValueChanged<int> onChanged;

  const _EntryFeeCard({
    required this.selected,
    required this.playerCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('דמי כניסה', style: AppTextStyles.titleDark),
          const SizedBox(height: AppSpacing.sm),
          Text(
            selected == 0
                ? 'ללא סיר, משחק חינמי'
                : 'סיר: $selected × $playerCount = ${selected * playerCount} מטבעות',
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitleDark,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              for (final fee in EconomyConfig.entryFeeOptions) ...[
                Expanded(
                  child: _FeeButton(
                    fee: fee,
                    selected: selected == fee,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onChanged(fee);
                    },
                  ),
                ),
                if (fee != EconomyConfig.entryFeeOptions.last)
                  const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _FeeButton extends StatelessWidget {
  final int fee;
  final bool selected;
  final VoidCallback onTap;

  const _FeeButton({required this.fee, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        decoration: BoxDecoration(
          color: selected ? Candy.teal.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Candy.teal : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          fee == 0 ? 'חינם' : '$fee',
          style: TextStyle(
            color: selected ? Candy.teal : Colors.white70,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
