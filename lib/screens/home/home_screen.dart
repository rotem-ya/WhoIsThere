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
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(flex: 7),
                    const _EntryHeroMark(),
                    const SizedBox(height: 46),
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'מה בתמונה?',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.4,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'חשוף חלקים ונחש את המקום',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const Spacer(flex: 9),
                    _PrimaryEntryButton(
                      label: 'צור משחק',
                      isLoading: _isCreating,
                      onPressed: _isCreating ? null : _createAndJoin,
                    ),
                    const SizedBox(height: 42),
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

class _EntryHeroMark extends StatelessWidget {
  const _EntryHeroMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(62),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.16),
              Colors.white.withOpacity(0.07),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.20), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF29E6FF).withOpacity(0.22),
              blurRadius: 54,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Center(
          child: SizedBox(
            width: 118,
            height: 118,
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: 9,
              itemBuilder: (context, index) {
                final revealed = index == 1 || index == 4 || index == 8;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: revealed
                        ? const Color(0xFF35D9D0)
                        : Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: revealed
                          ? const Color(0xFF78FFF2)
                          : Colors.white.withOpacity(0.22),
                      width: 2,
                    ),
                    boxShadow: revealed
                        ? [
                            BoxShadow(
                              color: const Color(0xFF35D9D0).withOpacity(0.42),
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      revealed ? '✦' : '?',
                      style: TextStyle(
                        color: revealed ? const Color(0xFFFFD740) : Colors.white70,
                        fontSize: revealed ? 26 : 25,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryEntryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _PrimaryEntryButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: onPressed == null ? 0.72 : 1,
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF35D9FF), Color(0xFF6A43FF), Color(0xFFFF4EB8)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6A43FF).withOpacity(0.46),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.6,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
