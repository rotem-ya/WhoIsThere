import 'package:flutter/material.dart';

class VaultPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const VaultPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(10),
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF07101F).withOpacity(0.72),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: const Color(0xFFD4AF37).withOpacity(0.34),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.38),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.08),
            blurRadius: 26,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }
}
