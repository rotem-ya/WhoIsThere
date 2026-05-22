// TEMP DEBUG — continuous-image board visual prototype v4.
// Remove before merging vault visuals to production.
// Does NOT touch GameBoardScreen, game_board_view.dart, ApertureTile, or any gameplay code.

import 'dart:math' as math;
import 'package:flutter/material.dart';

const String _kImage = 'assets/game_places/images/masada.jpg';
const Set<int> _kInitialRevealed = {0, 1, 5, 6, 7, 10, 12};
const int _kCols = 5;
const int _kRows = 5;
const double _kSeam = 1.5;
// Short, tactile reveal duration — feels mechanical, not animated.
const Duration _kRevealDuration = Duration(milliseconds: 190);

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
  // Controllers for cells currently mid-animation.
  final Map<int, AnimationController> _controllers = {};
  // Current hole-scale progress per animating cell: 0.0 = closed, 1.0 = open.
  final Map<int, double> _progress = {};

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  void _tap(int idx) {
    if (_controllers.containsKey(idx)) return; // already animating

    final opening = !_revealed.contains(idx);

    final ctrl = AnimationController(vsync: this, duration: _kRevealDuration);
    final curved = CurvedAnimation(
      parent: ctrl,
      // easeOut = snaps open quickly then settles.
      // easeIn  = releases slowly then snaps shut.
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
        // Base: midnight blue → deep steel blue — NOT black.
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
        // Cyan atmospheric bloom — upper centre.
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
        // Warm gold exhale — bottom-left corner.
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
                  // Layer 1 — continuous image, fills entire board.
                  Image.asset(_kImage, fit: BoxFit.cover),
                  // Layer 2 — unified shutter mask with mechanical depth.
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

// ── Unified shutter mask ──────────────────────────────────────────────────────
//
// Single CustomPainter covers the full board.
//
// Paint order:
//   [saveLayer]
//     1. Dark steel-blue base fill — covers entire board, fully opaque
//     2. Directional gradient overlay — soft light from top-left
//     3. Horizontal brushed-metal lines — subtle surface texture
//     4. BlendMode.clear punches transparent holes for revealed cells
//        — fully open cells: full cell rect cleared
//        — animating cells: centered iris rect scaled by progress
//   [restore]
//   5. Inner bevel on fully covered cells (top+left white, bottom+right black)
//   6. Hairline seam grid across entire board
//   7. Gold cut-edge around open apertures
//
// Covered cells receive ZERO transparency — image is invisible under them.

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

    // ── Layer: unified shutter with punched apertures ─────────────────────
    canvas.saveLayer(bounds, Paint());

    // 1. Base fill — dark steel-blue. Fully opaque; image invisible here.
    canvas.drawRect(
      bounds,
      Paint()..color = const Color(0xFF07152A),
    );

    // 2. Soft directional light from top-left — implies a single overhead
    //    light source, gives the panel a slight convex/curved feel.
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

    // 3. Horizontal brushed-metal texture — very faint parallel lines
    //    simulate a horizontally brushed aluminium/steel surface.
    //    Low opacity and tight spacing keep it subtle, not noisy.
    final brushPaint = Paint()
      ..color = Colors.white.withOpacity(0.022)
      ..strokeWidth = 0.55;
    for (double y = 1.5; y < size.height; y += 4.0) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), brushPaint);
    }

    // 4. Punch holes.
    final clearPaint = Paint()..blendMode = BlendMode.clear;

    // Fully open cells — clear entire cell rect.
    for (var idx = 0; idx < rows * cols; idx++) {
      if (revealed.contains(idx) && !animProgress.containsKey(idx)) {
        canvas.drawRect(_cell(idx ~/ cols, idx % cols), clearPaint);
      }
    }

    // Animating cells — clear a centered iris scaled by progress.
    // The iris grows/shrinks vertically from the cell's horizontal midline,
    // like two blast-door panels sliding apart or sealing shut.
    for (final entry in animProgress.entries) {
      final idx = entry.key;
      final p = entry.value; // 0.0 = fully closed, 1.0 = fully open
      if (p > 0.001 && revealed.contains(idx)) {
        final cell = _cell(idx ~/ cols, idx % cols);
        canvas.drawRect(
          Rect.fromCenter(
            center: cell.center,
            width: cell.width,
            height: cell.height * p,
          ),
          clearPaint,
        );
      }
    }

    canvas.restore();

    // ── Inner bevel — covered cells only ─────────────────────────────────
    // Four hairlines per cell (top/left highlight, bottom/right shadow)
    // create an inset bevel — the plate reads as a slightly recessed panel.
    for (var idx = 0; idx < rows * cols; idx++) {
      if (revealed.contains(idx)) continue;
      final r = _cell(idx ~/ cols, idx % cols);

      // Top inner highlight
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

    // ── Hairline seam grid ────────────────────────────────────────────────
    // Runs across the entire board including open cells — keeps the board
    // reading as one unified surface even when tiles are revealed.
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

    // ── Gold cut-edge on open apertures ───────────────────────────────────
    // Thin gold stroke marks revealed openings — reads as a precision-cut
    // aperture edge, premium and restrained.
    final goldEdge = Paint()
      ..color = const Color(0xFFD4AF37).withOpacity(0.50)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;

    for (var idx = 0; idx < rows * cols; idx++) {
      if (!revealed.contains(idx)) continue;
      final cell = _cell(idx ~/ cols, idx % cols);
      if (animProgress.containsKey(idx)) {
        final p = animProgress[idx]!;
        if (p > 0.001) {
          canvas.drawRect(
            Rect.fromCenter(
              center: cell.center,
              width: cell.width,
              height: cell.height * p,
            ),
            goldEdge,
          );
        }
      } else {
        canvas.drawRect(cell, goldEdge);
      }
    }
  }

  // Always repaint during animation; no-op frames are cheap.
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
