import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../services/feedback_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _isCreating = false;
  int? _loadingPlayers;
  DateTime? _lastBackPressedAt;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startQuickGame(int targetPlayers) async {
    if (_isCreating) return;
    FeedbackService.click();
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
    FeedbackService.click();
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
          backgroundColor: const Color(0xFF050A14),
          body: Stack(
            children: [
              const Positioned.fill(child: _VaultBackground()),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxHeight < 760;
                    return SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(height: compact ? 18 : 38),
                              _VaultHeroMark(size: compact ? 138 : 166),
                              SizedBox(height: compact ? 22 : 28),
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
                                    letterSpacing: -1.7,
                                    height: 1,
                                    shadows: [
                                      Shadow(color: Color(0xFFD4AF37), blurRadius: 16),
                                      Shadow(color: Colors.black87, offset: Offset(0, 4), blurRadius: 10),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'חשוף חלקים ונחש את המקום',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFF87CEEB).withOpacity(0.86),
                                  fontSize: compact ? 18 : 20,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                              SizedBox(height: compact ? 22 : 36),
                              const Text(
                                'משחק מהיר',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _MainVaultButton(
                                pulseController: _pulseController,
                                label: '2 שחקנים',
                                subtitle: 'מהיר ופשוט',
                                height: compact ? 68 : 74,
                                isLoading: _isCreating && _loadingPlayers == 2,
                                onTap: _isCreating ? null : () => _startQuickGame(2),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _GlassButton(
                                      label: '3 שחקנים',
                                      height: compact ? 54 : 60,
                                      isLoading: _isCreating && _loadingPlayers == 3,
                                      onTap: _isCreating ? null : () => _startQuickGame(3),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _GlassButton(
                                      label: '4 שחקנים',
                                      height: compact ? 54 : 60,
                                      isLoading: _isCreating && _loadingPlayers == 4,
                                      onTap: _isCreating ? null : () => _startQuickGame(4),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              _PrivateRoomButton(
                                isLoading: _isCreating && _loadingPlayers == null,
                                onTap: _isCreating ? null : _createPrivateRoom,
                              ),
                              SizedBox(height: compact ? 20 : 34),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VaultBackground extends StatelessWidget {
  const _VaultBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.28,
          colors: [Color(0xFF12345F), Color(0xFF07101F), Color(0xFF050A14)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -110, right: -80, child: _Glow(color: Color(0xFFD4AF37), size: 310, opacity: 0.12)),
          Positioned(bottom: -95, left: -80, child: _Glow(color: Color(0xFF87CEEB), size: 285, opacity: 0.14)),
          Positioned(top: 190, left: 26, child: _Dot(size: 5, opacity: 0.40)),
          Positioned(top: 270, right: 34, child: _Dot(size: 4, opacity: 0.28)),
          Positioned(bottom: 190, right: 52, child: _Dot(size: 6, opacity: 0.24)),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _Glow({required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withOpacity(opacity), blurRadius: 120, spreadRadius: 48)],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final double size;
  final double opacity;

  const _Dot({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(opacity)),
    );
  }
}

class _VaultHeroMark extends StatelessWidget {
  final double size;

  const _VaultHeroMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.84, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.elasticOut,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF07101F).withOpacity(0.62),
            borderRadius: BorderRadius.circular(size * 0.25),
            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.82), width: 2.1),
            boxShadow: [
              BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.20), blurRadius: 30, spreadRadius: 3),
              BoxShadow(color: Colors.black.withOpacity(0.42), blurRadius: 24, offset: const Offset(0, 12)),
            ],
          ),
          child: Center(
            child: SizedBox.square(
              dimension: size * 0.55,
              child: GridView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 7, crossAxisSpacing: 7),
                itemCount: 9,
                itemBuilder: (context, index) {
                  final revealed = index == 1 || index == 4 || index == 8;
                  return Container(
                    decoration: BoxDecoration(
                      color: revealed ? const Color(0xFF35D9D0) : const Color(0xFF050A14),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: revealed ? const Color(0xFF87CEEB) : const Color(0xFFD4AF37).withOpacity(0.55), width: 1.8),
                      boxShadow: revealed ? [BoxShadow(color: const Color(0xFF87CEEB).withOpacity(0.35), blurRadius: 10)] : const [],
                    ),
                    child: Center(
                      child: Text(
                        revealed ? '✦' : '?',
                        style: TextStyle(color: revealed ? const Color(0xFFFFE082) : const Color(0xFFD4AF37), fontSize: size * 0.12, fontWeight: FontWeight.w900, height: 1),
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

class _MainVaultButton extends StatelessWidget {
  final AnimationController pulseController;
  final String label;
  final String subtitle;
  final double height;
  final bool isLoading;
  final VoidCallback? onTap;

  const _MainVaultButton({required this.pulseController, required this.label, required this.subtitle, required this.height, required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.018).animate(CurvedAnimation(parent: pulseController, curve: Curves.easeInOut)),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: onTap == null ? 0.65 : 1,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFE082), Color(0xFFD4AF37), Color(0xFFA1811A)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.42), blurRadius: 25, offset: const Offset(0, 10))],
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(color: Color(0xFF07101F), strokeWidth: 2.7))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bolt_rounded, color: Color(0xFF07101F), size: 30),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: const TextStyle(color: Color(0xFF07101F), fontSize: 28, fontWeight: FontWeight.w900, height: 1)),
                            const SizedBox(height: 4),
                            Text(subtitle, style: TextStyle(color: const Color(0xFF07101F).withOpacity(0.68), fontSize: 14, fontWeight: FontWeight.w800, height: 1)),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final String label;
  final double height;
  final bool isLoading;
  final VoidCallback? onTap;

  const _GlassButton({required this.label, required this.height, required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: onTap == null ? 0.62 : 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.065),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF87CEEB).withOpacity(0.34), width: 1.2),
              ),
              child: Center(
                child: isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                    : Text(label, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
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
  final VoidCallback? onTap;

  const _PrivateRoomButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: onTap == null ? 0.58 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFF050A14).withOpacity(0.50),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF87CEEB).withOpacity(0.26)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Color(0xFF87CEEB), strokeWidth: 2))
                else
                  const Icon(Icons.lock_outline_rounded, color: Color(0xFF87CEEB), size: 19),
                const SizedBox(width: 8),
                const Text('חדר פרטי עם קוד', style: TextStyle(color: Color(0xFF87CEEB), fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
