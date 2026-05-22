/// Isolated visual prototype for puzzle-piece style tiles.
///
/// NOT connected to the production game board in any way.
/// No gameplay, Firestore, timers, sound, or animations.
///
/// HOW TO OPEN (dev only — revert before shipping):
///   Option A — replace home route temporarily in router:
///     redirect: (_,__) => '/puzzle-preview'
///     ... and add GoRoute(path: '/puzzle-preview', builder: (_,__) => const PuzzleTilePreviewScreen())
///
///   Option B — mount directly in main() for a one-off run:
///     runApp(MaterialApp(home: PuzzleTilePreviewScreen()));
///
///   Option C — add a hidden tap gesture to the profile screen (dev builds only).
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_styles.dart';

// ── Geometry constants ────────────────────────────────────────────────────────

/// Base tile size in logical pixels.
const double _kTileSize = 80.0;

/// Tab/blank radius as a fraction of tile size (0.22 ≈ standard jigsaw feel).
const double _kTabR = _kTileSize * 0.22;

// ── Screen ────────────────────────────────────────────────────────────────────

/// Self-contained prototype screen. No production wiring.
class PuzzleTilePreviewScreen extends StatelessWidget {
  const PuzzleTilePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppStyles.backgroundGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
            children: [
              Text(
                'Puzzle Tile Prototype',
                style: AppStyles.heading2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'static visual experiment — not production board',
                style: AppStyles.bodySmall.copyWith(
                  color: Colors.white.withOpacity(0.35),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 44),
              const _GridSection(label: '3 × 3', gridSize: 3),
              const SizedBox(height: 52),
              const _GridSection(label: '4 × 4', gridSize: 4),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridSection extends StatelessWidget {
  final String label;
  final int gridSize;
  const _GridSection({required this.label, required this.gridSize});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: AppStyles.cyanLabel),
        const SizedBox(height: 18),
        Center(child: _PuzzleGrid(gridSize: gridSize)),
      ],
    );
  }
}

// ── Grid ──────────────────────────────────────────────────────────────────────

/// Places puzzle tiles in a Stack. Tiles are painted in row-major order
/// so that right/bottom tabs from earlier tiles remain visible through the
/// left/top blanks of later tiles — correct visual interlocking without
/// any special clip logic.
class _PuzzleGrid extends StatelessWidget {
  final int gridSize;
  const _PuzzleGrid({required this.gridSize});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kTileSize * gridSize,
      height: _kTileSize * gridSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int row = 0; row < gridSize; row++)
            for (int col = 0; col < gridSize; col++)
              Positioned(
                left: col * _kTileSize,
                top: row * _kTileSize,
                child: _PuzzleTile(row: row, col: col, gridSize: gridSize),
              ),
        ],
      ),
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

/// Dark metallic palette — slight variation by position for visual distinction.
/// All entries are deep navy-to-black; real image would replace this.
const List<List<Color>> _kPalettes = [
  [Color(0xFF1C3154), Color(0xFF0D1C30)],
  [Color(0xFF162B44), Color(0xFF0B1826)],
  [Color(0xFF1A2E4C), Color(0xFF0C1A2C)],
  [Color(0xFF182948), Color(0xFF0A1622)],
  [Color(0xFF1E3358), Color(0xFF0F2038)],
  [Color(0xFF142640), Color(0xFF09131E)],
];

class _PuzzleTile extends StatelessWidget {
  final int row, col, gridSize;
  const _PuzzleTile({required this.row, required this.col, required this.gridSize});

  @override
  Widget build(BuildContext context) {
    final last = gridSize - 1;
    // Palette index offset by both row and col so neighbours differ.
    final paletteIdx = (row * 3 + col * 2) % _kPalettes.length;
    return CustomPaint(
      size: const Size(_kTileSize, _kTileSize),
      painter: _PuzzlePiecePainter(
        gradientColors: _kPalettes[paletteIdx],
        hasTopBlank: row > 0,
        hasRightTab: col < last,
        hasBottomTab: row < last,
        hasLeftBlank: col > 0,
      ),
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _PuzzlePiecePainter extends CustomPainter {
  final List<Color> gradientColors;
  final bool hasTopBlank;
  final bool hasRightTab;
  final bool hasBottomTab;
  final bool hasLeftBlank;

  const _PuzzlePiecePainter({
    required this.gradientColors,
    required this.hasTopBlank,
    required this.hasRightTab,
    required this.hasBottomTab,
    required this.hasLeftBlank,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const w = _kTileSize;
    const h = _kTileSize;
    final path = _buildPath(w, h);
    final rect = Rect.fromLTWH(0, 0, w, h);

    // ── Subtle outer glow (depth/shadow beneath tab edges) ──
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0xFF0A1828).withOpacity(0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 5),
    );

    // ── Base metallic fill ──
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ).createShader(rect),
    );

    // ── Top-left specular sheen (simulates surface curvature / lighting) ──
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.55, -0.55),
          radius: 1.3,
          colors: [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.00),
          ],
        ).createShader(rect),
    );

    // ── Bevel highlight: bright edge (top-left lit, bottom-right dark) ──
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.25),
            Colors.white.withOpacity(0.04),
          ],
        ).createShader(rect),
    );

    // ── Bevel shadow: dark outer stroke for depth ──
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75
        ..color = Colors.black.withOpacity(0.55),
    );
  }

  /// Builds the jigsaw puzzle-piece path.
  ///
  /// Edge conventions (tile bounding box is 0,0 → w,h):
  ///   • Tab:   convex protrusion OUTSIDE the bounding box (right→right, bottom→down).
  ///   • Blank: concave indentation INSIDE the bounding box (left←right, top←down).
  ///
  /// Adjacent tiles have complementary shapes: right tab of tile A = left blank of tile B.
  /// With row-major paint order, A's tab is visible through B's blank — no clip needed.
  Path _buildPath(double w, double h) {
    final mx = w / 2;
    final my = h / 2;
    const r = _kTabR;
    final path = Path();

    path.moveTo(0, 0);

    // ── Top edge — left to right ──
    if (hasTopBlank) {
      // Blank: concave arc curving DOWNWARD into the tile.
      // Center on the top edge at (mx, 0).  Start angle π (left), sweep +π (clockwise → down).
      path.lineTo(mx - r, 0);
      path.arcTo(
        Rect.fromCircle(center: Offset(mx, 0), radius: r),
        math.pi, math.pi, false,
      );
    }
    path.lineTo(w, 0);

    // ── Right edge — top to bottom ──
    if (hasRightTab) {
      // Tab: convex arc protruding RIGHTWARD beyond x = w.
      // Center on right edge at (w, my).  Start angle −π/2 (up), sweep +π (clockwise → right).
      path.lineTo(w, my - r);
      path.arcTo(
        Rect.fromCircle(center: Offset(w, my), radius: r),
        -math.pi / 2, math.pi, false,
      );
    }
    path.lineTo(w, h);

    // ── Bottom edge — right to left ──
    if (hasBottomTab) {
      // Tab: convex arc protruding DOWNWARD beyond y = h.
      // Center on bottom edge at (mx, h).  Start angle 0 (right), sweep +π (clockwise → down).
      path.lineTo(mx + r, h);
      path.arcTo(
        Rect.fromCircle(center: Offset(mx, h), radius: r),
        0, math.pi, false,
      );
    }
    path.lineTo(0, h);

    // ── Left edge — bottom to top ──
    if (hasLeftBlank) {
      // Blank: concave arc curving RIGHTWARD into the tile.
      // Center on left edge at (0, my).  Start angle π/2 (down), sweep −π (counter-clockwise → right).
      path.lineTo(0, my + r);
      path.arcTo(
        Rect.fromCircle(center: Offset(0, my), radius: r),
        math.pi / 2, -math.pi, false,
      );
    }
    path.lineTo(0, 0);

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_PuzzlePiecePainter old) =>
      old.hasTopBlank != hasTopBlank ||
      old.hasRightTab != hasRightTab ||
      old.hasBottomTab != hasBottomTab ||
      old.hasLeftBlank != hasLeftBlank ||
      old.gradientColors != gradientColors;
}
