import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/economy_config.dart';
import '../../core/theme/candy_theme.dart';
import '../../providers/providers.dart';
import '../../services/qa_logger_service.dart';
import '../../services/sfx_service.dart';
import 'coin_fly.dart';
import 'coin_icon.dart';

/// Whether today's free spin is still available (UTC day, mirrors the wallet's
/// [lastDailySpinAt]). Used by the home button to show the "ready" dot.
bool isDailySpinAvailable(DateTime? lastSpinAt) {
  if (lastSpinAt == null) return true;
  final now = DateTime.now().toUtc();
  return !(lastSpinAt.year == now.year &&
      lastSpinAt.month == now.month &&
      lastSpinAt.day == now.day);
}

void showDailySpinSheet(BuildContext context, WidgetRef ref) {
  SfxService.instance.sheetOpen();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _DailySpinSheet(),
  );
}

const _segColors = <Color>[
  Candy.teal,
  Candy.pink,
  Candy.tangerine,
  Candy.blue,
  Candy.grape,
  Candy.gold,
  Color(0xFF56D364),
  Color(0xFFE0563D),
];

class _DailySpinSheet extends ConsumerStatefulWidget {
  const _DailySpinSheet();

  @override
  ConsumerState<_DailySpinSheet> createState() => _DailySpinSheetState();
}

class _DailySpinSheetState extends ConsumerState<_DailySpinSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;
  double _fromTurns = 0; // where the wheel currently rests (turns)
  double _toTurns = 0; // target
  bool _spinning = false;
  int? _wonCoins;
  final GlobalKey _wheelKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _doSpin() async {
    if (_spinning || _wonCoins != null) return;
    final uid = ref.read(firebaseUserProvider).valueOrNull?.uid;
    if (uid == null) return;
    setState(() => _spinning = true);

    try {
      final res = await ref.read(economyServiceProvider).claimDailySpin(uid);
      if (!mounted) return;
      if (res == null) {
        // Already spun today.
        setState(() => _spinning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('כבר סובבת היום, חזרו מחר'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Land segment res.index under the top pointer, after several turns.
      final n = EconomyConfig.dailySpinSegments.length;
      final seg = 1.0 / n;
      final landing = (n - res.index) % n * seg - seg / 2; // turns, [0,1)
      _fromTurns = _toTurns;
      _toTurns = _fromTurns.floorToDouble() + 5 + landing;
      SfxService.instance.reveal();
      await _spin.forward(from: 0);
      if (!mounted) return;
      setState(() {
        _spinning = false;
        _wonCoins = res.coins;
      });
      HapticFeedback.mediumImpact();
      SfxService.instance.coinGain();
      _flyCoins(res.coins);
      await Future.delayed(const Duration(milliseconds: 2400));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      final msg = e.toString();
      QaLoggerService.instance.log('ECONOMY',
          'DAILY_SPIN_UI_ERROR ${msg.length > 80 ? msg.substring(0, 80) : msg}');
      if (mounted) {
        setState(() => _spinning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('שגיאה בגלגל, נסו שוב')),
        );
      }
    }
  }

  void _flyCoins(int coins) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _wheelKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final from = box.localToGlobal(box.size.center(Offset.zero));
      CoinFly.burst(context, from: from, count: (coins ~/ 6).clamp(6, 16));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Candy.bgBottom,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Candy.gold.withOpacity(0.34), width: 1.2),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 24,
        top: 10,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text('🎡', style: TextStyle(fontSize: 44, height: 1)),
          const SizedBox(height: 8),
          const Text(
            'גלגל המזל היומי',
            style: TextStyle(
              color: Candy.gold,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'סיבוב אחד חינם בכל יום',
            style: TextStyle(
              color: Colors.white.withOpacity(0.62),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          // Wheel + pointer
          SizedBox(
            key: _wheelKey,
            width: 260,
            height: 274,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: 14,
                  child: AnimatedBuilder(
                    animation: _spin,
                    builder: (context, child) {
                      final t = Curves.easeOutQuart.transform(_spin.value);
                      final turns = _fromTurns + (_toTurns - _fromTurns) * t;
                      return Transform.rotate(
                        angle: turns * 2 * math.pi,
                        child: child,
                      );
                    },
                    child: CustomPaint(
                      size: const Size(248, 248),
                      painter: _WheelPainter(),
                    ),
                  ),
                ),
                // Top pointer
                Positioned(
                  top: 0,
                  child: Icon(Icons.arrow_drop_down_rounded,
                      size: 40, color: Candy.gold, shadows: const [
                    Shadow(color: Colors.black54, blurRadius: 6),
                  ]),
                ),
                // Hub
                Positioned(
                  top: 14 + 124 - 22,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFFFFF3C4), Candy.gold, Color(0xFFB8860B)],
                      ),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(color: Candy.gold.withOpacity(0.5), blurRadius: 12)
                      ],
                    ),
                    child: const Center(child: CoinIcon(size: 22, color: Color(0xFF6B4E08))),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_wonCoins != null)
            Text('זכית ב-$_wonCoins מטבעות! ✨',
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                    color: Candy.gold, fontSize: 20, fontWeight: FontWeight.w900))
          else
            SizedBox(
              width: double.infinity,
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE082), Candy.gold, Color(0xFFA1811A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: Candy.gold.withOpacity(0.38),
                        blurRadius: 20,
                        offset: const Offset(0, 8)),
                  ],
                ),
                child: FilledButton(
                  onPressed: _spinning ? null : _doSpin,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Candy.bgBottom,
                    textStyle: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  child: _spinning
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Color(0xFF07101F), strokeWidth: 2.5))
                      : const Text('סובב!'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final segments = EconomyConfig.dailySpinSegments;
    final n = segments.length;
    final seg = 2 * math.pi / n;
    // Outer gold rim.
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Candy.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6);

    for (var i = 0; i < n; i++) {
      final start = -math.pi / 2 + i * seg;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = _segColors[i % _segColors.length];
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius - 3), start, seg, true, paint);
      // Divider line.
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius - 3), start,
          seg, true, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withOpacity(0.25));

      // Amount label along the mid-angle.
      final mid = start + seg / 2;
      final tp = TextPainter(
        text: TextSpan(
          text: '${segments[i]}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelR = radius * 0.62;
      final pos = Offset(
        center.dx + math.cos(mid) * labelR - tp.width / 2,
        center.dy + math.sin(mid) * labelR - tp.height / 2,
      );
      tp.paint(canvas, pos);
    }
  }

  @override
  bool shouldRepaint(_WheelPainter old) => false;
}
