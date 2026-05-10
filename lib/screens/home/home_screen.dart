import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/game_constants.dart';
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

  void _showJoinDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _JoinCodeDialog(),
    );
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
              const Positioned(
                top: 12,
                right: 16,
                child: SafeArea(child: _DailyRewardButton()),
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
                              const SizedBox(height: 10),
                              _JoinRoomButton(
                                onTap: _isCreating ? null : _showJoinDialog,
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

// ── Join by code button ────────────────────────────────────────────────────

class _JoinRoomButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _JoinRoomButton({required this.onTap});

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
              border: Border.all(color: const Color(0xFF81C784).withOpacity(0.40)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.group_add_rounded, color: Color(0xFF81C784), size: 19),
                SizedBox(width: 8),
                Text('הצטרף עם קוד', style: TextStyle(color: Color(0xFF81C784), fontSize: 16, fontWeight: FontWeight.w800)),
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
      onTap: () => showDailyRewardSheet(context, ref),
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
    final code = _controller.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'נא להזין קוד חדר');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) return;

      final found = await ref.read(roomServiceProvider).findRoomByCode(code);
      if (found == null) {
        setState(() => _error = 'לא נמצא חדר עם הקוד הזה');
        return;
      }
      if (found.phase != GamePhase.waiting) {
        setState(() => _error = 'המשחק כבר התחיל');
        return;
      }
      if (found.players.length >= GameConstants.maxPlayers) {
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
        setState(() => _error = 'לא ניתן להצטרף לחדר');
        return;
      }

      ref.read(currentRoomIdProvider.notifier).state = room.id;
      if (mounted) {
        Navigator.of(context).pop();
        context.go('/lobby/${room.id}');
      }
    } catch (e) {
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
