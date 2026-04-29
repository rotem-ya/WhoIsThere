import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../providers/providers.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_feedback.dart';
import '../../widgets/common/app_header.dart';

class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _joinRoom() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      AppFeedback.error();
      setState(() => _errorMessage = 'נא להזין קוד בן 6 תווים');
      return;
    }

    AppFeedback.confirm();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) return;

      final room = await ref.read(roomServiceProvider).joinRoom(
            code: code,
            userId: user.id,
            userName: user.name,
            userPhotoUrl: user.photoUrl,
          );

      if (room == null) {
        AppFeedback.error();
        setState(() => _errorMessage = 'החדר לא נמצא או כבר התחיל');
        return;
      }

      ref.read(currentRoomIdProvider.notifier).state = room.id;
      if (mounted) context.go('/lobby/${room.id}');
    } catch (e) {
      setState(() => _errorMessage = 'ההצטרפות נכשלה: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundGradient: AppColors.pageBackground,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          AppHeader(
            title: 'הצטרפות',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
          ),
          Expanded(
            child: Center(
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('הכנס קוד חדר', style: AppTextStyles.titleDark),
                    const SizedBox(height: AppSpacing.sm),
                    Text('קוד בן 6 תווים מהמארח',
                        style: AppTextStyles.subtitleDark),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: _codeController,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 6,
                      style: AppTextStyles.titleDark.copyWith(
                        fontSize: 34,
                        letterSpacing: 8,
                      ),
                      decoration: InputDecoration(
                        hintText: 'XXXXXX',
                        counterText: '',
                        errorText: _errorMessage,
                      ),
                      onSubmitted: (_) => _joinRoom(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _isLoading
              ? const CircularProgressIndicator(color: AppColors.accent)
              : AppButton(
                  label: 'הצטרף למשחק',
                  icon: Icons.login_rounded,
                  onPressed: _joinRoom,
                ),
        ],
      ),
    );
  }
}
