import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import 'coin_icon.dart';

/// Compact coin balance widget that reads walletProvider directly.
/// Animates the displayed number when the balance changes.
class CoinDisplay extends ConsumerWidget {
  final bool compact;
  const CoinDisplay({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(walletProvider).valueOrNull?.coins ?? 0;
    return _AnimatedCoinChip(amount: coins, compact: compact);
  }
}

class _AnimatedCoinChip extends StatefulWidget {
  final int amount;
  final bool compact;
  const _AnimatedCoinChip({required this.amount, required this.compact});

  @override
  State<_AnimatedCoinChip> createState() => _AnimatedCoinChipState();
}

class _AnimatedCoinChipState extends State<_AnimatedCoinChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _anim;
  // A celebratory bump — pulses only when the balance grows.
  Animation<double> _scale = const AlwaysStoppedAnimation(1.0);
  int _from = 0;

  @override
  void initState() {
    super.initState();
    _from = widget.amount;
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _anim = AlwaysStoppedAnimation(widget.amount.toDouble());
  }

  @override
  void didUpdateWidget(_AnimatedCoinChip old) {
    super.didUpdateWidget(old);
    if (old.amount != widget.amount) {
      _from = _anim.value.round();
      _anim = Tween<double>(
        begin: _from.toDouble(),
        end: widget.amount.toDouble(),
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
      _scale = widget.amount > old.amount
          ? TweenSequence<double>([
              TweenSequenceItem(
                tween: Tween(begin: 1.0, end: 1.12)
                    .chain(CurveTween(curve: Curves.easeOut)),
                weight: 35,
              ),
              TweenSequenceItem(
                tween: Tween(begin: 1.12, end: 1.0)
                    .chain(CurveTween(curve: Curves.easeIn)),
                weight: 65,
              ),
            ]).animate(_ctrl)
          : const AlwaysStoppedAnimation(1.0);
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.compact ? 32.0 : 40.0;
    final px = widget.compact ? 10.0 : 12.0;
    final iconSize = widget.compact ? 12.0 : 14.0;
    final fontSize = widget.compact ? 14.0 : 18.0;

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final displayed = _anim.value.round().clamp(0, 999999);
        return Transform.scale(
          scale: _scale.value,
          child: Container(
          height: h,
          padding: EdgeInsets.symmetric(horizontal: px),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFE082), Color(0xFFD4AF37), Color(0xFFA1811A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(widget.compact ? 14 : 18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4AF37).withOpacity(0.28),
                blurRadius: widget.compact ? 8 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CoinIcon(size: iconSize),
              SizedBox(width: widget.compact ? 3 : 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    // A tiny pop on every counted value so the tally feels alive.
                    scale: Tween<double>(begin: 0.72, end: 1.0).animate(
                        CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.4),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                ),
                child: Text(
                  '$displayed',
                  key: ValueKey(displayed),
                  style: TextStyle(
                    color: const Color(0xFF07101F),
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}
