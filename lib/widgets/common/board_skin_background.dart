import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/board_skin.dart';

/// A bright Candy colorway for a board skin: a glossy 3-stop gradient plus one
/// or two soft accent glows (and optional starfield). Clean and coherent with
/// the app's Candy line — no muddy dark photos.
class _CW {
  final List<Color> grad;
  final Color glowA;
  final Color? glowB;
  final bool stars;
  const _CW(this.grad, this.glowA, {this.glowB, this.stars = false});
}

const Map<String, _CW> _boardColorways = {
  'none': _CW([Color(0xFF6A34BE), Color(0xFF3A1B6E), Color(0xFF22103F)],
      Color(0xFFFF6EA6), glowB: Color(0xFF12B5A6)),
  'midnight': _CW([Color(0xFF3E5BC0), Color(0xFF22306E), Color(0xFF0E1430)],
      Color(0xFF6E8CFF)),
  'deep_sea': _CW([Color(0xFF12B5A6), Color(0xFF0B6E64), Color(0xFF04231F)],
      Color(0xFF3FE0D0)),
  'plum': _CW([Color(0xFF8A3FD1), Color(0xFF4A228A), Color(0xFF1E0E38)],
      Color(0xFFFF6EA6)),
  'forest': _CW([Color(0xFF5AC06A), Color(0xFF2E7A3E), Color(0xFF0E2A14)],
      Color(0xFF8CE05A)),
  'ember': _CW([Color(0xFFFF8A3A), Color(0xFFB0402A), Color(0xFF3A0E08)],
      Color(0xFFFFB03A), glowB: Color(0xFFFF6EA6)),
  'aurora': _CW([Color(0xFF12B5A6), Color(0xFF1F5AB0), Color(0xFF0E1F4A)],
      Color(0xFF3FE0C0), glowB: Color(0xFF6E8CFF), stars: true),
  'sunset': _CW([Color(0xFFFF6EA6), Color(0xFFE0673D), Color(0xFF3A0E28)],
      Color(0xFFFFB03A)),
  'galaxy': _CW([Color(0xFF6A4AD1), Color(0xFF2E2A8A), Color(0xFF120A33)],
      Color(0xFF8C5AE0), glowB: Color(0xFF3E7BE0), stars: true),
  'royal_gold': _CW([Color(0xFFFFD84D), Color(0xFFB08020), Color(0xFF3A2A05)],
      Color(0xFFFFE98A)),
  'nebula': _CW([Color(0xFFC04AD1), Color(0xFF5A2A8A), Color(0xFF1A0A33)],
      Color(0xFFFF6EA6), glowB: Color(0xFF6E8CFF), stars: true),
  'emerald_dream': _CW([Color(0xFF2FD6A0), Color(0xFF0B8A5A), Color(0xFF04231A)],
      Color(0xFF3FE0A0)),
};

/// Rich, layered background for an equipped board skin. Each skin is a bespoke
/// composition (base gradient + radial glows + light beams + starfields +
/// vignette) rather than a flat colour swap, so every skin reads as distinct
/// and premium. Used both in-game (behind the board) and as a store preview.
class BoardSkinBackground extends StatelessWidget {
  final String skinId;
  final Widget? child;

  const BoardSkinBackground({super.key, required this.skinId, this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ..._layersFor(skinId),
        if (child != null) child!,
      ],
    );
  }

  // ── Layer helpers ─────────────────────────────────────────────────────────

  static Widget _base(List<Color> colors,
          {Alignment begin = Alignment.topCenter,
          Alignment end = Alignment.bottomCenter}) =>
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: begin, end: end, colors: colors),
          ),
        ),
      );

  /// A soft radial glow anchored at [center]. [radius] is relative to the
  /// shorter side; [opacity] is the glow strength at the centre.
  static Widget _glow(Color color, Alignment center, double radius,
          double opacity) =>
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: center,
              radius: radius,
              colors: [color.withOpacity(opacity), color.withOpacity(0)],
            ),
          ),
        ),
      );

  /// A diagonal light beam (angled linear band that fades at both ends).
  static Widget _beam(Color color, double opacity,
          {required Alignment begin, required Alignment end}) =>
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin,
              end: end,
              colors: [
                color.withOpacity(0),
                color.withOpacity(opacity),
                color.withOpacity(0),
              ],
              stops: const [0.30, 0.5, 0.70],
            ),
          ),
        ),
      );

  static Widget _vignette([double strength = 0.55]) => Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(strength),
              ],
              stops: const [0.55, 1.0],
            ),
          ),
        ),
      );

  static Widget _stars(
          {required Color color,
          required int count,
          required int seed,
          double maxRadius = 1.4}) =>
      Positioned.fill(
        child: CustomPaint(
          painter: _StarfieldPainter(
              color: color, count: count, seed: seed, maxRadius: maxRadius),
        ),
      );

  List<Widget> _layersFor(String id) {
    final live = boardSkinFor(id);
    // A BAKED local asset (release bake) always wins — instant, no cloud read.
    if (live.id == id && live.assetPath != null) {
      return [
        Positioned.fill(
          child: Image.asset(
            live.assetPath!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => DecoratedBox(
              decoration: BoxDecoration(gradient: live.gradient),
            ),
          ),
        ),
        _vignette(0.40),
      ];
    }
    // An admin-attached background IMAGE (live cosmetics catalog) wins next —
    // including for bundled ids that would otherwise hit their bespoke case.
    if (live.id == id && live.imageUrl != null) {
      return [
        Positioned.fill(
          child: CachedNetworkImage(
            imageUrl: live.imageUrl!,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => DecoratedBox(
              decoration: BoxDecoration(gradient: live.gradient),
            ),
          ),
        ),
        _vignette(0.40),
      ];
    }
    // Bright Candy colorway (clean glossy gradient + soft glows) — the new,
    // consistent look for every bundled skin. Admin live skins (not in the map)
    // still fall through to the legacy switch / default below.
    final cw = _boardColorways[id];
    if (cw != null) {
      return [
        _base(cw.grad,
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        _glow(cw.glowA, const Alignment(-0.45, -0.85), 1.0, 0.30),
        if (cw.glowB != null)
          _glow(cw.glowB!, const Alignment(0.55, 0.9), 0.9, 0.22),
        if (cw.stars)
          _stars(color: Colors.white, count: 70, seed: 7, maxRadius: 1.3),
        _vignette(0.24),
      ];
    }
    switch (id) {
      case 'midnight':
        return [
          _base(const [Color(0xFF18335A), Color(0xFF050A16)]),
          _glow(const Color(0xFF4F91FF), Alignment.topCenter, 0.9, 0.30),
          _vignette(0.35),
        ];
      case 'deep_sea':
        return [
          _base(const [Color(0xFF06343E), Color(0xFF00161C)]),
          _glow(const Color(0xFF18E0C8), const Alignment(0, 1.0), 1.1, 0.30),
          _glow(const Color(0xFF0A6E8A), const Alignment(0, -0.8), 0.8, 0.22),
          _vignette(),
        ];
      case 'plum':
        return [
          _base(const [Color(0xFF351C53), Color(0xFF0E0518)]),
          _beam(const Color(0xFFC056E0), 0.16,
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          _glow(const Color(0xFF8E2DE2), Alignment.topRight, 0.9, 0.26),
          _vignette(),
        ];
      case 'forest':
        return [
          _base(const [Color(0xFF173B22), Color(0xFF04120A)]),
          _glow(const Color(0xFF5BE07A), const Alignment(-0.3, -0.9), 0.9, 0.26),
          _glow(const Color(0xFF1B7A3E), const Alignment(0.6, 0.7), 0.9, 0.20),
          _vignette(),
        ];
      case 'ember':
        return [
          _base(const [Color(0xFF2A0D08), Color(0xFF120403)]),
          _glow(const Color(0xFFFF5722), const Alignment(0, 1.05), 1.2, 0.42),
          _glow(const Color(0xFFFFC107), const Alignment(0, 1.2), 0.6, 0.30),
          _vignette(0.5),
        ];
      case 'aurora':
        return [
          _base(const [Color(0xFF071326), Color(0xFF02060F)]),
          _glow(const Color(0xFF18E08A), const Alignment(-0.7, -0.9), 1.0, 0.34),
          _glow(const Color(0xFF1FB6E0), const Alignment(0.5, -0.7), 0.9, 0.30),
          _glow(const Color(0xFF8E5BFF), const Alignment(0.9, -1.0), 0.7, 0.20),
          _stars(color: Colors.white, count: 40, seed: 11, maxRadius: 1.0),
          _vignette(),
        ];
      case 'sunset':
        return [
          _base(const [
            Color(0xFF2A1040),
            Color(0xFF8A2D4B),
            Color(0xFFE0673D),
            Color(0xFF1A0512),
          ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          _glow(const Color(0xFFFFD27A), const Alignment(0, 0.35), 0.7, 0.45),
          _vignette(0.45),
        ];
      case 'galaxy':
        return [
          _base(const [Color(0xFF160A33), Color(0xFF05030F)]),
          _glow(const Color(0xFF7A2DE0), const Alignment(-0.4, -0.4), 1.1, 0.34),
          _glow(const Color(0xFF2D6EE0), const Alignment(0.6, 0.5), 0.9, 0.26),
          _stars(color: Colors.white, count: 90, seed: 7, maxRadius: 1.6),
          _vignette(),
        ];
      case 'royal_gold':
        return [
          _base(const [Color(0xFF221802), Color(0xFF0A0700)]),
          _glow(const Color(0xFFFFD700), Alignment.center, 1.1, 0.34),
          _glow(const Color(0xFFFFF3C0), Alignment.center, 0.45, 0.30),
          _stars(color: const Color(0xFFFFE9A8), count: 36, seed: 21, maxRadius: 1.5),
          _vignette(0.62),
        ];
      case 'nebula':
        return [
          _base(const [Color(0xFF120633), Color(0xFF04020D)]),
          _glow(const Color(0xFF8E2DE2), const Alignment(-0.6, -0.6), 0.9, 0.34),
          _glow(const Color(0xFF2D6EE0), const Alignment(0.7, 0.0), 0.8, 0.30),
          _glow(const Color(0xFFE0457A), const Alignment(0.1, 0.8), 0.8, 0.26),
          _stars(color: Colors.white, count: 110, seed: 3, maxRadius: 1.7),
          _vignette(),
        ];
      case 'emerald_dream':
        return [
          _base(const [Color(0xFF06392C), Color(0xFF02120C)]),
          _glow(const Color(0xFF1FE0A0), Alignment.center, 1.0, 0.34),
          _glow(const Color(0xFF0FB0E0), const Alignment(0, 1.0), 0.8, 0.22),
          _stars(color: const Color(0xFFBFFFE8), count: 30, seed: 33, maxRadius: 1.2),
          _vignette(),
        ];
      case 'none':
        // App-default — the Candy grape ground with soft pink + teal glows,
        // matching the rest of the app so the default board looks designed.
        return [
          _base(const [Color(0xFF5B2AA6), Color(0xFF3A1B6E), Color(0xFF22103F)]),
          _glow(const Color(0xFFFF6EA6), const Alignment(-0.5, -0.9), 0.9, 0.16),
          _glow(const Color(0xFF12B5A6), const Alignment(0.6, 0.9), 0.9, 0.14),
          _vignette(0.30),
        ];
      default:
        // Admin-created skins (live catalog) without an image: a generic
        // gradient composition from the skin's colors. Unknown ids fall back
        // to the app-default deep navy board.
        final skin = live;
        if (skin.id == id && skin.colors.isNotEmpty) {
          return [
            _base(skin.colors.length == 1
                ? [skin.colors.first, skin.colors.first]
                : skin.colors),
            _glow(skin.accent, Alignment.topCenter, 0.9, 0.26),
            _vignette(0.35),
          ];
        }
        return [
          _base(const [Color(0xFF0A1A2E), Color(0xFF04091A)]),
        ];
    }
  }
}

/// Scatters small static "stars" deterministically (seeded) across the canvas.
class _StarfieldPainter extends CustomPainter {
  final Color color;
  final int count;
  final int seed;
  final double maxRadius;

  _StarfieldPainter({
    required this.color,
    required this.count,
    required this.seed,
    required this.maxRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    for (var i = 0; i < count; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      final r = 0.4 + rnd.nextDouble() * maxRadius;
      final opacity = 0.25 + rnd.nextDouble() * 0.6;
      canvas.drawCircle(
          Offset(dx, dy), r, Paint()..color = color.withOpacity(opacity));
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter old) =>
      old.color != color ||
      old.count != count ||
      old.seed != seed ||
      old.maxRadius != maxRadius;
}
