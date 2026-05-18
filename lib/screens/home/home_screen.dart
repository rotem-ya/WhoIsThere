import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/game_constants.dart';
import '../../core/theme/app_styles.dart';
import '../../providers/providers.dart';
import '../../services/feedback_service.dart';
import '../../services/qa_logger_service.dart';
import '../../widgets/common/ambient_background.dart';
import '../../widgets/common/pressable_scale.dart';
import '../../widgets/economy/coin_display.dart';
import '../../widgets/economy/daily_reward_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  // Persists across route remounts — intro plays only on first visit per session.
  static bool _introPlayed = false;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final bool _doIntro;
  bool _isCreating = false;
  int? _loadingPlayers;
  DateTime? _lastBackPressedAt;

  @override
  void initState() {
    super.initState();
    _doIntro = !HomeScreen._introPlayed;
    HomeScreen._introPlayed = true;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    QaLoggerService.instance.log('HOME', 'HOME_SCREEN_OPENED');
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startQuickGame(int targetPlayers) async {
    if (_isCreating) return;
    QaLoggerService.instance.log('HOME', 'TAP_QUICK_GAME players=$targetPlayers');
    FeedbackService.click();
    setState(() {
      _isCreating = true;
      _loadingPlayers = targetPlayers;
    });

    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) return;

      QaLoggerService.instance.log('HOME', 'QUICK_GAME_ATTEMPT players=$targetPlayers');
      final room = await ref.read(roomServiceProvider).createRoom(
            hostId: user.id,
            hostName: user.name,
            hostPhotoUrl: user.photoUrl,
            playerCount: targetPlayers,
          );

      await ref.read(roomServiceProvider).startGameDirectly(room.id);
      ref.read(currentRoomIdProvider.notifier).state = room.id;

      final shortId = room.id.substring(0, room.id.length.clamp(0, 6));
      QaLoggerService.instance.log('HOME', 'QUICK_GAME_SUCCESS code=${room.code} id=$shortId');
      QaLoggerService.instance.log('HOME', 'QUICK_GAME_NAVIGATED dest=/game/$shortId');
      if (mounted) context.go('/game/${room.id}');
    } catch (e) {
      final msg = e.toString();
      QaLoggerService.instance.log('HOME', 'QUICK_GAME_ERROR ${msg.length > 60 ? msg.substring(0, 60) : msg}');
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

  void _showJoinDialog() {
    QaLoggerService.instance.log('HOME', 'TAP_JOIN_ROOM');
    QaLoggerService.instance.log('HOME', 'JOIN_ROOM_SCREEN_OPENED');
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _JoinCodeDialog(),
    );
  }

  Future<void> _createPrivateRoom() async {
    if (_isCreating) return;
    QaLoggerService.instance.log('HOME', 'TAP_CREATE_ROOM');
    FeedbackService.click();
    setState(() {
      _isCreating = true;
      _loadingPlayers = null;
    });

    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) return;

      QaLoggerService.instance.log('HOME', 'CREATE_ROOM_ATTEMPT playerCount=default');
      final room = await ref.read(roomServiceProvider).createRoom(
            hostId: user.id,
            hostName: user.name,
            hostPhotoUrl: user.photoUrl,
          );

      final shortId = room.id.substring(0, room.id.length.clamp(0, 6));
      QaLoggerService.instance.log('HOME', 'CREATE_ROOM_SUCCESS code=${room.code} id=$shortId');
      ref.read(currentRoomIdProvider.notifier).state = room.id;
      if (mounted) context.go('/lobby/${room.id}');
    } catch (e) {
      final msg = e.toString();
      QaLoggerService.instance.log('HOME', 'CREATE_ROOM_ERROR ${msg.length > 60 ? msg.substring(0, 60) : msg}');
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

  /// Wraps [w] with a fade+rise entrance only on first visit.
  Widget _step(Widget w, {required int delayMs, required int durationMs, double dy = 0}) {
    if (!_doIntro) return w;
    var a = w.animate().fadeIn(
      delay: Duration(milliseconds: delayMs),
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeOut,
    );
    if (dy != 0) {
      a = a.moveY(
        begin: dy,
        end: 0,
        delay: Duration(milliseconds: delayMs),
        duration: Duration(milliseconds: durationMs),
        curve: Curves.easeOut,
      );
    }
    return a;
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
              const Positioned.fill(
                child: RepaintBoundary(
                  child: AmbientBackground(
                    showGrid: false,
                    showOrbits: false,
                    showParticles: true,
                    goldAccent: true,
                    intensity: 0.28,
                  ),
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final verySmall = constraints.maxHeight < 640;
                    final compact = constraints.maxHeight < 760;
                    final iconSize = verySmall ? 156.0 : compact ? 188.0 : 218.0;
                    return SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(height: verySmall ? 8 : compact ? 14 : 24),
                              _step(
                                Center(child: RepaintBoundary(child: _HomeHeroPeekGrid(size: iconSize))),
                                delayMs: 0, durationMs: 500, dy: 14,
                              ),
                              SizedBox(height: verySmall ? 10 : compact ? 16 : 20),
                              _step(
                                FittedBox(
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
                                      shadows: const [
                                        Shadow(color: Color(0xFFD4AF37), blurRadius: 16),
                                        Shadow(color: Colors.black87, offset: Offset(0, 4), blurRadius: 10),
                                        Shadow(color: Color(0x55D4AF37), blurRadius: 48, offset: Offset(0, 8)),
                                      ],
                                    ),
                                  ),
                                ),
                                delayMs: 120, durationMs: 380, dy: 8,
                              ),
                              const SizedBox(height: 10),
                              _step(
                                Text(
                                  'מי יזהה את המקום ראשון?',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: const Color(0xFF87CEEB).withOpacity(0.86),
                                    fontSize: verySmall ? 16 : compact ? 18 : 20,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                ),
                                delayMs: 220, durationMs: 320,
                              ),
                              SizedBox(height: verySmall ? 12 : compact ? 18 : 26),
                              _step(
                                const Text(
                                  'בחר פורמט',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white30,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.8,
                                  ),
                                ),
                                delayMs: 320, durationMs: 280,
                              ),
                              const SizedBox(height: 10),
                              _step(
                                _MainVaultButton(
                                  pulseController: _pulseController,
                                  label: 'שחק עכשיו',
                                  subtitle: 'דו־קרב מהיר · 2 שחקנים',
                                  height: verySmall ? 62 : compact ? 66 : 72,
                                  isLoading: _isCreating && _loadingPlayers == 2,
                                  onTap: _isCreating ? null : () => _startQuickGame(2),
                                ),
                                delayMs: 440, durationMs: 300, dy: 8,
                              ),
                              const SizedBox(height: 14),
                              _step(
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
                                delayMs: 540, durationMs: 280,
                              ),
                              SizedBox(height: verySmall ? 10 : 16),
                              _step(
                                _PrivateRoomButton(
                                  isLoading: _isCreating && _loadingPlayers == null,
                                  onTap: _isCreating ? null : _createPrivateRoom,
                                ),
                                delayMs: 640, durationMs: 260,
                              ),
                              const SizedBox(height: 10),
                              _step(
                                _JoinRoomButton(
                                  onTap: _isCreating ? null : _showJoinDialog,
                                ),
                                delayMs: 720, durationMs: 260,
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
              // Both of these must be after the ScrollView in the Stack so their
              // taps are not absorbed by SingleChildScrollView's opaque hit testing.
              const Positioned(
                top: 12,
                right: 16,
                child: SafeArea(child: _DailyRewardButton()),
              ),
              Positioned(
                top: 12,
                left: 16,
                child: SafeArea(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    // Force LTR so ProfileIcon is always at physical left (x=16)
                    // regardless of ambient RTL directionality.
                    textDirection: TextDirection.ltr,
                    children: [
                      const _ProfileIconButton(),
                      const SizedBox(width: 8),
                      const CoinDisplay(),
                    ],
                  ),
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
        onTap: onTap == null ? null : () {
          HapticFeedback.mediumImpact();
          onTap!();
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: onTap == null ? 0.65 : 1,
          child: Container(
            height: height,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFE082), Color(0xFFD4AF37), Color(0xFFA1811A)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.42), blurRadius: 25, offset: const Offset(0, 10))],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (onTap != null)
                  const _GoldShine()
                      .animate(onPlay: (c) => c.repeat())
                      .slideX(begin: -1.4, end: 1.4, duration: 2200.ms),
                Center(
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
                ],
              ),
          ),
        ),
      ),
    );
  }
}

class _GoldShine extends StatelessWidget {
  const _GoldShine();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.30,
        heightFactor: 1.0,
        child: Transform.rotate(
          angle: -0.30,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0),
                  Colors.white.withOpacity(0.18),
                  Colors.white.withOpacity(0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
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
    return PressableScale(
      onTap: onTap == null ? null : () {
        HapticFeedback.lightImpact();
        onTap!();
      },
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
      child: PressableScale(
        onTap: onTap == null ? null : () {
          HapticFeedback.lightImpact();
          onTap!();
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: onTap == null ? 0.58 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
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
                  const Icon(Icons.people_rounded, color: Color(0xFF87CEEB), size: 19),
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('שחק עם חברים', style: TextStyle(color: Color(0xFF87CEEB), fontSize: 16, fontWeight: FontWeight.w800, height: 1.1)),
                    Text('צור חדר ושתף קוד', style: TextStyle(color: const Color(0xFF87CEEB).withOpacity(0.60), fontSize: 11, fontWeight: FontWeight.w600, height: 1.2)),
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

// ── Join by code button ────────────────────────────────────────────────────

class _JoinRoomButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _JoinRoomButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: PressableScale(
        onTap: onTap == null ? null : () {
          HapticFeedback.lightImpact();
          onTap!();
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: onTap == null ? 0.58 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFF050A14).withOpacity(0.50),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF81C784).withOpacity(0.40)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.key_rounded, color: Color(0xFF81C784), size: 19),
                SizedBox(width: 8),
                Text('יש לי קוד', style: TextStyle(color: Color(0xFF81C784), fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Daily reward button (top-right corner) ────────────────────────────────

class _DailyRewardButton extends ConsumerWidget {
  const _DailyRewardButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAvailable =
        ref.watch(localEconomyCacheProvider).valueOrNull?.isDailyRewardAvailable ?? false;

    return GestureDetector(
      onTap: () {
        if (isAvailable) {
          showDailyRewardSheet(context, ref);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('הפרס היומי כבר נאסף'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isAvailable ? 1.0 : 0.38,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF050A14).withOpacity(0.60),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isAvailable
                      ? const Color(0xFFD4AF37).withOpacity(0.70)
                      : Colors.white.withOpacity(0.15),
                  width: isAvailable ? 1.5 : 1.0,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.card_giftcard_rounded,
                  color: Color(0xFFD4AF37),
                  size: 20,
                ),
              ),
            ),
            if (isAvailable)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppStyles.navyTop, width: 1.5),
                  ),
                  child: const Center(
                    child: Text(
                      '1',
                      style: TextStyle(
                        color: Color(0xFF07101F),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Profile icon button (top-left, QA access) ─────────────────────────────

class _ProfileIconButton extends StatelessWidget {
  const _ProfileIconButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          QaLoggerService.instance.log('HOME', 'TAP_PROFILE');
          context.push('/profile');
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF050A14).withOpacity(0.60),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1.0,
                ),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Colors.white70,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Join-by-code dialog ────────────────────────────────────────────────────

class _JoinCodeDialog extends ConsumerStatefulWidget {
  const _JoinCodeDialog();

  @override
  ConsumerState<_JoinCodeDialog> createState() => _JoinCodeDialogState();
}

class _JoinCodeDialogState extends ConsumerState<_JoinCodeDialog> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final raw = _controller.text.trim();
    final code = raw.toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'נא להזין קוד חדר');
      return;
    }

    QaLoggerService.instance.log('HOME', 'JOIN_ROOM_ATTEMPT raw=$raw code=$code');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) return;

      final found = await ref.read(roomServiceProvider).findRoomByCode(code);
      if (found == null) {
        QaLoggerService.instance.log('HOME', 'JOIN_ROOM_ERROR reason=not_found code=$code');
        setState(() => _error = 'לא נמצא חדר עם הקוד הזה');
        return;
      }
      if (found.phase != GamePhase.waiting) {
        QaLoggerService.instance.log('HOME', 'JOIN_ROOM_ERROR reason=already_started code=$code');
        setState(() => _error = 'המשחק כבר התחיל');
        return;
      }
      if (found.players.length >= GameConstants.maxPlayers) {
        QaLoggerService.instance.log('HOME', 'JOIN_ROOM_ERROR reason=room_full code=$code');
        setState(() => _error = 'חדר מלא\nניתן להצטרף לעד ${GameConstants.maxPlayers} שחקנים');
        return;
      }

      final room = await ref.read(roomServiceProvider).joinRoom(
            code: code,
            userId: user.id,
            userName: user.name,
            userPhotoUrl: user.photoUrl,
          );

      if (room == null) {
        QaLoggerService.instance.log('HOME', 'JOIN_ROOM_ERROR reason=join_failed code=$code');
        setState(() => _error = 'לא ניתן להצטרף לחדר');
        return;
      }

      final shortId = room.id.substring(0, room.id.length.clamp(0, 6));
      QaLoggerService.instance.log('HOME', 'JOIN_ROOM_SUCCESS code=${room.code} id=$shortId');
      ref.read(currentRoomIdProvider.notifier).state = room.id;
      if (mounted) {
        Navigator.of(context).pop();
        context.go('/lobby/${room.id}');
      }
    } catch (e) {
      final msg = e.toString();
      QaLoggerService.instance.log('HOME', 'JOIN_ROOM_ERROR reason=exception msg=${msg.length > 50 ? msg.substring(0, 50) : msg}');
      setState(() => _error = 'שגיאה: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: const Color(0xFF07101F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'הצטרפות לחדר',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _controller,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                autofocus: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: 'XXXXXX',
                  hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8),
                  counterText: '',
                  errorText: _error,
                  errorMaxLines: 2,
                  errorStyle: const TextStyle(fontSize: 13, height: 1.4),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF81C784), width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.redAccent),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                ],
                onSubmitted: (_) => _join(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white54,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('ביטול', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _join,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF81C784),
                        foregroundColor: const Color(0xFF07101F),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF07101F)))
                          : const Text('הצטרף', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Home screen hero — peek grid ─────────────────────────────────────────────
//
// 3×3 dark tile grid over a real landmark image.
// Tiles at indices 1, 3, 7 are "open" (transparent → image shows through).
// Tile 5 breathes slowly, suggesting imminent reveal.
// No board code, no ApertureTile, no image slicing math.

class _HomeHeroPeekGrid extends StatefulWidget {
  final double size;
  const _HomeHeroPeekGrid({required this.size});

  @override
  State<_HomeHeroPeekGrid> createState() => _HomeHeroPeekGridState();
}

class _HomeHeroPeekGridState extends State<_HomeHeroPeekGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  // Tile indices where the image shows through
  static const Set<int> _open = {1, 3, 7};
  // Tile that breathes (opacity pulse), hinting imminent reveal
  static const int _breathIdx = 5;
  // Landmark image shown behind the grid
  static const String _image = 'assets/game_places/images/masada.jpg';

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final r = s * 0.115;
    final gap = s * 0.030;

    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        border: Border.all(
          color: const Color(0xFFD4AF37).withOpacity(0.58),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.20),
            blurRadius: 30,
            spreadRadius: 3,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.65),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r - 1.5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Real landmark image — masada.jpg (local asset, 1024×1024)
            Image.asset(_image, fit: BoxFit.cover),
            // Dark gradient so closed tiles read clearly against bright areas
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.08),
                    Colors.black.withOpacity(0.48),
                  ],
                ),
              ),
            ),
            // Tile grid
            Padding(
              padding: EdgeInsets.all(gap),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: gap,
                  mainAxisSpacing: gap,
                  childAspectRatio: 1.0,
                ),
                itemCount: 9,
                itemBuilder: (_, idx) => _buildCell(idx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(int idx) {
    if (_open.contains(idx)) {
      // Transparent — image shows through; thin cyan border marks the opening
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: const Color(0xFF87CEEB).withOpacity(0.52),
            width: 1.0,
          ),
        ),
      );
    }

    final Widget tile = const _ClosedTile();

    if (idx == _breathIdx) {
      return AnimatedBuilder(
        animation: _breath,
        builder: (_, child) => Opacity(
          opacity: 0.52 + 0.48 * Curves.easeInOut.transform(_breath.value),
          child: child,
        ),
        child: tile,
      );
    }

    return tile;
  }
}

class _ClosedTile extends StatelessWidget {
  const _ClosedTile();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E1C30), Color(0xFF040C18)],
        ),
        border: Border.all(
          color: const Color(0xFFD4AF37).withOpacity(0.42),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}
