import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_styles.dart';
import '../../providers/providers.dart';
import '../../services/feedback_service.dart';
import '../../widgets/economy/coin_display.dart';
import '../../widgets/economy/daily_reward_sheet.dart';
import '../../widgets/game/vault_game_icon.dart';

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
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeTriggerDailyReward());
  }

  Future<void> _maybeTriggerDailyReward() async {
    try {
      final cache = await ref.read(localEconomyCacheProvider.future);
      if (!mounted || !cache.isDailyRewardAvailable) return;
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      showDailyRewardSheet(context, ref);
    } catch (_) {}
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
          backgroundColor: AppStyles.navyTop,
          body: Stack(
            children: [
              const Positioned.fill(child: _VaultBackground()),
              const Positioned(
                top: 12,
                left: 16,
                child: SafeArea(child: CoinDisplay()),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final verySmall = constraints.maxHeight < 640;
                    final compact = constraints.maxHeight < 760;
                    final iconSize = verySmall ? 104.0 : compact ? 124.0 : 146.0;
                    return SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(height: verySmall ? 10 : compact ? 18 : 34),
                              Center(child: VaultGameIcon(size: iconSize)),
                              SizedBox(height: verySmall ? 14 : compact ? 20 : 26),
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
                              const SizedBox(height: 10),
                              Text(
                                'חשוף חלקים ונחש את המקום',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFF87CEEB).withOpacity(0.86),
                                  fontSize: verySmall ? 16 : compact ? 18 : 20,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                              SizedBox(height: verySmall ? 16 : compact ? 22 : 32),
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
                                height: verySmall ? 62 : compact ? 66 : 72,
                                isLoading: _isCreating && _loadingPlayers == 2,
                                onTap: _isCreating ? null : () => _startQuickGame(2),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _GlassButton(
                                      label: '3 שחקנים',
                                      height: verySmall ? 50 : compact ? 54 : 58,
                                      isLoading: _isCreating && _loadingPlayers == 3,
                                      onTap: _isCreating ? null : () => _startQuickGame(3),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _GlassButton(
                                      label: '4 שחקנים',
                                      height: verySmall ? 50 : compact ? 54 : 58,
                                      isLoading: _isCreating && _loadingPlayers == 4,
                                      onTap: _isCreating ? null : () => _startQuickGame(4),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: verySmall ? 16 : 22),
                              _PrivateRoomButton(
                                isLoading: _isCreating && _loadingPlayers == null,
                                onTap: _isCreating ? null : _createPrivateRoom,
                              ),
                              SizedBox(height: verySmall ? 14 : compact ? 20 : 30),
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
        gradient: AppStyles.backgroundGradient,
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
      scale: Tween<double>(begin: 1.0, end: 1.04).animate(CurvedAnimation(parent: pulseController, curve: Curves.easeInOut)),
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
