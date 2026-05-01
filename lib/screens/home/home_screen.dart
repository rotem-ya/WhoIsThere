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
  int? _loadingPlayers;

  Future<void> _startQuickGame(int targetPlayers) async {
    if (_isCreating) return;
    setState(() {
      _isCreating = true;
      _loadingPlayers = targetPlayers;
    });

    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) return;

      final room = await ref.read(roomServiceProvider).createRoom(
            hostId: user.id,
            hostName: user.name,
            hostPhotoUrl: user.photoUrl,
            playerCount: targetPlayers,
          );

      await ref.read(roomServiceProvider).startGameDirectly(room.id);
      ref.read(currentRoomIdProvider.notifier).state = room.id;

      if (mounted) context.go('/game/${room.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('יצירת המשחק נכשלה: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
          _loadingPlayers = null;
        });
      }
    }
  }

  Future<void> _createPrivateRoom() async {
    if (_isCreating) return;
    setState(() {
      _isCreating = true;
      _loadingPlayers = null;
    });

    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) return;

      final room = await ref.read(roomServiceProvider).createRoom(
            hostId: user.id,
            hostName: user.name,
            hostPhotoUrl: user.photoUrl,
          );

      ref.read(currentRoomIdProvider.notifier).state = room.id;
      if (mounted) context.go('/lobby/${room.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('יצירת החדר נכשלה: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
          _loadingPlayers = null;
        });
      }
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
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(flex: 4),
                    const _EntryHeroMark(),
                    const SizedBox(height: 34),
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'מה בתמונה?',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.4,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'חשוף חלקים ונחש את המקום',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const Spacer(flex: 5),
                    const Text(
                      'משחק מהיר',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _QuickPlayButton(
                      label: '2 שחקנים',
                      subtitle: 'מהיר ופשוט',
                      isLoading: _isCreating && _loadingPlayers == 2,
                      onPressed: _isCreating ? null : () => _startQuickGame(2),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _SmallQuickButton(
                            label: '3 שחקנים',
                            isLoading: _isCreating && _loadingPlayers == 3,
                            onPressed:
                                _isCreating ? null : () => _startQuickGame(3),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SmallQuickButton(
                            label: '4 שחקנים',
                            isLoading: _isCreating && _loadingPlayers == 4,
                            onPressed:
                                _isCreating ? null : () => _startQuickGame(4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _PrivateRoomButton(
                      isLoading: _isCreating && _loadingPlayers == null,
                      onPressed: _isCreating ? null : _createPrivateRoom,
                    ),
                    const SizedBox(height: 30),
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
        width: 198,
        height: 198,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(58),
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
            width: 108,
            height: 108,
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
                        color:
                            revealed ? const Color(0xFFFFD740) : Colors.white70,
                        fontSize: revealed ? 24 : 23,
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

class _QuickPlayButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _QuickPlayButton({
    required this.label,
    required this.subtitle,
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
          height: 74,
          padding: const EdgeInsets.symmetric(horizontal: 22),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.6,
                  ),
                )
              else ...[
                const Icon(Icons.bolt_rounded, color: Colors.white, size: 30),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallQuickButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _SmallQuickButton({
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
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.20)),
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.4,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _PrivateRoomButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _PrivateRoomButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2),
            )
          : const Icon(Icons.lock_outline_rounded, size: 18),
      label: const Text('חדר פרטי עם קוד'),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white70,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}
