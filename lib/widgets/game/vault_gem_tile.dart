import 'package:flutter/material.dart';

class VaultGemTile extends StatefulWidget {
  final bool isRevealed;
  final Widget child;

  const VaultGemTile({
    super.key,
    required this.isRevealed,
    required this.child,
  });

  @override
  State<VaultGemTile> createState() => _VaultGemTileState();
}

class _VaultGemTileState extends State<VaultGemTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _isPressed ? 0.94 : 1.0;

    return Listener(
      onPointerDown: (_) => setState(() => _isPressed = true),
      onPointerUp: (_) => setState(() => _isPressed = false),
      onPointerCancel: (_) => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) {
            final scaleAnimation = TweenSequence<double>([
              TweenSequenceItem(
                tween: Tween(begin: 0.96, end: 1.06).chain(CurveTween(curve: Curves.easeOut)),
                weight: 55,
              ),
              TweenSequenceItem(
                tween: Tween(begin: 1.06, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
                weight: 45,
              ),
            ]).animate(animation);

            return ScaleTransition(
              scale: scaleAnimation,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: widget.isRevealed ? _buildRevealed() : _buildHidden(),
        ),
      ),
    );
  }

  Widget _buildHidden() {
    return Container(
      key: const ValueKey('vault_hidden'),
      decoration: BoxDecoration(
        color: const Color(0xFF050A14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC5A021), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.58),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFFC5A021).withOpacity(0.18),
            blurRadius: 0,
            offset: const Offset(0, -2),
            spreadRadius: -1,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.06),
                    Colors.transparent,
                    Colors.black.withOpacity(0.10),
                  ],
                ),
              ),
            ),
          ),
          const Center(
            child: Icon(
              Icons.help_outline_rounded,
              color: Color(0xFFD4AF37),
              size: 32,
              shadows: [
                Shadow(
                  color: Colors.black45,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevealed() {
    return Container(
      key: const ValueKey('vault_revealed'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF87CEEB).withOpacity(0.82),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF87CEEB).withOpacity(0.36),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.10),
                      Colors.transparent,
                      Colors.black.withOpacity(0.05),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
