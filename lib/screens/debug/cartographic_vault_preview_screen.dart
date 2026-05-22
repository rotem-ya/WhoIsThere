// TEMP DEBUG — continuous-image board visual prototype.
// Remove before merging vault visuals to production.
// Does NOT touch GameBoardScreen, game_board_view.dart, ApertureTile, or any gameplay code.

import 'package:flutter/material.dart';

// Placeholder image — same asset used by home screen hero, confirmed in pubspec.yaml assets.
const String _kPlaceholderImage = 'assets/game_places/images/masada.jpg';

// Which cells are "revealed" in the static prototype (row*5+col).
const Set<int> _kRevealed = {0, 1, 5, 6, 7, 10, 12};

// Board geometry.
const int _kCols = 5;
const int _kRows = 5;
const double _kGap = 3.0;

class CartographicVaultPreviewScreen extends StatefulWidget {
  const CartographicVaultPreviewScreen({super.key});

  @override
  State<CartographicVaultPreviewScreen> createState() =>
      _CartographicVaultPreviewScreenState();
}

class _CartographicVaultPreviewScreenState
    extends State<CartographicVaultPreviewScreen> {
  // Tracks which cells the user has tapped open in the prototype.
  final Set<int> _revealed = Set.from(_kRevealed);

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
      backgroundColor: const Color(0xFF060D1A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background — dark indigo gradient
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A1428), Color(0xFF050A14)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                _buildHeader(context),
                const SizedBox(height: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _ContinuousBoard(
                      revealed: _revealed,
                      onTap: _toggleCell,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildHint(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: Colors.white70),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'תצוגת לוח',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          // Revealed count badge
          _RevealedBadge(revealed: _revealed.length, total: _kCols * _kRows),
        ],
      ),
    );
  }

  Widget _buildHint() {
    return Center(
      child: Text(
        'גע בלוח לחשיפה',
        textDirection: TextDirection.rtl,
        style: TextStyle(
          color: Colors.white.withOpacity(0.28),
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Revealed count badge ──────────────────────────────────────────────────────

class _RevealedBadge extends StatelessWidget {
  final int revealed;
  final int total;
  const _RevealedBadge({required this.revealed, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Text(
        '$revealed / $total',
        style: TextStyle(
          color: Colors.white.withOpacity(0.45),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Continuous-image board ────────────────────────────────────────────────────
//
// Uses a single LayoutBuilder to compute exact pixel geometry, then places:
//   1. The full image, clipped to the board rectangle.
//   2. A grid of plate overlays — transparent for revealed cells, opaque for covered.
//
// Both layers share the same coordinate space, so the image appears
// continuous across all revealed cells.

class _ContinuousBoard extends StatelessWidget {
  final Set<int> revealed;
  final void Function(int idx) onTap;

  const _ContinuousBoard({required this.revealed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final boardW = constraints.maxWidth;
      // Keep board square — take the smaller dimension.
      final boardH = constraints.maxHeight < boardW ? constraints.maxHeight : boardW;

      final cellW = (boardW - _kGap * (_kCols - 1)) / _kCols;
      final cellH = (boardH - _kGap * (_kRows - 1)) / _kRows;

      return Center(
        child: SizedBox(
          width: boardW,
          height: boardH,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Layer 1 — the continuous image, fills entire board.
                Image.asset(
                  _kPlaceholderImage,
                  fit: BoxFit.cover,
                  width: boardW,
                  height: boardH,
                ),
                // Layer 2 — plate overlay grid.
                // Each cell is either a transparent hit-target (revealed)
                // or a metal plate that hides the image beneath it.
                _PlateGrid(
                  boardW: boardW,
                  boardH: boardH,
                  cellW: cellW,
                  cellH: cellH,
                  revealed: revealed,
                  onTap: onTap,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

// ── Plate grid overlay ────────────────────────────────────────────────────────

class _PlateGrid extends StatelessWidget {
  final double boardW;
  final double boardH;
  final double cellW;
  final double cellH;
  final Set<int> revealed;
  final void Function(int idx) onTap;

  const _PlateGrid({
    required this.boardW,
    required this.boardH,
    required this.cellW,
    required this.cellH,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(_kRows * _kCols, (idx) {
        final row = idx ~/ _kCols;
        final col = idx % _kCols;
        final left = col * (cellW + _kGap);
        final top = row * (cellH + _kGap);
        final isRevealed = revealed.contains(idx);

        return Positioned(
          left: left,
          top: top,
          width: cellW,
          height: cellH,
          child: GestureDetector(
            onTap: () => onTap(idx),
            child: isRevealed
                ? _RevealedCell(cellW: cellW, cellH: cellH)
                : _MetalPlate(cellW: cellW, cellH: cellH),
          ),
        );
      }),
    );
  }
}

// ── Revealed cell ─────────────────────────────────────────────────────────────
//
// Transparent — the image underneath is fully visible.
// A thin cyan border marks the open aperture.

class _RevealedCell extends StatelessWidget {
  final double cellW;
  final double cellH;
  const _RevealedCell({required this.cellW, required this.cellH});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: const Color(0xFF00F2FF).withOpacity(0.55),
          width: 1.2,
        ),
      ),
    );
  }
}

// ── Metal plate (covered cell) ────────────────────────────────────────────────
//
// A solid overlay that hides the image beneath.
// Styled as a dark machined plate with a bevel highlight and a gold border.

class _MetalPlate extends StatelessWidget {
  final double cellW;
  final double cellH;
  const _MetalPlate({required this.cellW, required this.cellH});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PlatePainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _PlatePainter extends CustomPainter {
  const _PlatePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(5),
    );

    // Base plate — dark steel gradient
    final basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1A2840), Color(0xFF0C1624)],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(rr, basePaint);

    // Top-left bevel highlight (thin bright strip)
    final bevelPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - 3, 3)
      ..lineTo(3, 3)
      ..lineTo(3, size.height - 3)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      bevelPath,
      Paint()..color = Colors.white.withOpacity(0.07),
    );

    // Bottom-right shadow bevel
    final shadowPath = Path()
      ..moveTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..lineTo(3, size.height - 3)
      ..lineTo(size.width - 3, size.height - 3)
      ..lineTo(size.width - 3, 3)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(
      shadowPath,
      Paint()..color = Colors.black.withOpacity(0.30),
    );

    // Gold border
    canvas.drawRRect(
      rr,
      Paint()
        ..color = const Color(0xFFD4AF37).withOpacity(0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Central rivet dots — two small circles, machined feel
    final rivetPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final cy = size.height / 2;
    const rr2 = 1.8;
    canvas.drawCircle(Offset(cx - 4, cy), rr2, rivetPaint);
    canvas.drawCircle(Offset(cx + 4, cy), rr2, rivetPaint);
  }

  @override
  bool shouldRepaint(covariant _PlatePainter old) => false;
}
