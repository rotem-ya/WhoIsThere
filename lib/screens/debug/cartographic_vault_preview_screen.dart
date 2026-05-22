// TEMP DEBUG — continuous-image board visual prototype v3.
// Remove before merging vault visuals to production.
// Does NOT touch GameBoardScreen, game_board_view.dart, ApertureTile, or any gameplay code.

import 'dart:math' as math;
import 'package:flutter/material.dart';

const String _kImage = 'assets/game_places/images/masada.jpg';
const Set<int> _kInitialRevealed = {0, 1, 5, 6, 7, 10, 12};
const int _kCols = 5;
const int _kRows = 5;
// Hairline seam between cells — thin enough to feel like one board.
const double _kSeam = 1.5;

class CartographicVaultPreviewScreen extends StatefulWidget {
  const CartographicVaultPreviewScreen({super.key});

  @override
  State<CartographicVaultPreviewScreen> createState() =>
      _CartographicVaultPreviewScreenState();
}

class _CartographicVaultPreviewScreenState
    extends State<CartographicVaultPreviewScreen> {
  final Set<int> _revealed = Set.from(_kInitialRevealed);

  void _toggleCell(int idx) {
    setState(() {
      if (_revealed.contains(idx)) {
        _revealed.remove(idx);
      } else {
        _revealed.add(idx);
      }
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
                      onTap: _toggleCell,
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
// Midnight blue → deep steel blue — deliberately NOT black.

class _Atmosphere extends StatelessWidget {
  const _Atmosphere();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base gradient: midnight blue → steel blue → dark navy
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0C1A2E),
                Color(0xFF0E2444),
                Color(0xFF080F1E),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        // Cyan atmospheric bloom — upper centre
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
        // Warm gold exhale — bottom-left corner
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
          // Revealed count — understated
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
  final void Function(int) onTap;

  const _BoardArea({required this.revealed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = math.min(constraints.maxWidth, constraints.maxHeight);
      final cellSize = (size - _kSeam * (_kCols - 1)) / _kCols;

      return Center(
        child: ClipRRect(
          // Minimal radius — the board is an aperture, not a card.
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
                  // Layer 1 — the continuous image.
                  // Fills the entire board area; both layers share this space.
                  Image.asset(_kImage, fit: BoxFit.cover),
                  // Layer 2 — unified shutter mask.
                  // One painter covers everything; revealed cells are transparent
                  // holes punched through with BlendMode.clear.
                  CustomPaint(
                    painter: _ShutterMask(
                      revealed: revealed,
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
// Draws a single dark overlay over the full board, then punches transparent
// holes at each revealed cell using BlendMode.clear inside a saveLayer.
// The result is ONE mechanical surface with aperture openings — not N tiles.
//
// Pass order:
//   1. saveLayer → dark steel overlay → clear holes → restore
//   2. Hairline seam grid (over everything, including revealed cells)
//   3. Gold cut-edge around each revealed aperture
//   4. Top-left bevel hairline on covered cells (machined feel)

class _ShutterMask extends CustomPainter {
  final Set<int> revealed;
  final int cols;
  final int rows;
  final double cellSize;
  final double seam;

  _ShutterMask({
    required this.revealed,
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

    // ── 1. Unified overlay with punched holes ─────────────────────────────
    canvas.saveLayer(bounds, Paint());

    // Dark steel-blue shutter — not black, not grey.
    canvas.drawRect(
      bounds,
      Paint()..color = const Color(0xFF07152A).withOpacity(0.88),
    );

    // Punch transparent holes for revealed cells.
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    for (var idx = 0; idx < rows * cols; idx++) {
      if (revealed.contains(idx)) {
        canvas.drawRect(_cell(idx ~/ cols, idx % cols), clearPaint);
      }
    }

    canvas.restore();

    // ── 2. Hairline seam grid ─────────────────────────────────────────────
    // Drawn on top of everything — gives the board a unified grid reading
    // even across revealed cells, so it reads as one surface not N tiles.
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

    // ── 3. Gold cut-edge on revealed apertures ────────────────────────────
    // Thin gold stroke marks each opened aperture — premium, laser-cut feel.
    final goldEdge = Paint()
      ..color = const Color(0xFFD4AF37).withOpacity(0.48)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;

    for (var idx = 0; idx < rows * cols; idx++) {
      if (revealed.contains(idx)) {
        canvas.drawRect(_cell(idx ~/ cols, idx % cols), goldEdge);
      }
    }

    // ── 4. Bevel highlight on covered cells ───────────────────────────────
    // Very faint top + left hairline — implies machined depth without
    // making each cell look like a standalone button.
    final bevel = Paint()
      ..color = Colors.white.withOpacity(0.11)
      ..strokeWidth = 0.7;

    for (var idx = 0; idx < rows * cols; idx++) {
      if (!revealed.contains(idx)) {
        final r = _cell(idx ~/ cols, idx % cols);
        canvas.drawLine(r.topLeft, r.topRight, bevel);
        canvas.drawLine(r.topLeft, r.bottomLeft, bevel);
      }
    }
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
