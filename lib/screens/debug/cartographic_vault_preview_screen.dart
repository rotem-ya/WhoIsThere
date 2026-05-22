// TEMP DEBUG — continuous-image board visual prototype v6 (DSLR aperture iris).
// Remove before merging vault visuals to production.
// Does NOT touch GameBoardScreen, game_board_view.dart, ApertureTile, or any gameplay code.

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

const String _kImage = 'assets/game_places/images/masada.jpg';
const Set<int> _kInitialRevealed = {0, 1, 5, 6, 7, 10, 12};
const int _kCols = 5;
const int _kRows = 5;
const double _kSeam = 1.5;
const Duration _kRevealDuration = Duration(milliseconds: 210);

class CartographicVaultPreviewScreen extends StatefulWidget {
  const CartographicVaultPreviewScreen({super.key});

  @override
  State<CartographicVaultPreviewScreen> createState() =>
      _CartographicVaultPreviewScreenState();
}

class _CartographicVaultPreviewScreenState
    extends State<CartographicVaultPreviewScreen>
    with TickerProviderStateMixin {
  final Set<int> _revealed = Set.from(_kInitialRevealed);
  final Map<int, AnimationController> _controllers = {};
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
                  Image.asset(_kImage, fit: BoxFit.cover),
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

    // Everything inside this layer forms the solid mask over the image.
    canvas.saveLayer(bounds, Paint());

    // 1. Draw the base mechanical board surface (opaque graphite)
    canvas.drawRect(bounds, Paint()..color = const Color(0xFF071221));

    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.05),
            Colors.transparent,
            Colors.black.withOpacity(0.20),
          ],
          stops: const [0.0, 0.40, 1.0],
        ).createShader(bounds),
    );

    // Subtle brushed metal texture
    final brushPaint = Paint()
      ..color = Colors.white.withOpacity(0.015)
      ..strokeWidth = 0.55;
    for (var y = 1.5; y < size.height; y += 3.0) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), brushPaint);
    }

    final clearPaint = Paint()..blendMode = BlendMode.clear;

    // 2. Clear holes for fully revealed cells (exposing image)
    for (var idx = 0; idx < rows * cols; idx++) {
      if (revealed.contains(idx) && !animProgress.containsKey(idx)) {
        canvas.drawRect(_cell(idx ~/ cols, idx % cols), clearPaint);
      }
    }

    // 3. Draw mechanical aperture blades for animating cells
    for (final entry in animProgress.entries) {
      final idx = entry.key;
      final p = entry.value;

      if (p <= 0.001 || !revealed.contains(idx)) continue;

      final cell = _cell(idx ~/ cols, idx % cols);

      canvas.save();
      canvas.clipRect(cell);

      // Clear the entire cell area first.
      // This ensures the image underneath is exposed in the center hole.
      canvas.drawRect(cell, clearPaint);

      // Now draw the overlapping graphite blades inside the cleared cell.
      // Where the blades paint, they act as the opaque mask covering the image.
      const int blades = 8;

      // Add mechanical easing: fast initial snap, then slow glide
      final double easeP = Curves.easeOutQuart.transform(p);

      // Blades twist open by 90 degrees as they retract
      final double twist = (1.0 - easeP) * (math.pi / 2);

      // Apothem max must safely clear the cell corners (sqrt(2)/2 ≈ 0.707)
      final double maxD = cell.width * 0.85;
      final double d = easeP * maxD;

      // Helper function to draw a single blade
      void drawBlade(int i, bool isWovenRedraw) {
        final double midT = (i + 0.5) * (2 * math.pi / blades) + twist;

        // M: midpoint of the blade's inner edge
        final Offset M =
            cell.center + Offset(d * math.cos(midT), d * math.sin(midT));

        // E: direction vector running ALONG the blade's inner edge
        final Offset E = Offset(-math.sin(midT), math.cos(midT));

        // N: normal vector pointing OUTWARD from the center
        final Offset N = Offset(math.cos(midT), math.sin(midT));

        // To fix cyclic overlap (blade 8 sitting on top of blade 1),
        // we redraw blade 1, but clipped strictly to its angular sector.
        if (isWovenRedraw) {
          canvas.save();
          final sector = Path()
            ..moveTo(cell.center.dx, cell.center.dy)
            ..lineTo(
                cell.center.dx +
                    cell.width * 2 * math.cos(midT - math.pi / blades),
                cell.center.dy +
                    cell.width * 2 * math.sin(midT - math.pi / blades))
            ..lineTo(
                cell.center.dx +
                    cell.width * 2 * math.cos(midT + math.pi / blades),
                cell.center.dy +
                    cell.width * 2 * math.sin(midT + math.pi / blades))
            ..close();
          canvas.clipPath(sector);
        }

        // The blade polygon (an oversized rectangle facing outward)
        final Path bladePath = Path()
          ..moveTo(
              (M - E * cell.width * 2).dx, (M - E * cell.width * 2).dy)
          ..lineTo(
              (M + E * cell.width * 2).dx, (M + E * cell.width * 2).dy)
          ..lineTo((M + E * cell.width * 2 + N * cell.width * 2).dx,
              (M + E * cell.width * 2 + N * cell.width * 2).dy)
          ..lineTo((M - E * cell.width * 2 + N * cell.width * 2).dx,
              (M - E * cell.width * 2 + N * cell.width * 2).dy)
          ..close();

        // Mechanical drop shadow from overlapping blades
        canvas.drawPath(
          bladePath.shift(N * -3.0 + E * 3.0),
          Paint()
            ..color = Colors.black.withOpacity(0.7)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
        );

        // Glossy graphite blade body
        final shader = ui.Gradient.linear(
          M,
          M + N * (cell.width * 0.6),
          [
            const Color(0xFF263142), // Lighter metallic edge
            const Color(0xFF040911), // Deep graphite base
          ],
        );
        canvas.drawPath(bladePath, Paint()..shader = shader);

        // Crisp precision highlight on the physical inner edge
        canvas.drawLine(
          M - E * cell.width * 2,
          M + E * cell.width * 2,
          Paint()
            ..color = Colors.white.withOpacity(0.4)
            ..strokeWidth = 0.8,
        );

        if (isWovenRedraw) {
          canvas.restore();
        }
      }

      // Draw all 8 blades
      for (int i = 0; i < blades; i++) {
        drawBlade(i, false);
      }

      // Redraw the first blade clipped to its sector to create a perfect woven iris
      drawBlade(0, true);

      canvas.restore();
    }

    // End masking layer composite
    canvas.restore();

    // 4. Draw seamless panel grid lines (no floating 3D tiles)
    final seamPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 0.6;

    for (var c = 1; c < cols; c++) {
      final x = c * (cellSize + seam) - seam * 0.5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), seamPaint);
    }
    for (var r = 1; r < rows; r++) {
      final y = r * (cellSize + seam) - seam * 0.5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), seamPaint);
    }

    // 5. Draw premium gunmetal rims around fully opened cells
    for (var idx = 0; idx < rows * cols; idx++) {
      if (revealed.contains(idx) && !animProgress.containsKey(idx)) {
        final cell = _cell(idx ~/ cols, idx % cols);

        // Inner shadow edge
        canvas.drawRect(
            cell,
            Paint()
              ..color = Colors.black.withOpacity(0.5)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0);

        // Crisp chrome/gunmetal sub-pixel highlight
        canvas.drawRect(
            cell,
            Paint()
              ..color = Colors.white.withOpacity(0.18)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.6);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ShutterMask old) => true;
}

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
