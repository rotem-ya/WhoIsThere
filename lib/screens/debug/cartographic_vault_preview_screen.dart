import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_styles.dart';

class CartographicVaultPreviewScreen extends StatelessWidget {
  const CartographicVaultPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060D1A),
      body: Stack(
        children: [
          const _VaultBackground(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _VaultHeader(),
                const Expanded(child: _PlateGrid()),
                const _VaultHUD(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Background ────────────────────────────────────────────────────────────────

class _VaultBackground extends StatelessWidget {
  const _VaultBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base gradient — deep indigo atmosphere
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0A1428),
                Color(0xFF060D1A),
                Color(0xFF04080F),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        // Subtle radial vignette — steel blue centre bloom
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.0, -0.3),
              radius: 0.9,
              colors: [
                const Color(0xFF1A3A5C).withOpacity(0.28),
                Colors.transparent,
              ],
            ),
          ),
        ),
        // Cyan dust particle layer
        CustomPaint(painter: _DustPainter(seed: 42)),
        // Horizontal scan lines — very faint mechanical texture
        CustomPaint(painter: _ScanLinePainter()),
      ],
    );
  }
}

// ── Dust Particles ────────────────────────────────────────────────────────────

class _DustPainter extends CustomPainter {
  final int seed;
  const _DustPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final cyanPaint = Paint()
      ..color = const Color(0xFF00F2FF).withOpacity(0.06)
      ..style = PaintingStyle.fill;
    final goldPaint = Paint()
      ..color = const Color(0xFFD4AF37).withOpacity(0.08)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 60; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.8 + 0.4;
      final isGold = rng.nextDouble() < 0.08; // ~8% gold dust
      canvas.drawCircle(Offset(x, y), r, isGold ? goldPaint : cyanPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DustPainter old) => old.seed != seed;
}

class _ScanLinePainter extends CustomPainter {
  const _ScanLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.012)
      ..strokeWidth = 1.0;
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter old) => false;
}

// ── Header ────────────────────────────────────────────────────────────────────

class _VaultHeader extends StatelessWidget {
  const _VaultHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          // Vault crest — gold hexagon badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFE27A), Color(0xFFD4AF37), Color(0xFFA1811A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withOpacity(0.45),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.shield_rounded, size: 18, color: Color(0xFF07101F)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VAULT PREVIEW',
                style: AppStyles.bodySmall.copyWith(
                  color: const Color(0xFF00F2FF).withOpacity(0.7),
                  fontSize: 9,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'Cartographic Vault',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Round indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white.withOpacity(0.06),
              border: Border.all(
                color: Colors.white.withOpacity(0.14),
                width: 1,
              ),
            ),
            child: Text(
              'ROUND 3 / 5',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.6),
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 4×4 Plate Grid ────────────────────────────────────────────────────────────

class _PlateGrid extends StatelessWidget {
  const _PlateGrid();

  // Fake reveal pattern: which tiles are uncovered
  static const _revealed = {0, 1, 4, 5, 8};
  // Tile that is "active" / glowing
  static const _active = 9;
  // Tile with gold accent highlight
  static const _goldHint = 6;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tileSize = (constraints.maxWidth - 12 * 3) / 4; // 3 gaps between 4 cols
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (row) {
              return Padding(
                padding: row < 3 ? const EdgeInsets.only(bottom: 12) : EdgeInsets.zero,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (col) {
                    final idx = row * 4 + col;
                    return Padding(
                      padding: col < 3
                          ? const EdgeInsets.only(right: 12)
                          : EdgeInsets.zero,
                      child: _MachinedPlate(
                        size: tileSize,
                        isRevealed: _revealed.contains(idx),
                        isActive: idx == _active,
                        hasGoldHint: idx == _goldHint,
                        index: idx,
                      ),
                    );
                  }),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// ── Machined Plate Tile ───────────────────────────────────────────────────────

class _MachinedPlate extends StatelessWidget {
  final double size;
  final bool isRevealed;
  final bool isActive;
  final bool hasGoldHint;
  final int index;

  const _MachinedPlate({
    required this.size,
    required this.isRevealed,
    required this.isActive,
    required this.hasGoldHint,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isActive
        ? const Color(0xFF00F2FF)
        : hasGoldHint
            ? const Color(0xFFD4AF37).withOpacity(0.8)
            : Colors.white.withOpacity(0.12);

    final glowShadows = isActive
        ? [
            BoxShadow(
              color: const Color(0xFF00F2FF).withOpacity(0.40),
              blurRadius: 16,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: const Color(0xFF00F2FF).withOpacity(0.15),
              blurRadius: 32,
              spreadRadius: 6,
            ),
          ]
        : hasGoldHint
            ? [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withOpacity(0.30),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : <BoxShadow>[];

    return SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: _tileGradient(),
          border: Border.all(color: borderColor, width: isActive ? 1.5 : 1.0),
          boxShadow: [
            // Inset-like ambient shadow at bottom
            BoxShadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 6,
              offset: const Offset(0, 4),
            ),
            ...glowShadows,
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Bevel highlight — top-left white shimmer
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: size * 0.28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Bevel shadow — bottom-right
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: size * 0.22,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.30),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Tile content
              Center(child: _tileContent(size)),
            ],
          ),
        ),
      ),
    );
  }

  LinearGradient _tileGradient() {
    if (isRevealed) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1A3A5C), Color(0xFF0D2040)],
      );
    }
    if (isActive) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF0E2440).withOpacity(0.95),
          const Color(0xFF071828),
        ],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF101C2E), Color(0xFF080F1C)],
    );
  }

  Widget _tileContent(double size) {
    if (isRevealed) {
      return CustomPaint(
        size: Size(size * 0.55, size * 0.55),
        painter: _LocationIconPainter(index: index),
      );
    }
    if (isActive) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.my_location_rounded,
            size: size * 0.32,
            color: const Color(0xFF00F2FF),
          ),
          const SizedBox(height: 3),
          Text(
            '?',
            style: TextStyle(
              fontSize: size * 0.20,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF00F2FF).withOpacity(0.8),
            ),
          ),
        ],
      );
    }
    if (hasGoldHint) {
      return Icon(
        Icons.star_rounded,
        size: size * 0.34,
        color: const Color(0xFFD4AF37).withOpacity(0.6),
      );
    }
    return Icon(
      Icons.lock_outline_rounded,
      size: size * 0.30,
      color: Colors.white.withOpacity(0.15),
    );
  }
}

// ── Location Icon Painter ─────────────────────────────────────────────────────
// Draws a minimal stylized pin / landmark for revealed tiles

class _LocationIconPainter extends CustomPainter {
  final int index;
  const _LocationIconPainter({required this.index});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw a small glowing dot as the landmark pin
    final paint = Paint()
      ..color = const Color(0xFF87CEEB).withOpacity(0.75)
      ..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawCircle(Offset(cx, cy), size.width * 0.18, paint);

    final ringPaint = Paint()
      ..color = const Color(0xFF00F2FF).withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(cx, cy), size.width * 0.36, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _LocationIconPainter old) => old.index != index;
}

// ── HUD Strip ────────────────────────────────────────────────────────────────

class _VaultHUD extends StatelessWidget {
  const _VaultHUD();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E1E35), Color(0xFF07101F)],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          _HUDStat(
            label: 'TILES LEFT',
            value: '11',
            valueColor: Colors.white,
          ),
          _HUDDivider(),
          _HUDStat(
            label: 'PLAYERS',
            value: '3',
            valueColor: const Color(0xFF87CEEB),
          ),
          _HUDDivider(),
          _HUDStat(
            label: 'PHASE',
            value: 'REVEAL',
            valueColor: const Color(0xFF00F2FF),
          ),
          _HUDDivider(),
          _HUDStat(
            label: 'COINS',
            value: '240',
            valueColor: const Color(0xFFD4AF37),
          ),
          const Spacer(),
          // Timer pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFF00F2FF).withOpacity(0.10),
              border: Border.all(
                color: const Color(0xFF00F2FF).withOpacity(0.30),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 13,
                  color: const Color(0xFF00F2FF).withOpacity(0.8),
                ),
                const SizedBox(width: 4),
                const Text(
                  '0:12',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF00F2FF),
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HUDStat extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _HUDStat({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.40),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: valueColor,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _HUDDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white.withOpacity(0.10),
    );
  }
}
