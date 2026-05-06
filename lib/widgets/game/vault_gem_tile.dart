import 'package:flutter/material.dart';

class VaultGemTile extends StatelessWidget {
  final bool isRevealed;
  final bool isFocused;
  final Widget child;

  const VaultGemTile({
    super.key,
    required this.isRevealed,
    required this.child,
    this.isFocused = false,
  });

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _navyBlack = Color(0xFF050A14);
  static const Color _cyan = Color(0xFF87CEEB);

  @override
  Widget build(BuildContext context) {
    return isRevealed ? _revealed() : _hidden();
  }

  Widget _hidden() {
    return Container(
      key: const ValueKey('vault_hidden'),
      decoration: BoxDecoration(
        color: _navyBlack,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFocused ? _cyan : _gold.withOpacity(0.30),
          width: isFocused ? 2.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.62), blurRadius: 9, offset: const Offset(0, 5)),
          if (isFocused) BoxShadow(color: _cyan.withOpacity(0.30), blurRadius: 12, spreadRadius: 1),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white.withOpacity(0.055), Colors.transparent, Colors.black.withOpacity(0.18)],
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.lock_outline_rounded,
              color: _gold.withOpacity(isFocused ? 0.44 : 0.24),
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _revealed() {
    return Container(
      key: const ValueKey('vault_revealed'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold.withOpacity(0.80), width: 1.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: child,
      ),
    );
  }
}
