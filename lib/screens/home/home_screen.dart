import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isCreating = false;

  Future<void> _createAndJoin() async {
    if (_isCreating) return;
    setState(() => _isCreating = true);
    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) return;
      final room = await ref.read(roomServiceProvider).createRoom(
            hostId: user.id,
            hostName: user.name,
            hostPhotoUrl: user.photoUrl,
          );
      ref.read(currentRoomIdProvider.notifier).state = room.id;
      if (mounted) context.push('/lobby/${room.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('יצירת המשחק נכשלה: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (ctx) => Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: const Text('לצאת מהאפליקציה?'),
                content: const Text('האם אתה בטוח שברצונך לצאת?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('ביטול'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('יציאה'),
                  ),
                ],
              ),
            ),
          );
          if (shouldExit == true && context.mounted) {
            Navigator.of(context).maybePop();
          }
        },
        child: Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: AppColors.pageBackground,
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(flex: 3),
                    const Center(
                      child: Text('🧩', style: TextStyle(fontSize: 88)),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'מה בתמונה?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'חשוף חלקים ונחש את המקום',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    const Spacer(flex: 3),
                    _CreateButton(
                      isLoading: _isCreating,
                      onPressed: _isCreating ? null : _createAndJoin,
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _CreateButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF9B7EFF), Color(0xFF5B3DF5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.45),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Text(
                  'צור משחק',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}
