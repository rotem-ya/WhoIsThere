import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/card_skin.dart';

Future<ui.Image> _decodeUiImage(Uint8List bytes) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromList(bytes, completer.complete);
  return completer.future;
}

/// Resolves a network URL directly to a ui.Image via Flutter's image cache.
Future<ui.Image?> _fetchNetworkUiImage(String url) async {
  try {
    final stream = NetworkImage(url).resolve(ImageConfiguration.empty);
    final completer = Completer<ui.Image>();
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) => completer.complete(info.image),
      onError: (e, _) => completer.completeError(e),
    );
    stream.addListener(listener);
    final image = await completer.future;
    stream.removeListener(listener);
    return image;
  } catch (_) {
    return null;
  }
}

class VaultCover extends StatefulWidget {
  final bool isRevealed;
  final bool isFocused;
  final Widget child;
  final String cardSkinId;
  /// Optional full skin object — when provided, network coverImageUrl is used.
  final CardSkin? skin;

  const VaultCover({
    super.key,
    required this.isRevealed,
    required this.child,
    this.isFocused = false,
    this.cardSkinId = 'default',
    this.skin,
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
    if (widget.cardSkinId != oldWidget.cardSkinId ||
        widget.skin?.coverImageUrl != oldWidget.skin?.coverImageUrl) {
      _loadSkinImage(widget.cardSkinId);
    }
  }

  Future<void> _loadSkinImage(String skinId) async {
    // Prefer explicit skin object (may have network URL) over hardcoded lookup
    final skin = widget.skin ??
        kAvailableCardSkins.firstWhere(
          (s) => s.id == skinId,
          orElse: () => kAvailableCardSkins.first,
        );

    // Network image takes priority
    if (skin.coverImageUrl != null) {
      final image = await _fetchNetworkUiImage(skin.coverImageUrl!);
      if (mounted) setState(() => _skinImage = image);
      return;
    }

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
      case 'classic':
        return const _SkinPalette(
          base:          Color(0xFF1A1A2E),
          bladeLight:    Color(0xFFE8E8F0),
          bladeMid:      Color(0xFFB0B0C8),
          bladeDark:     Color(0xFF6060A0),
          bladeShadow:   Color(0xFF0D0D1E),
          seam:          Color(0xFFFFFFFF),
          rimOuter:      Color(0xFFB0B0C8),
          rimInner:      Color(0xFF8080C0),
        );
      case 'ocean':
        return const _SkinPalette(
          base:          Color(0xFF001A33),
          bladeLight:    Color(0xFF80FFEE),
          bladeMid:      Color(0xFF00BCD4),
          bladeDark:     Color(0xFF006080),
          bladeShadow:   Color(0xFF001020),
          seam:          Color(0xFFB2FFF5),
          rimOuter:      Color(0xFF00BCD4),
          rimInner:      Color(0xFF00E5FF),
        );
      case 'forest':
        return const _SkinPalette(
          base:          Color(0xFF071A07),
          bladeLight:    Color(0xFFB8FFB8),
          bladeMid:      Color(0xFF4CAF50),
          bladeDark:     Color(0xFF1B5E20),
          bladeShadow:   Color(0xFF030D03),
          seam:          Color(0xFFCCFFCC),
          rimOuter:      Color(0xFF4CAF50),
          rimInner:      Color(0xFF69F070),
        );
      case 'sand':
        return const _SkinPalette(
          base:          Color(0xFF2A1F0A),
          bladeLight:    Color(0xFFFFF8DC),
          bladeMid:      Color(0xFFD4A54A),
          bladeDark:     Color(0xFF8B6914),
          bladeShadow:   Color(0xFF1A1005),
          seam:          Color(0xFFFFFAE0),
          rimOuter:      Color(0xFFD4A54A),
          rimInner:      Color(0xFFFFD060),
        );
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
      case 'copper':
        return const _SkinPalette(
          base:          Color(0xFF1A0D05),
          bladeLight:    Color(0xFFFFCBA0),
          bladeMid:      Color(0xFFB87333),
          bladeDark:     Color(0xFF6B3D0A),
          bladeShadow:   Color(0xFF100803),
          seam:          Color(0xFFFFDDB8),
          rimOuter:      Color(0xFFB87333),
          rimInner:      Color(0xFFFF9050),
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
      case 'emerald':
        return const _SkinPalette(
          base:          Color(0xFF011A0D),
          bladeLight:    Color(0xFF80FFD0),
          bladeMid:      Color(0xFF00C853),
          bladeDark:     Color(0xFF00571E),
          bladeShadow:   Color(0xFF010D06),
          seam:          Color(0xFFB0FFE0),
          rimOuter:      Color(0xFF00C853),
          rimInner:      Color(0xFF69FFB4),
        );
      case 'ruby':
        return const _SkinPalette(
          base:          Color(0xFF1A0008),
          bladeLight:    Color(0xFFFFB0C8),
          bladeMid:      Color(0xFFE91E63),
          bladeDark:     Color(0xFF880025),
          bladeShadow:   Color(0xFF120005),
          seam:          Color(0xFFFFCCDD),
          rimOuter:      Color(0xFFE91E63),
          rimInner:      Color(0xFFFF4088),
        );
      case 'rose_gold':
        return const _SkinPalette(
          base:          Color(0xFF1A0D10),
          bladeLight:    Color(0xFFFFD6CC),
          bladeMid:      Color(0xFFB76E79),
          bladeDark:     Color(0xFF7A3040),
          bladeShadow:   Color(0xFF120809),
          seam:          Color(0xFFFFE8E2),
          rimOuter:      Color(0xFFB76E79),
          rimInner:      Color(0xFFFFAABB),
        );
      case 'galaxy':
        return const _SkinPalette(
          base:          Color(0xFF03001A),
          bladeLight:    Color(0xFFE0C0FF),
          bladeMid:      Color(0xFF9C27B0),
          bladeDark:     Color(0xFF4A0072),
          bladeShadow:   Color(0xFF020010),
          seam:          Color(0xFFF0D8FF),
          rimOuter:      Color(0xFF9C27B0),
          rimInner:      Color(0xFFCE93D8),
        );
      case 'obsidian':
        return const _SkinPalette(
          base:          Color(0xFF000000),
          bladeLight:    Color(0xFF909090),
          bladeMid:      Color(0xFF404040),
          bladeDark:     Color(0xFF1A1A1A),
          bladeShadow:   Color(0xFF000000),
          seam:          Color(0xFFC0C0C0),
          rimOuter:      Color(0xFF606060),
          rimInner:      Color(0xFF909090),
        );
      default: // 'default' — gold mandala
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

  // ── Per-skin unique background pattern ────────────────────────────────────
  void _drawSkinPattern(Canvas canvas, Size size, Rect rect,
      Offset center, _SkinPalette pal) {
    _drawPattern(canvas, size, rect, center, pal, cardSkinId);
  }

  static void _drawPattern(
      Canvas canvas, Size size, Rect rect, Offset center,
      _SkinPalette pal, String skinId) {
    final rngA = math.Random(1337);
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()..style = PaintingStyle.fill;

    switch (skinId) {
      // ── classic — ornamental diamond grid ──────────────────────────────
      case 'classic':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.20)
          ..strokeWidth = 0.8;
        const s = 20.0;
        for (var x = -s; x < size.width + s; x += s) {
          for (var y = -s; y < size.height + s; y += s) {
            final p = Path()
              ..moveTo(x, y - s * 0.5)
              ..lineTo(x + s * 0.5, y)
              ..lineTo(x, y + s * 0.5)
              ..lineTo(x - s * 0.5, y)
              ..close();
            canvas.drawPath(p, linePaint);
          }
        }

      // ── ocean — horizontal sine waves ──────────────────────────────────
      case 'ocean':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.22)
          ..strokeWidth = 1.1;
        const waveCount = 13;
        const amp = 5.0;
        for (var w = 0; w <= waveCount; w++) {
          final baseY = (size.height / waveCount) * w;
          final path = Path();
          var first = true;
          for (var x = 0.0; x <= size.width; x += 3) {
            final y = baseY + math.sin(x * 0.045 + w * 0.9) * amp;
            if (first) {
              path.moveTo(x, y);
              first = false;
            } else {
              path.lineTo(x, y);
            }
          }
          canvas.drawPath(path, linePaint);
        }

      // ── forest — diagonal branch lines + leaf ovals ────────────────────
      case 'forest':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.18)
          ..strokeWidth = 0.9;
        const spacing = 26.0;
        for (var i = -size.height.toInt();
            i < size.width.toInt() + size.height.toInt();
            i += spacing.toInt()) {
          canvas.drawLine(Offset(i.toDouble(), 0),
              Offset(i.toDouble() + size.height * 0.7, size.height), linePaint);
        }
        fillPaint.color = pal.bladeLight.withOpacity(0.12);
        for (var i = 0; i < 18; i++) {
          final angle = i * 2.41;
          final r = size.width * (0.08 + (i % 5) * 0.09);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(center.dx + math.cos(angle) * r,
                  center.dy + math.sin(angle) * r),
              width: 14,
              height: 7,
            ),
            fillPaint,
          );
        }

      // ── sand — concentric ellipse rings ────────────────────────────────
      case 'sand':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.22)
          ..strokeWidth = 1.0;
        for (var i = 1; i <= 12; i++) {
          canvas.drawOval(
            Rect.fromCenter(
              center: center,
              width: i * size.width * 0.17,
              height: i * size.height * 0.13,
            ),
            linePaint,
          );
        }

      // ── blue — constellation (dots + connecting lines) ─────────────────
      case 'blue':
        final positions = List.generate(
          55,
          (i) => Offset(
            rngA.nextDouble() * size.width,
            rngA.nextDouble() * size.height,
          ),
        );
        fillPaint.color = pal.bladeLight.withOpacity(0.55);
        for (final p in positions) {
          canvas.drawCircle(p, rngA.nextDouble() * 1.5 + 0.5, fillPaint);
        }
        linePaint
          ..color = pal.bladeMid.withOpacity(0.14)
          ..strokeWidth = 0.6;
        for (var i = 0; i < 14; i++) {
          canvas.drawLine(positions[i], positions[i + 1], linePaint);
        }

      // ── red — bold diagonal stripes ────────────────────────────────────
      case 'red':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.20)
          ..strokeWidth = 10;
        const sp = 32.0;
        for (var i = -size.height.toInt();
            i < size.width.toInt() + size.height.toInt();
            i += sp.toInt()) {
          canvas.drawLine(Offset(i.toDouble(), 0),
              Offset(i.toDouble() + size.height, size.height), linePaint);
        }

      // ── copper — cross-hatch grid ──────────────────────────────────────
      case 'copper':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.20)
          ..strokeWidth = 0.8;
        const g = 18.0;
        for (var x = 0.0; x < size.width; x += g) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
        }
        for (var y = 0.0; y < size.height; y += g) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
        }

      // ── dark — night star field + purple glow ─────────────────────────
      case 'dark':
        fillPaint.color = pal.bladeLight.withOpacity(0.55);
        for (var i = 0; i < 90; i++) {
          final x = rngA.nextDouble() * size.width;
          final y = rngA.nextDouble() * size.height;
          final r = i < 6 ? 1.8 : 0.7;
          canvas.drawCircle(Offset(x, y), r, fillPaint);
        }
        // Soft central glow
        canvas.drawCircle(
          center,
          size.width * 0.28,
          Paint()
            ..color = pal.bladeDark.withOpacity(0.22)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
        );

      // ── emerald — hexagonal grid ───────────────────────────────────────
      case 'emerald':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.22)
          ..strokeWidth = 1.0;
        const hr = 16.0;
        const dx = hr * 1.7321; // sqrt(3)
        const dy = hr * 1.5;
        for (var row = -1; row < size.height / dy + 2; row++) {
          for (var col = -1; col < size.width / dx + 2; col++) {
            final ox = (row % 2) * (dx / 2);
            final cx = col * dx + ox;
            final cy = row * dy;
            final path = Path();
            for (var side = 0; side < 6; side++) {
              final a = side * math.pi / 3 - math.pi / 6;
              final px = cx + hr * math.cos(a);
              final py = cy + hr * math.sin(a);
              if (side == 0) path.moveTo(px, py);
              else path.lineTo(px, py);
            }
            path.close();
            canvas.drawPath(path, linePaint);
          }
        }

      // ── ruby — scattered 4-pointed sparkles ───────────────────────────
      case 'ruby':
        fillPaint.color = pal.bladeLight.withOpacity(0.40);
        for (var i = 0; i < 40; i++) {
          final x = rngA.nextDouble() * size.width;
          final y = rngA.nextDouble() * size.height;
          final s = rngA.nextDouble() * 5 + 2;
          final path = Path()
            ..moveTo(x, y - s)
            ..lineTo(x + s * 0.28, y - s * 0.28)
            ..lineTo(x + s, y)
            ..lineTo(x + s * 0.28, y + s * 0.28)
            ..lineTo(x, y + s)
            ..lineTo(x - s * 0.28, y + s * 0.28)
            ..lineTo(x - s, y)
            ..lineTo(x - s * 0.28, y - s * 0.28)
            ..close();
          canvas.drawPath(path, fillPaint);
        }

      // ── rose_gold — overlapping circle petals ─────────────────────────
      case 'rose_gold':
        linePaint
          ..color = pal.bladeMid.withOpacity(0.18)
          ..strokeWidth = 1.1;
        const petalCount = 8;
        const petalR = 30.0;
        for (var i = 0; i < petalCount; i++) {
          final a = (i / petalCount) * 2 * math.pi;
          final px = center.dx + math.cos(a) * petalR;
          final py = center.dy + math.sin(a) * petalR;
          for (var j = 0; j < 4; j++) {
            canvas.drawCircle(
              Offset(px, py),
              petalR * (1 - j * 0.2),
              linePaint
                ..color = pal.bladeMid.withOpacity(0.10 - j * 0.02),
            );
          }
        }
        for (var r = 15.0; r < size.width; r += 28) {
          canvas.drawCircle(
              center, r, linePaint..color = pal.bladeLight.withOpacity(0.07));
        }

      // ── galaxy — star field + two spiral arms ─────────────────────────
      case 'galaxy':
        fillPaint.color = pal.bladeLight.withOpacity(0.60);
        for (var i = 0; i < 130; i++) {
          canvas.drawCircle(
            Offset(rngA.nextDouble() * size.width,
                rngA.nextDouble() * size.height),
            rngA.nextDouble() * 1.4 + 0.3,
            fillPaint,
          );
        }
        linePaint
          ..color = pal.bladeMid.withOpacity(0.16)
          ..strokeWidth = 1.6;
        for (var arm = 0; arm < 2; arm++) {
          final offset = arm * math.pi;
          final path = Path();
          var first = true;
          for (var t = 0.0; t < 4 * math.pi; t += 0.07) {
            final r = t * size.width * 0.06;
            final x = center.dx + math.cos(t + offset) * r;
            final y = center.dy + math.sin(t + offset) * r;
            if (first) {
              path.moveTo(x, y);
              first = false;
            } else {
              path.lineTo(x, y);
            }
          }
          canvas.drawPath(path, linePaint);
        }

      // ── obsidian — jagged cracks from centre ──────────────────────────
      case 'obsidian':
        linePaint
          ..color = pal.rimInner.withOpacity(0.30)
          ..strokeWidth = 0.9;
        for (var crack = 0; crack < 9; crack++) {
          var angle = crack * math.pi * 2 / 9;
          var x = center.dx;
          var y = center.dy;
          final path = Path()..moveTo(x, y);
          for (var step = 0; step < 10; step++) {
            angle += (rngA.nextDouble() - 0.5) * 0.9;
            x += math.cos(angle) * size.width * 0.095;
            y += math.sin(angle) * size.height * 0.095;
            path.lineTo(x, y);
            if (rngA.nextDouble() < 0.3 && step > 3) {
              final ba = angle + (rngA.nextDouble() - 0.5) * 1.2;
              path
                ..lineTo(
                    x + math.cos(ba) * size.width * 0.055,
                    y + math.sin(ba) * size.height * 0.055)
                ..moveTo(x, y);
            }
          }
          canvas.drawPath(path, linePaint);
        }
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
      // Draw per-skin unique pattern (only when no custom image)
      _drawSkinPattern(canvas, size, rect, center, pal);
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

// ── Store preview widget ──────────────────────────────────────────────────────
// Shows the iris at a fixed 45 % open so blade colours AND the centre
// image (mandala etc.) are simultaneously visible.

class CardSkinPreview extends StatefulWidget {
  final String cardSkinId;
  /// Optional full skin — when provided, network coverImageUrl is used.
  final CardSkin? skin;

  const CardSkinPreview({super.key, required this.cardSkinId, this.skin});

  @override
  State<CardSkinPreview> createState() => _CardSkinPreviewState();
}

class _CardSkinPreviewState extends State<CardSkinPreview> {
  ui.Image? _skinImage;

  @override
  void initState() {
    super.initState();
    _loadImage(widget.cardSkinId);
  }

  @override
  void didUpdateWidget(covariant CardSkinPreview old) {
    super.didUpdateWidget(old);
    if (widget.cardSkinId != old.cardSkinId ||
        widget.skin?.coverImageUrl != old.skin?.coverImageUrl) {
      _loadImage(widget.cardSkinId);
    }
  }

  Future<void> _loadImage(String skinId) async {
    final skin = widget.skin ??
        kAvailableCardSkins.firstWhere(
          (s) => s.id == skinId,
          orElse: () => kAvailableCardSkins.first,
        );

    // Network image takes priority
    if (skin.coverImageUrl != null) {
      final image = await _fetchNetworkUiImage(skin.coverImageUrl!);
      if (mounted) setState(() => _skinImage = image);
      return;
    }

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
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _AperturePainter(
          progress: 0.45,
          cardSkinId: widget.cardSkinId,
          skinImage: _skinImage,
        ),
      ),
    );
  }
}
