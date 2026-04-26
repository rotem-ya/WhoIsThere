import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/providers.dart';
import '../../widgets/common/gradient_button.dart';

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
      setState(() => _errorMessage = 'נא להזין קוד בן 6 תווים');
      return;
    }

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
    return Scaffold(
      appBar: AppBar(title: const Text('הצטרף לחדר')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '🚪',
                style: TextStyle(fontSize: 72),
              ).animate().scale(curve: Curves.elasticOut, duration: 600.ms),
              const SizedBox(height: 24),
              const Text(
                'הכנס קוד חדר',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkBlue,
                ),
              ).animate(delay: 200.ms).fadeIn(),
              const SizedBox(height: 8),
              const Text(
                'בקש מהחבר שלך את הקוד בן 6 הספרות',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
              ).animate(delay: 300.ms).fadeIn(),
              const SizedBox(height: 32),
              TextField(
                controller: _codeController,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8,
                  color: AppColors.darkBlue,
                ),
                decoration: InputDecoration(
                  hintText: 'XXXXXX',
                  hintStyle: TextStyle(
                    letterSpacing: 8,
                    color: Colors.grey.shade300,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                  counterText: '',
                  errorText: _errorMessage,
                ),
                onSubmitted: (_) => _joinRoom(),
              ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.3),
              const SizedBox(height: 32),
              _isLoading
                  ? const CircularProgressIndicator(color: AppColors.primary)
                  : GradientButton(
                      text: 'הצטרף למשחק',
                      icon: Icons.login_rounded,
                      gradient: AppColors.secondaryGradient,
                      onPressed: _joinRoom,
                    ).animate(delay: 500.ms).fadeIn(),
            ],
          ),
        ),
      ),
    );
  }
}
