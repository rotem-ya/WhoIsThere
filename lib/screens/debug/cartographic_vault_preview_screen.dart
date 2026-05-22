// TEMP DEBUG — continuous-image board visual prototype v5 (aperture iris).
// Remove before merging vault visuals to production.
// Does NOT touch GameBoardScreen, game_board_view.dart, ApertureTile, or any gameplay code.

import 'dart:math' as math;
import 'package:flutter/material.dart';

const String _kImage = 'assets/game_places/images/masada.jpg';
const Set<int> _kInitialRevealed = {0, 1, 5, 6, 7, 10, 12};
const int _kCols = 5;
const int _kRows = 5;
const double _kSeam = 1.5;
const Duration _kRevealDuration = Duration(milliseconds: 210);

// ── Iris geometry ─────────────────────────────────────────────────────────────
// 6-blade hexagonal aperture that grows AND rotates as it opens,
// matching the mechanics of a real camera iris diaphragm.
const int _kBlades = 6;
// Circumradius multiple at progress=1 — must exceed half-diagonal (√2/2 ≈ 0.707).
// At 0.84 the blade tips clear all four cell corners. ✓
const double _kMaxR = 0.84;
// Total twist over the full animation: one blade pitch = 2π/N.
// Blades "unwind" as they retract, matching physical aperture rotation.
const double _kTwist = math.pi / _kBlades; // π/6 = 30°

// Builds the 6-gon iris aperture polygon.
// progress 0.0 → point at centre (fully closed)
// progress 1.0 → hexagon whose inscribed circle covers the cell square
Path _irisPath(Offset center, double cellSize, double progress) {
  final r = cellSize * _kMaxR * progress;
  // Twist decreases as iris opens — blades rotate outward as they retract.
  final twist = _kTwist * (1.0 - progress);

  final path = Path();
  for (var i = 0; i < _kBlades; i++) {
    final angle = 2 * math.pi * i / _kBlades + twist;
    final pt = Offset(
      center.dx + r * math.cos(angle),
      center.dy + r * math.sin(angle),
    );
    if (i == 0) path.moveTo(pt.dx, pt.dy);
    else path.lineTo(pt.dx, pt.dy);
  }
  path.close();
  return path;
}

// ─────────────────────────────────────────────────────────────────────────────

class CartographicVaultPreviewScreen extends StatefulWidget {
  const CartographicVaultPreviewScreen({super.key});

  @override
  State<CartographicVaultPreviewScreen> createState() =>
      _CartographicVaultPreviewScreenState();
}

class _CartographicVaultPreviewScreenState
    extends State<CartographicVaultPreviewScreen>
    with TickerProviderStateMixin {
  // Cells that are fully open (animation complete).
  final Set<int> _revealed = Set.from(_kInitialRevealed);
  // Per-cell animation controllers (discarded after animation completes).
  final Map<int, AnimationController> _controllers = {};
  // Current iris-open progress per animating cell: 0.0 = closed, 1.0 = open.
  final Map<int, double> _progress = {};

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  void _tap(int idx) {
    if (_controllers.containsKey(idx)) return; // ignore while animating

    final opening = !_revealed.contains(idx);

    final ctrl = AnimationController(vsync: this, duration: _kRevealDuration);
    // easeOut = aperture snaps open quickly then settles.
    // easeIn  = aperture releases slowly then snaps shut.
    final curved = CurvedAnimation(
      parent: ctrl,
      curve: opening ? Curves.easeOut : Curves.easeIn,
    );

    curved.addListener(() {
      if (!mounted) return;
      setState(() {
        _progress[idx] = opening ? curved.value : 1.0 - curved.value;
      });
    });

    setState(() {
      if (opening) _revealed.add(idx);
      _controllers[idx] = ctrl;
      _progress[idx] = opening ? 0.0 : 1.0;
    });

    ctrl.forward().then((_) {
      if (!mounted) return; // dispose() already cleaned up ctrl
      setState(() {
        if (!opening) _revealed.remove(idx);
        _progress.remove(idx);
        _controllers.remove(idx);
      });
      ctrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080F1E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _Atmosphere(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  revealed: _revealed.length,
                  total: _kCols * _kRows,
                  onBack: () => Navigator.maybePop(context),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                    child: _BoardArea(
                      revealed: Set.from(_revealed),
                      animProgress: Map.from(_progress),
                      onTap: _tap,
                    ),
                  ),
                ),
                const _Hint(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Atmosphere ────────────────────────────────────────────────────────────────

class _Atmosphere extends StatelessWidget {
  const _Atmosphere();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0C1A2E), Color(0xFF0E2444), Color(0xFF080F1E)],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.0, -0.5),
              radius: 0.90,
              colors: [
                const Color(0xFF1A4060).withOpacity(0.38),
                Colors.transparent,
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.85, 0.85),
              radius: 0.55,
              colors: [
                const Color(0xFFD4AF37).withOpacity(0.07),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int revealed;
  final int total;
  final VoidCallback onBack;

  const _Header({
    required this.revealed,
    required this.total,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 15,
                color: Colors.white60,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'תצוגת לוח',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Text(
              '$revealed / $total',
              style: TextStyle(
                color: Colors.white.withOpacity(0.38),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Board area ────────────────────────────────────────────────────────────────

class _BoardArea extends StatelessWidget {
  final Set<int> revealed;
  final Map<int, double> animProgress;
  final void Function(int) onTap;

  const _BoardArea({
    required this.revealed,
    required this.animProgress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = math.min(constraints.maxWidth, constraints.maxHeight);
      final cellSize = (size - _kSeam * (_kCols - 1)) / _kCols;

      return Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: size,
            height: size,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                final col = (d.localPosition.dx / (cellSize + _kSeam))
                    .floor()
                    .clamp(0, _kCols - 1);
                final row = (d.localPosition.dy / (cellSize + _kSeam))
                    .floor()
                    .clamp(0, _kRows - 1);
                onTap(row * _kCols + col);
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Layer 1 — continuous image, full board.
                  Image.asset(_kImage, fit: BoxFit.cover),
                  // Layer 2 — shutter mask with aperture iris animation.
                  CustomPaint(
                    painter: _ShutterMask(
                      revealed: revealed,
                      animProgress: animProgress,
                      cols: _kCols,
                      rows: _kRows,
                      cellSize: cellSize,
                      seam: _kSeam,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

// ── Shutter mask with camera-iris aperture ────────────────────────────────────
//
// Paint order
// ──────────────────────────────────────────────────────────────────────────────
// [saveLayer]
//   1. Dark base fill   — fully opaque, image invisible under closed cells
//   2. Directional gradient — soft top-left light source
//   3. Brushed-metal texture — horizontal hairlines
//   4. BlendMode.clear  — full rect for fully open cells
//   5. BlendMode.clear  — iris polygon for animating cells
// [restore]
//   6. Inner bevel on fully covered cells (top/left highlight, bottom/right shadow)
//   7. Hairline seam grid across the whole board
//   8. Gold cut-edge on fully open apertures
//   9. Per animating cell:
//      a. clip to cell rect
//      b. evenOdd clip (cell minus iris polygon) → draw dark graphite blade body
//         with matching directional sheen — blades look like physical objects
//      c. thin specular stroke along the iris polygon — metallic blade-edge glint
// ──────────────────────────────────────────────────────────────────────────────

class _ShutterMask extends CustomPainter {
  final Set<int> revealed;
  final Map<int, double> animProgress;
  final int cols;
  final int rows;
  final double cellSize;
  final double seam;

  _ShutterMask({
    required this.revealed,
    required this.animProgress,
    required this.cols,
    required this.rows,
    required this.cellSize,
    required this.seam,
  });

  Rect _cell(int row, int col) => Rect.fromLTWH(
        col * (cellSize + seam),
        row * (cellSize + seam),
        cellSize,
        cellSize,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;

    // ── Steps 1-5: unified mask layer ─────────────────────────────────────
    canvas.saveLayer(bounds, Paint());

    // 1. Base fill — dark steel-blue, FULLY OPAQUE.
    //    The image is completely invisible beneath any covered cell.
    canvas.drawRect(bounds, Paint()..color = const Color(0xFF07152A));

    // 2. Directional gradient — single light source from top-left creates
    //    the illusion that the shutter surface has slight convexity.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.07),
            Colors.transparent,
            Colors.black.withOpacity(0.14),
          ],
          stops: const [0.0, 0.40, 1.0],
        ).createShader(bounds),
    );

    // 3. Horizontal brushed-metal texture — fine parallel lines
    //    at 2.2% opacity simulate a horizontally-machined steel surface.
    final brushPaint = Paint()
      ..color = Colors.white.withOpacity(0.022)
      ..strokeWidth = 0.55;
    for (var y = 1.5; y < size.height; y += 4.0) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), brushPaint);
    }

    final clearPaint = Paint()..blendMode = BlendMode.clear;

    // 4. Clear full rect for fully open cells.
    for (var idx = 0; idx < rows * cols; idx++) {
      if (revealed.contains(idx) && !animProgress.containsKey(idx)) {
        canvas.drawRect(_cell(idx ~/ cols, idx % cols), clearPaint);
      }
    }

    // 5. Clear iris polygon for animating cells.
    //    The polygon grows and rotates — at partial progress it creates
    //    the characteristic polygonal camera-iris aperture opening.
    for (final entry in animProgress.entries) {
      final idx = entry.key;
      final p = entry.value;
      if (p > 0.001 && revealed.contains(idx)) {
        final cell = _cell(idx ~/ cols, idx % cols);
        canvas.drawPath(_irisPath(cell.center, cell.width, p), clearPaint);
      }
    }

    canvas.restore();

    // ── Step 6: inner bevel on fully covered cells ─────────────────────────
    for (var idx = 0; idx < rows * cols; idx++) {
      if (revealed.contains(idx)) continue;
      final r = _cell(idx ~/ cols, idx % cols);

      // Top inner highlight — brightest edge (light source above)
      canvas.drawLine(
        Offset(r.left + 0.5, r.top + 0.5),
        Offset(r.right - 0.5, r.top + 0.5),
        Paint()
          ..color = Colors.white.withOpacity(0.18)
          ..strokeWidth = 0.9,
      );
      // Left inner highlight
      canvas.drawLine(
        Offset(r.left + 0.5, r.top + 1.0),
        Offset(r.left + 0.5, r.bottom - 0.5),
        Paint()
          ..color = Colors.white.withOpacity(0.10)
          ..strokeWidth = 0.9,
      );
      // Bottom inner shadow
      canvas.drawLine(
        Offset(r.left + 0.5, r.bottom - 0.5),
        Offset(r.right - 0.5, r.bottom - 0.5),
        Paint()
          ..color = Colors.black.withOpacity(0.38)
          ..strokeWidth = 0.9,
      );
      // Right inner shadow
      canvas.drawLine(
        Offset(r.right - 0.5, r.top + 1.0),
        Offset(r.right - 0.5, r.bottom - 0.5),
        Paint()
          ..color = Colors.black.withOpacity(0.26)
          ..strokeWidth = 0.9,
      );
    }

    // ── Step 7: hairline seam grid ──────────────────────────────────────────
    // Runs across the full board including open cells —
    // the board reads as one unified surface.
    final seamPaint = Paint()
      ..color = Colors.white.withOpacity(0.09)
      ..strokeWidth = 0.6;
    for (var c = 1; c < cols; c++) {
      final x = c * (cellSize + seam) - seam * 0.5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), seamPaint);
    }
    for (var r = 1; r < rows; r++) {
      final y = r * (cellSize + seam) - seam * 0.5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), seamPaint);
    }

    // ── Step 8: gold cut-edge on fully open cells ───────────────────────────
    final goldEdge = Paint()
      ..color = const Color(0xFFD4AF37).withOpacity(0.50)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;
    for (var idx = 0; idx < rows * cols; idx++) {
      if (revealed.contains(idx) && !animProgress.containsKey(idx)) {
        canvas.drawRect(_cell(idx ~/ cols, idx % cols), goldEdge);
      }
    }

    // ── Step 9: blade body + specular for animating cells ──────────────────
    //
    // For each cell mid-animation, draw the physical blade geometry on top:
    //   a. clip canvas to cell rect
    //   b. further clip to evenOdd (cell - iris polygon) = blade-body area
    //   c. draw dark graphite fill + directional sheen — blades look physical
    //   d. release evenOdd clip, draw specular stroke on iris polygon edge
    //      (the blade tips catch the overhead light as they rotate)
    for (final entry in animProgress.entries) {
      final idx = entry.key;
      final p = entry.value;
      if (p <= 0.001 || !revealed.contains(idx)) continue;

      final cell = _cell(idx ~/ cols, idx % cols);
      final iris = _irisPath(cell.center, cell.width, p);

      canvas.save();
      canvas.clipRect(cell); // outer boundary — nothing outside the cell

      // Blade-body clip: cell rect minus iris polygon via even-odd fill.
      // Points inside the cell but outside the iris = blade body area.
      final bladeClip = Path()
        ..addRect(cell)
        ..addPath(iris, Offset.zero);
      bladeClip.fillType = PathFillType.evenOdd;

      canvas.save();
      canvas.clipPath(bladeClip); // restrict drawing to blade body only

      // Dark graphite blade body — fractionally cooler/darker than the main
      // mask to give the blades a separate material feel.
      canvas.drawRect(cell, Paint()..color = const Color(0xFF060D1A));

      // Directional sheen matching the main mask light source — the blade
      // surfaces catch the same overhead light consistently.
      canvas.drawRect(
        cell,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.09),
              Colors.transparent,
              Colors.black.withOpacity(0.13),
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(cell),
      );

      canvas.restore(); // release blade-body clip

      // Specular stroke along the iris polygon perimeter —
      // the inner edge of each blade tip catches the light as it rotates.
      // Opacity ramps quickly at the start of the animation so the glint is
      // most visible when the iris first starts to open.
      final specularOpacity = 0.24 * math.min(1.0, p * 2.0);
      canvas.drawPath(
        iris,
        Paint()
          ..color = Colors.white.withOpacity(specularOpacity)
          ..strokeWidth = 1.1
          ..style = PaintingStyle.stroke,
      );

      canvas.restore(); // release cell clipRect
    }
  }

  // Always repaint during animation; idle frames are zero-cost.
  @override
  bool shouldRepaint(covariant _ShutterMask old) => true;
}

// ── Hint ──────────────────────────────────────────────────────────────────────

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Center(
        child: Text(
          'גע לחשיפה',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: Colors.white.withOpacity(0.20),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}
