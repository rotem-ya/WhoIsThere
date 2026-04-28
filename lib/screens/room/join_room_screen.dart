import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/providers.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/app_feedback.dart';
import '../../widgets/common/premium_scaffold.dart';

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
    return PremiumScaffold(
      showBeams: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height -
                MediaQuery.of(context).padding.vertical -
                40,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PremiumHeader(
                eyebrow: 'כניסה מהירה',
                title: 'יש לך קוד?',
                subtitle: 'הזן את קוד החדר והצטרף ישירות ללובי.',
                icon: Icons.login_rounded,
                onBack: () => context.pop(),
              ).animate().fadeIn().slideY(begin: -0.12),
              const SizedBox(height: 28),
              PremiumGlassCard(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    const HeroPuzzleMark(size: 106),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _codeController,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 6,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: 'XXXXXX',
                        hintStyle: TextStyle(
                          letterSpacing: 8,
                          color: Colors.white.withOpacity(0.26),
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.10),
                        counterText: '',
                        errorText: _errorMessage,
                        errorStyle: const TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onSubmitted: (_) => _joinRoom(),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'טיפ: הקוד בן 6 תווים ונמצא אצל המארח',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.64),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ).animate(delay: 140.ms).fadeIn().scale(
                    begin: const Offset(0.96, 0.96),
                    curve: Curves.easeOutBack,
                  ),
              const SizedBox(height: 28),
              _isLoading
                  ? const CircularProgressIndicator(color: AppColors.accent)
                  : GradientButton(
                      text: 'הצטרף למשחק',
                      icon: Icons.login_rounded,
                      gradient: AppColors.secondaryGradient,
                      onPressed: _joinRoom,
                    ).animate(delay: 260.ms).fadeIn().slideY(begin: 0.16),
            ],
          ),
        ),
      ),
    );
  }
}
