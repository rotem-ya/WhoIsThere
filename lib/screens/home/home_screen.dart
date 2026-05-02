import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  DateTime? _lastBackPressedAt;

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

  void _handleHomeBack() {
    final now = DateTime.now();
    final shouldExit = _lastBackPressedAt != null &&
        now.difference(_lastBackPressedAt!) < const Duration(seconds: 2);

    if (shouldExit) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPressedAt = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('לחיצה נוספת ליציאה מהמשחק'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (didPop) return;
          _handleHomeBack();
        },
        child: Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(gradient: AppColors.pageBackground),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 760;
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 26),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: compact ? 10 : 24),
                            _EntryHeroMark(size: compact ? 150 : 180),
                            SizedBox(height: compact ? 20 : 28),
                            const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'מה בתמונה?',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 52,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.4,
                                  height: 1,
                                ),
                              ),
                            ),
                            SizedBox(height: compact ? 10 : 14),
                            Text(
                              'חשוף חלקים ונחש את המקום',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: compact ? 19 : 22,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: compact ? 18 : 32),
                            Text(
                              'משחק מהיר',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: compact ? 19 : 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: compact ? 8 : 12),
                            _QuickPlayButton(
                              label: '2 שחקנים',
                              subtitle: 'מהיר ופשוט',
                              height: compact ? 64 : 72,
                              isLoading: _isCreating && _loadingPlayers == 2,
                              onPressed:
                                  _isCreating ? null : () => _startQuickGame(2),
                            ),
                            SizedBox(height: compact ? 8 : 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _SmallQuickButton(
                                    label: '3 שחקנים',
                                    height: compact ? 48 : 54,
                                    isLoading: _isCreating && _loadingPlayers == 3,
                                    onPressed: _isCreating
                                        ? null
                                        : () => _startQuickGame(3),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _SmallQuickButton(
                                    label: '4 שחקנים',
                                    height: compact ? 48 : 54,
                                    isLoading: _isCreating && _loadingPlayers == 4,
                                    onPressed: _isCreating
                                        ? null
                                        : () => _startQuickGame(4),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: compact ? 8 : 12),
                            _PrivateRoomButton(
                              isLoading: _isCreating && _loadingPlayers == null,
                              onPressed: _isCreating ? null : _createPrivateRoom,
                            ),
                            SizedBox(height: compact ? 12 : 24),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryHeroMark extends StatelessWidget {
  final double size;

  const _EntryHeroMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.29),
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
              blurRadius: 46,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Center(
          child: SizedBox(
            width: size * 0.55,
            height: size * 0.55,
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 7,
                crossAxisSpacing: 7,
              ),
              itemCount: 9,
              itemBuilder: (context, index) {
                final revealed = index == 1 || index == 4 || index == 6;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: revealed
                        ? const Color(0xFF35D9D0)
                        : Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: revealed
                          ? const Color(0xFF78FFF2)
                          : Colors.white.withOpacity(0.22),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      revealed ? '✦' : '?',
                      style: TextStyle(
                        color:
                            revealed ? const Color(0xFFFFD740) : Colors.white70,
                        fontSize: size * 0.12,
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
  final double height;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _QuickPlayButton({
    required this.label,
    required this.subtitle,
    required this.height,
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
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF35D9FF), Color(0xFF6A43FF), Color(0xFFFF4EB8)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6A43FF).withOpacity(0.40),
                blurRadius: 24,
                offset: const Offset(0, 10),
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
                      strokeWidth: 2.6,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bolt_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
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
                  ),
          ),
        ),
      ),
    );
  }
}

class _SmallQuickButton extends StatelessWidget {
  final String label;
  final double height;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _SmallQuickButton({
    required this.label,
    required this.height,
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
          height: height,
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
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }
}
