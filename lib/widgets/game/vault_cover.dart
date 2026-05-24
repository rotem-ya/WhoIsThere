import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/card_skin.dart';

class VaultCover extends StatefulWidget {
  final bool isRevealed;
  final bool isFocused;
  final Widget child;
  final String cardSkinId;

  const VaultCover({
    super.key,
    required this.isRevealed,
    required this.child,
    this.isFocused = false,
    this.cardSkinId = 'default',
  });

  @override
  State<VaultCover> createState() => _VaultCoverState();
}

class _VaultCoverState extends State<VaultCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  ui.Image? _skinImage;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);

    if (widget.isRevealed) _ctrl.value = 1.0;
    _loadSkinImage(widget.cardSkinId);
  }

  @override
  void didUpdateWidget(covariant VaultCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRevealed && !oldWidget.isRevealed) {
      _ctrl.forward();
    } else if (!widget.isRevealed && oldWidget.isRevealed) {
      _ctrl.reverse();
    }
    if (widget.cardSkinId != oldWidget.cardSkinId) {
      _loadSkinImage(widget.cardSkinId);
    }
  }

  static Future<ui.Image> _decodeUiImage(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }

  Future<void> _loadSkinImage(String skinId) async {
    final skin = kAvailableCardSkins.firstWhere(
      (s) => s.id == skinId,
      orElse: () => kAvailableCardSkins.first,
    );
    if (skin.assetPath == null) {
      if (mounted) setState(() => _skinImage = null);
      return;
    }
    try {
      final data = await rootBundle.load(skin.assetPath!);
      final image = await _decodeUiImage(data.buffer.asUint8List());
      if (mounted) setState(() => _skinImage = image);
    } catch (_) {
      if (mounted) setState(() => _skinImage = null);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Revealed image underneath ──────────────────────────────────
          widget.child,

          // ── Iris blades ────────────────────────────────────────────────
          AnimatedBuilder(
            animation: _anim,
            builder: (context, _) {
              if (_anim.value >= 0.995) return const SizedBox.shrink();
              return RepaintBoundary(
                child: CustomPaint(
                  painter: _AperturePainter(
                    progress: _anim.value,
                    cardSkinId: widget.cardSkinId,
                    skinImage: _skinImage,
                  ),
                ),
              );
            },
          ),

          // ── Flash of light at reveal peak ──────────────────────────────
          AnimatedBuilder(
            animation: _ctrl, // linear for precise timing
            builder: (context, _) {
              final t = _ctrl.value;
              // Ramp up 0→0.38, ramp down 0.38→0.72
              final raw = t <= 0.38
                  ? t / 0.38
                  : math.max(0.0, 1.0 - (t - 0.38) / 0.34);
              final opacity = (raw * 0.60).clamp(0.0, 1.0);
              if (opacity < 0.01) return const SizedBox.shrink();
              return Opacity(
                opacity: opacity,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Color(0xFFFFFFFF),
                        Color(0xFFFFE082),
                        Color(0x00FFE082),
                      ],
                      stops: [0.0, 0.40, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Improved iris painter ──────────────────────────────────────────────────────

class _AperturePainter extends CustomPainter {
  final double progress;
  final String cardSkinId;
  final ui.Image? skinImage;

  static const int _bladeCount = 10;

  const _AperturePainter({
    required this.progress,
    this.cardSkinId = 'default',
    this.skinImage,
  });

  // ── Per-skin colour scheme ─────────────────────────────────────────────────
  static _SkinPalette _palette(String id) {
    switch (id) {
      case 'blue':
        return const _SkinPalette(
          base:          Color(0xFF030D1A),
          bladeLight:    Color(0xFFB8DFFF),
          bladeMid:      Color(0xFF87CEEB),
          bladeDark:     Color(0xFF1890D0),
          bladeShadow:   Color(0xFF040F1E),
          seam:          Color(0xFFD0EEFF),
          rimOuter:      Color(0xFF87CEEB),
          rimInner:      Color(0xFF00BFFF),
        );
      case 'red':
        return const _SkinPalette(
          base:          Color(0xFF1A0303),
          bladeLight:    Color(0xFFFFBBB0),
          bladeMid:      Color(0xFFFF6B6B),
          bladeDark:     Color(0xFFBB1515),
          bladeShadow:   Color(0xFF230404),
          seam:          Color(0xFFFFD0CC),
          rimOuter:      Color(0xFFFF6B6B),
          rimInner:      Color(0xFFFF3B30),
        );
      case 'dark':
        return const _SkinPalette(
          base:          Color(0xFF05050F),
          bladeLight:    Color(0xFFB8AEFF),
          bladeMid:      Color(0xFF8B6FFF),
          bladeDark:     Color(0xFF4A3A8A),
          bladeShadow:   Color(0xFF080516),
          seam:          Color(0xFFD0C8FF),
          rimOuter:      Color(0xFF8B6FFF),
          rimInner:      Color(0xFF6464FF),
        );
      default: // 'default' — gold
        return const _SkinPalette(
          base:          Color(0xFF07101F),
          bladeLight:    Color(0xFFFFF3B8),
          bladeMid:      Color(0xFFD4AF37),
          bladeDark:     Color(0xFF8B6914),
          bladeShadow:   Color(0xFF3A2A05),
          seam:          Color(0xFFFFF8CC),
          rimOuter:      Color(0xFFD4AF37),
          rimInner:      Color(0xFF87CEEB),
        );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height / 2);
    final diagonal =
        math.sqrt(size.width * size.width + size.height * size.height);
    final outerRadius = diagonal * 0.74;
    final pal = _palette(cardSkinId);

    canvas.saveLayer(rect, Paint());

    // ── Base: skin image if loaded, otherwise solid colour ────────────────
    if (skinImage != null) {
      final src = Rect.fromLTWH(
          0, 0, skinImage!.width.toDouble(), skinImage!.height.toDouble());
      canvas.drawImageRect(skinImage!, src, rect, Paint());
    } else {
      canvas.drawRect(rect, Paint()..color = pal.base);
    }

    // ── Metallic rotating blades (skin colours) ───────────────────────────
    final rotation = progress * math.pi * 0.52;
    final angleStep = (2 * math.pi) / _bladeCount;

    for (int i = 0; i < _bladeCount; i++) {
      final angle = i * angleStep + rotation;
      final nextAngle = angle + angleStep * 1.85;

      final pOuter1 = Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      );
      final pOuter2 = Offset(
        center.dx + outerRadius * math.cos(nextAngle),
        center.dy + outerRadius * math.sin(nextAngle),
      );
      final midAngle = (angle + nextAngle) / 2;
      final controlRadius = outerRadius * 0.78;
      final pControl = Offset(
        center.dx + controlRadius * math.cos(midAngle),
        center.dy + controlRadius * math.sin(midAngle),
      );

      final bladePath = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(pOuter1.dx, pOuter1.dy)
        ..quadraticBezierTo(
            pControl.dx, pControl.dy, pOuter2.dx, pOuter2.dy)
        ..close();

      final gradientAngle = angle + 0.25;
      canvas.drawPath(
        bladePath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment(
                math.cos(gradientAngle), math.sin(gradientAngle)),
            end: Alignment(math.cos(gradientAngle + math.pi),
                math.sin(gradientAngle + math.pi)),
            colors: [
              pal.bladeLight,
              pal.bladeLight.withOpacity(0.85),
              pal.bladeMid,
              pal.bladeDark,
              pal.bladeShadow,
            ],
            stops: const [0.0, 0.18, 0.42, 0.72, 1.0],
          ).createShader(rect),
      );

      // Thin bright seam on the leading edge
      canvas.drawLine(
        center,
        pOuter1,
        Paint()
          ..color = pal.seam.withOpacity(0.55)
          ..strokeWidth = 0.6,
      );
    }

    // ── Punch iris hole using BlendMode.clear ────────────────────────────
    final holeRadius = progress * outerRadius;
    if (holeRadius > 0) {
      canvas.drawCircle(
          center, holeRadius, Paint()..blendMode = BlendMode.clear);
    }

    canvas.restore();

    // ── Chrome ring at the iris edge (skin-tinted) ───────────────────────
    if (holeRadius > 2 && progress < 0.97) {
      final rimAlpha = (1.0 - progress).clamp(0.0, 1.0);

      canvas.drawCircle(
        center,
        holeRadius + 0.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = pal.rimOuter.withOpacity(rimAlpha * 0.85)
          ..strokeWidth = 1.4,
      );
      canvas.drawCircle(
        center,
        holeRadius - 0.8,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = pal.rimInner.withOpacity(rimAlpha * 0.50)
          ..strokeWidth = 0.7,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AperturePainter old) =>
      old.progress != progress ||
      old.cardSkinId != cardSkinId ||
      old.skinImage != skinImage;
}

// ── Skin colour palette ───────────────────────────────────────────────────────

class _SkinPalette {
  final Color base;
  final Color bladeLight;
  final Color bladeMid;
  final Color bladeDark;
  final Color bladeShadow;
  final Color seam;
  final Color rimOuter;
  final Color rimInner;

  const _SkinPalette({
    required this.base,
    required this.bladeLight,
    required this.bladeMid,
    required this.bladeDark,
    required this.bladeShadow,
    required this.seam,
    required this.rimOuter,
    required this.rimInner,
  });
}
