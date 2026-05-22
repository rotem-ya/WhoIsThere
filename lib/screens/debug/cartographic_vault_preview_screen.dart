// TEMP DEBUG — continuous-image board visual prototype v6 (overlapping shutter blades).
// Remove before merging vault visuals to production.
// Does NOT touch GameBoardScreen, game_board_view.dart, ApertureTile, or any gameplay code.

import 'dart:math' as math;
import 'package:flutter/material.dart';

const String _kImage = 'assets/game_places/images/masada.jpg';
const Set<int> _kInitialRevealed = {0, 1, 5, 6, 7, 10, 12};
const int _kCols = 5;
const int _kRows = 5;
const double _kSeam = 1.5;
const Duration _kRevealDuration = Duration(milliseconds: 220);

// ── Blade geometry ────────────────────────────────────────────────────────────
const int    _kBlades   = 7;
const double _kPivotR   = 0.40;           // pivot ring radius / cellSize
const double _kBladeLen = 0.88;           // blade length / cellSize
const double _kBladeW   = 0.36;           // blade width / cellSize
const double _kSweep    = math.pi * 0.82; // total sweep from closed→open (~148°)
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
  // Cells that are open (fully revealed or currently opening/closing).
  final Set<int> _revealed = Set.from(_kInitialRevealed);
  // Per-cell animation controllers, discarded once complete.
  final Map<int, AnimationController> _controllers = {};
  // Blade-open progress: 0.0 = blades fully covering cell, 1.0 = blades swept away.
  final Map<int, double> _progress = {};

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  void _tap(int idx) {
    if (_controllers.containsKey(idx)) return;
    final opening = !_revealed.contains(idx);
    final ctrl = AnimationController(vsync: this, duration: _kRevealDuration);
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
      if (!mounted) return;
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
                  // Layer 2 — shutter mask with overlapping blade animation.
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

// ── Shutter mask with overlapping camera-shutter blades ───────────────────────
//
// Paint order
// ─────────────────────────────────────────────────────────────────────────────
// [saveLayer]
//   1. Dark base fill — fully opaque, image hidden beneath covered cells
//   2. Directional gradient — top-left light source, global convexity illusion
//   3. Brushed-metal texture — horizontal hairlines
//   4. BlendMode.clear — full cell rect for ALL revealed cells
//      (both mid-animation and fully open — blades drawn on top for the former)
// [restore]
//   5. Thin frame stroke on fully covered cells
//   6. Hairline seam grid across the full board
//   7. Gold cut-edge on fully open (non-animating) cells
//   8. Per animating opening cell: _drawBlades — N=7 overlapping graphite
//      shutter blades clipped to the cell rect, rotating from closed to open
// ─────────────────────────────────────────────────────────────────────────────

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

    // ── Steps 1-4: unified mask saveLayer ────────────────────────────────────
    canvas.saveLayer(bounds, Paint());

    // 1. Fully opaque dark base.
    canvas.drawRect(bounds, Paint()..color = const Color(0xFF07152A));

    // 2. Directional gradient — single light source from top-left.
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

    // 3. Brushed-metal horizontal hairlines.
    final brushPaint = Paint()
      ..color = Colors.white.withOpacity(0.022)
      ..strokeWidth = 0.55;
    for (var y = 1.5; y < size.height; y += 4.0) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), brushPaint);
    }

    // 4. Clear ALL revealed cells so the image shows through.
    //    Mid-animation cells get the same full clear; the blades drawn after
    //    restore provide the coverage at partial progress.
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    for (var idx = 0; idx < rows * cols; idx++) {
      if (revealed.contains(idx)) {
        canvas.drawRect(_cell(idx ~/ cols, idx % cols), clearPaint);
      }
    }

    canvas.restore();

    // ── Step 5: thin frame on fully covered cells ─────────────────────────────
    final framePaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;
    for (var idx = 0; idx < rows * cols; idx++) {
      if (!revealed.contains(idx)) {
        canvas.drawRect(_cell(idx ~/ cols, idx % cols).deflate(0.5), framePaint);
      }
    }

    // ── Step 6: hairline seam grid across full board ──────────────────────────
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

    // ── Step 7: gold cut-edge on fully open cells ─────────────────────────────
    final goldEdge = Paint()
      ..color = const Color(0xFFD4AF37).withOpacity(0.50)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;
    for (var idx = 0; idx < rows * cols; idx++) {
      if (revealed.contains(idx) && !animProgress.containsKey(idx)) {
        canvas.drawRect(_cell(idx ~/ cols, idx % cols), goldEdge);
      }
    }

    // ── Step 8: overlapping shutter blades for animating cells ────────────────
    for (final entry in animProgress.entries) {
      final idx = entry.key;
      final p = entry.value;
      // Only draw blades while the cell is in the revealed set
      // (opening: cell added immediately; closing: cell still in set until end).
      if (!revealed.contains(idx)) continue;
      _drawBlades(canvas, _cell(idx ~/ cols, idx % cols), p);
    }
  }

  // Draws N=7 overlapping graphite shutter blades for one cell at open-progress p.
  //   p = 0.0 → blades closed, covering the cell
  //   p = 1.0 → blades swept away, cell fully exposed
  void _drawBlades(Canvas canvas, Rect cell, double progress) {
    final cx = cell.center.dx;
    final cy = cell.center.dy;
    final s = cell.width;
    final R = s * _kPivotR;    // pivot ring radius from cell center
    final L = s * _kBladeLen;  // blade body length
    final W = s * _kBladeW;    // blade body width
    final cr = W * 0.42;       // rounded corner radius on blade ends

    canvas.save();
    canvas.clipRect(cell); // blades never render outside their cell

    // Draw from last blade to first so blade 0 sits on top of blade 6 —
    // matching the physical stacking order of a real iris diaphragm.
    for (var i = _kBlades - 1; i >= 0; i--) {
      final base = 2 * math.pi * i / _kBlades;

      // The pivot ring itself rotates slightly as the aperture opens,
      // matching the physical rotation of the iris ring in a real lens.
      final pivotAngle = base + progress * (math.pi / _kBlades * 0.55);
      final px = cx + R * math.cos(pivotAngle);
      final py = cy + R * math.sin(pivotAngle);

      // At p=0: blade points from pivot toward cell center (pivotAngle + π).
      // At p=1: blade has swept _kSweep radians counterclockwise.
      final bladeAngle = pivotAngle + math.pi + progress * _kSweep;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(bladeAngle);

      // Blade body: rounded rect starting at pivot (t=0), extending length L.
      final rect = Rect.fromLTWH(0.0, -W * 0.5, L, W);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(cr));

      // Alternate between two very close graphite tones for z-stack depth.
      final fill = i.isEven ? const Color(0xFF0A1018) : const Color(0xFF0F1A24);
      canvas.drawRRect(rr, Paint()..color = fill);

      // Leading-edge specular — the top surface of each blade catches overhead
      // light and shows a thin bright line along its length.
      canvas.drawLine(
        Offset(cr, -W * 0.5 + 0.75),
        Offset(L - cr * 0.6, -W * 0.5 + 0.75),
        Paint()
          ..color = Colors.white.withOpacity(0.20)
          ..strokeWidth = 0.85,
      );

      // Trailing-edge shadow — the underside of the blade in shadow.
      canvas.drawLine(
        Offset(cr, W * 0.5 - 0.85),
        Offset(L - cr * 0.6, W * 0.5 - 0.85),
        Paint()
          ..color = Colors.black.withOpacity(0.28)
          ..strokeWidth = 0.7,
      );

      canvas.restore();
    }

    canvas.restore();
  }

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
