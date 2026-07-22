import 'package:flutter/cupertino.dart';

import '../economy/coin_icon.dart';

/// Pull-to-refresh with a spinning Candy coin instead of the stock spinner.
///
/// Built on [CupertinoSliverRefreshControl] so Flutter owns the pull physics
/// (no hand-rolled scroll math). The list is driven with bouncing physics so
/// the pull gesture works the same on Android and iOS. Pass the list items as
/// [slivers]; a plain list becomes `[SliverList(...)]`.
class CoinRefresh extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final List<Widget> slivers;
  final EdgeInsets padding;

  const CoinRefresh({
    super.key,
    required this.onRefresh,
    required this.slivers,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      // Bouncing everywhere so the coin can be pulled down on Android too.
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(
          refreshTriggerPullDistance: 96,
          refreshIndicatorExtent: 76,
          onRefresh: onRefresh,
          builder: (context, mode, pulled, triggerExtent, indicatorExtent) {
            // How far into the pull we are (0..1), and a bit beyond while armed.
            final t = (pulled / triggerExtent).clamp(0.0, 1.5);
            final refreshing = mode == RefreshIndicatorMode.refresh ||
                mode == RefreshIndicatorMode.armed;
            return Center(
              child: Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: _SpinningCoin(
                  // Grows as you pull; keeps spinning while it refreshes.
                  scale: (0.5 + 0.5 * t).clamp(0.5, 1.0),
                  spinning: refreshing,
                  pullTurns: t, // static rotation tracks the pull before release
                ),
              ),
            );
          },
        ),
        SliverPadding(padding: padding, sliver: _wrap(slivers)),
      ],
    );
  }

  Widget _wrap(List<Widget> slivers) {
    if (slivers.length == 1) return slivers.first;
    return SliverMainAxisGroup(slivers: slivers);
  }
}

class _SpinningCoin extends StatefulWidget {
  final double scale;
  final bool spinning;
  final double pullTurns;
  const _SpinningCoin({
    required this.scale,
    required this.spinning,
    required this.pullTurns,
  });

  @override
  State<_SpinningCoin> createState() => _SpinningCoinState();
}

class _SpinningCoinState extends State<_SpinningCoin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.spinning) _spin.repeat();
  }

  @override
  void didUpdateWidget(_SpinningCoin old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.spinning && _spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _spin,
      builder: (_, __) {
        // A Y-axis flip reads like a coin turning; fall back to the pull angle
        // before it starts spinning.
        final turns = widget.spinning ? _spin.value : widget.pullTurns * 0.5;
        return Transform.scale(
          scale: widget.scale,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(turns * 2 * 3.14159),
            child: const CoinIcon(size: 30),
          ),
        );
      },
    );
  }
}
