import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/sfx_service.dart';
import 'coin_icon.dart';

/// A global anchor the flying coins home in on. Wrap the wallet chip on the
/// home screen (or any coin balance) with a widget that carries this key, so a
/// reward earned anywhere can send coins straight to it.
///
/// If the anchor isn't mounted (e.g. the wallet isn't on screen), [CoinFly]
/// falls back to the top of the screen so the burst still reads as "coins
/// gained" without throwing.
final GlobalKey walletAnchorKey = GlobalKey();

/// Fires a short burst of coins that arc from a source point to the wallet
/// counter, with a light coin shower sound as they land. Purely cosmetic and
/// fail-soft: if anything is missing it simply does nothing.
class CoinFly {
  const CoinFly._();

  /// Launch [count] coins from [from] (a global screen position) toward the
  /// wallet anchor. Pass a [context] that sits under the root overlay.
  static void burst(
    BuildContext context, {
    required Offset from,
    int count = 12,
    bool sound = true,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    // Resolve the target from the wallet anchor; fall back near the top.
    Offset target;
    final anchorCtx = walletAnchorKey.currentContext;
    final anchorBox = anchorCtx?.findRenderObject() as RenderBox?;
    if (anchorBox != null && anchorBox.hasSize) {
      target = anchorBox.localToGlobal(anchorBox.size.center(Offset.zero));
    } else {
      final size = MediaQuery.maybeOf(context)?.size;
      if (size == null) return;
      target = Offset(size.width / 2, 90);
    }

    final n = count.clamp(4, 20);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CoinFlyLayer(
        from: from,
        to: target,
        count: n,
        sound: sound,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

class _CoinFlyLayer extends StatefulWidget {
  final Offset from;
  final Offset to;
  final int count;
  final bool sound;
  final VoidCallback onDone;

  const _CoinFlyLayer({
    required this.from,
    required this.to,
    required this.count,
    required this.sound,
    required this.onDone,
  });

  @override
  State<_CoinFlyLayer> createState() => _CoinFlyLayerState();
}

class _CoinFlyLayerState extends State<_CoinFlyLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Coin> _coins;
  final _rng = math.Random();
  // Coins that have already played their landing tick.
  final Set<int> _landed = {};

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..addListener(_tick);
    _coins = List.generate(widget.count, (i) {
      // Each coin starts a little apart from the source and lands staggered.
      const spread = 46.0;
      final jx = (_rng.nextDouble() - 0.5) * spread;
      final jy = (_rng.nextDouble() - 0.5) * spread * 0.7;
      final start = (i / widget.count) * 0.34;
      // A control point pulled sideways + up gives the arc its lob.
      final mid = Offset.lerp(widget.from, widget.to, 0.45)!;
      final control = mid +
          Offset((_rng.nextDouble() - 0.5) * 140, -80 - _rng.nextDouble() * 90);
      return _Coin(
        origin: widget.from + Offset(jx, jy),
        control: control,
        start: start,
        end: (start + 0.62).clamp(0.0, 1.0),
        size: 20 + _rng.nextDouble() * 12,
        spin: (_rng.nextDouble() - 0.5) * 5,
      );
    });
    _ctrl.forward().whenComplete(widget.onDone);
    // Kick off the shower with one satisfying coin sound.
    if (widget.sound) SfxService.instance.coinGain();
  }

  void _tick() {
    // Play a light landing tick as each coin arrives, so it feels like a
    // cascade of coins dropping into the wallet.
    for (var i = 0; i < _coins.length; i++) {
      if (_landed.contains(i)) continue;
      if (_ctrl.value >= _coins[i].end) {
        _landed.add(i);
        if (widget.sound && _landed.length.isEven) {
          SfxService.instance.coinGain();
        }
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          for (final coin in _coins) _buildCoin(coin),
        ],
      ),
    );
  }

  Widget _buildCoin(_Coin coin) {
    final raw = (_ctrl.value - coin.start) / (coin.end - coin.start);
    if (raw <= 0) return const SizedBox.shrink();
    final t = raw.clamp(0.0, 1.0);
    final eased = Curves.easeInCubic.transform(t);
    // Quadratic bezier from origin -> control -> target.
    final pos = _bezier(coin.origin, coin.control, widget.to, eased);
    // Shrink and fade as it reaches the wallet.
    final scale = (1.0 - 0.55 * t);
    final opacity = t > 0.82 ? (1.0 - (t - 0.82) / 0.18).clamp(0.0, 1.0) : 1.0;
    return Positioned(
      left: pos.dx - coin.size / 2,
      top: pos.dy - coin.size / 2,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: coin.spin * t,
          child: Transform.scale(
            scale: scale,
            child: _CoinChip(size: coin.size),
          ),
        ),
      ),
    );
  }

  Offset _bezier(Offset p0, Offset p1, Offset p2, double t) {
    final u = 1 - t;
    return Offset(
      u * u * p0.dx + 2 * u * t * p1.dx + t * t * p2.dx,
      u * u * p0.dy + 2 * u * t * p1.dy + t * t * p2.dy,
    );
  }
}

class _Coin {
  final Offset origin;
  final Offset control;
  final double start;
  final double end;
  final double size;
  final double spin;
  const _Coin({
    required this.origin,
    required this.control,
    required this.start,
    required this.end,
    required this.size,
    required this.spin,
  });
}

/// A single glossy coin with a soft glow, so the burst reads richer than a flat
/// icon in flight.
class _CoinChip extends StatelessWidget {
  final double size;
  const _CoinChip({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFFFF1B0), Color(0xFFFFD84D), Color(0xFFC79214)],
          stops: [0.0, 0.55, 1.0],
          center: Alignment(-0.3, -0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD84D).withOpacity(0.55),
            blurRadius: 10,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Center(
        child: CoinIcon(size: size * 0.62, color: const Color(0xFF8A6910)),
      ),
    );
  }
}
