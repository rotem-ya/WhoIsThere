import 'package:flutter/material.dart';

class VaultGemTile extends StatelessWidget {
  final bool isRevealed;
  final Widget child;

  const VaultGemTile({
    super.key,
    required this.isRevealed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: isRevealed ? _buildRevealed() : _buildHidden(),
    );
  }

  Widget _buildHidden() {
    return Container(
      key: const ValueKey('vault_hidden'),
      decoration: BoxDecoration(
        color: const Color(0xFF050A14),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFFC5A021),
          width: 1.5,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.question_mark,
          color: Color(0xFFD4AF37),
          size: 26,
        ),
      ),
    );
  }

  Widget _buildRevealed() {
    return Container(
      key: const ValueKey('vault_revealed'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFF87CEEB),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: child,
      ),
    );
  }
}
