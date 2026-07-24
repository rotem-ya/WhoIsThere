import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/candy_theme.dart';
import '../../services/sfx_service.dart';

/// A prestige "premium unlocked" celebration — deliberately NOT confetti.
///
/// When a player buys a top-tier (1000 coin) cosmetic, this plays a short,
/// classy reveal: slow rotating golden light rays, an expanding shockwave ring,
/// a handful of elegant sparks, and a gold medallion that pops in with the item
/// name. It reads as "you unlocked something special" rather than a party.
///
/// Fail-soft and self-contained: inserts a root-overlay entry, auto-dismisses
/// after ~1.8s (or on tap), and uses only CustomPaint — no packages, no assets.
class PremiumUnlock {
  const PremiumUnlock._();

  static bool _showing = false;

  /// Celebrate a premium purchase. [itemName] is shown under the seal.
  static void celebrate(BuildContext context, String itemName) {
    if (_showing) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _showing = true;
    SfxService.instance.appear();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _PremiumUnlockLayer(
        itemName: itemName,
        onDone: () {
          entry.remove();
          _showing = false;
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _PremiumUnlockLayer extends StatefulWidget {
  final String itemName;
  final VoidCallback onDone;

  const _PremiumUnlockLayer({required this.itemName, required this.onDone});

  @override
  State<_PremiumUnlockLayer> createState() => _PremiumUnlockLayerState();
}

class _PremiumUnlockLayerState extends State<_PremiumUnlockLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1850),
    );
    _ctrl.forward().whenComplete(_finish);
  }

  void _finish() {
    if (_dismissed) return;
    _dismissed = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_ctrl.value > 0.5) _finish();
        },
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _ctrl.value;
            // Global fade: in over the first 12%, out over the last 18%.
            final fade = t < 0.12
                ? (t / 0.12)
                : t > 0.82
                    ? (1 - (t - 0.82) / 0.18).clamp(0.0, 1.0)
                    : 1.0;
            return Opacity(
              opacity: fade.clamp(0.0, 1.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Dim, gold-tinted backdrop.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 0.9,
                        colors: [
                          Candy.gold.withOpacity(0.16),
                          const Color(0xE60E0A1E),
                        ],
                        stops: const [0.0, 0.9],
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                  // Rays + shockwave + sparks + medallion.
                  CustomPaint(
                    size: Size.infinite,
                    painter: _PremiumBurstPainter(t),
                  ),
                  _Medallion(t: t, name: widget.itemName),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Medallion extends StatelessWidget {
  final double t;
  final String name;
  const _Medallion({required this.t, required this.name});

  @override
  Widget build(BuildContext context) {
    // Pop in with an elastic settle over the first ~40%.
    final pop = Curves.elasticOut.transform((t / 0.42).clamp(0.0, 1.0));
    final scale = 0.4 + 0.6 * pop;
    return Transform.scale(
      scale: scale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFFFFF3C4), Color(0xFFFFD84D), Color(0xFFB8860B)],
                stops: [0.0, 0.55, 1.0],
                center: Alignment(-0.25, -0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Candy.gold.withOpacity(0.6),
                  blurRadius: 34,
                  spreadRadius: 4,
                ),
              ],
              border: Border.all(color: const Color(0xFFFFF7DD), width: 2),
            ),
            child: const Center(
              child: Text('✦', style: TextStyle(fontSize: 52, color: Color(0xFF6B4E08))),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'פריט פרימיום נפתח',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: Candy.gold,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              name,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the golden god-rays, the expanding shockwave ring, and a few elegant
/// sparks radiating from the center. All driven by a single 0..1 progress.
class _PremiumBurstPainter extends CustomPainter {
  final double t;
  _PremiumBurstPainter(this.t);

  static const int _rayCount = 16;
  static const int _sparkCount = 9;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.longestSide;

    // ── Rotating god-rays ──────────────────────────────────────────────────
    final rayFade = t < 0.15
        ? t / 0.15
        : t > 0.7
            ? (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0)
            : 1.0;
    if (rayFade > 0) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(t * 0.6); // slow drift
      final rayPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Candy.gold.withOpacity(0.0),
            Candy.gold.withOpacity(0.22 * rayFade),
            Candy.gold.withOpacity(0.0),
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: maxR));
      const half = math.pi / _rayCount * 0.42;
      for (var i = 0; i < _rayCount; i++) {
        final a = (2 * math.pi / _rayCount) * i;
        final path = Path()
          ..moveTo(0, 0)
          ..lineTo(math.cos(a - half) * maxR, math.sin(a - half) * maxR)
          ..lineTo(math.cos(a + half) * maxR, math.sin(a + half) * maxR)
          ..close();
        canvas.drawPath(path, rayPaint);
      }
      canvas.restore();
    }

    // ── Expanding shockwave ring ───────────────────────────────────────────
    final ringT = (t / 0.6).clamp(0.0, 1.0);
    if (ringT > 0 && ringT < 1) {
      final r = Curves.easeOutCubic.transform(ringT) * maxR * 0.5;
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5 * (1 - ringT)
        ..color = Candy.gold.withOpacity(0.5 * (1 - ringT));
      canvas.drawCircle(center, r, ringPaint);
    }

    // ── Elegant sparks flying outward ──────────────────────────────────────
    final sparkT = (t / 0.72).clamp(0.0, 1.0);
    if (sparkT > 0 && sparkT < 1) {
      final eased = Curves.easeOutCubic.transform(sparkT);
      final dist = eased * maxR * 0.34;
      final sparkFade = (1 - sparkT).clamp(0.0, 1.0);
      final sparkPaint = Paint()..color = const Color(0xFFFFF3C4).withOpacity(sparkFade);
      for (var i = 0; i < _sparkCount; i++) {
        final a = (2 * math.pi / _sparkCount) * i + 0.3;
        final p = center + Offset(math.cos(a), math.sin(a)) * dist;
        final s = 3.0 + 2.0 * sparkFade;
        _drawSpark(canvas, p, s, sparkPaint);
      }
    }
  }

  void _drawSpark(Canvas canvas, Offset c, double s, Paint paint) {
    // A four-point sparkle (diamond) rather than a round dot.
    final path = Path()
      ..moveTo(c.dx, c.dy - s)
      ..lineTo(c.dx + s * 0.4, c.dy)
      ..lineTo(c.dx, c.dy + s)
      ..lineTo(c.dx - s * 0.4, c.dy)
      ..close();
    canvas.drawPath(path, paint);
    final path2 = Path()
      ..moveTo(c.dx - s, c.dy)
      ..lineTo(c.dx, c.dy + s * 0.4)
      ..lineTo(c.dx + s, c.dy)
      ..lineTo(c.dx, c.dy - s * 0.4)
      ..close();
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(_PremiumBurstPainter old) => old.t != t;
}
