import 'package:flutter/material.dart';
import '../../core/theme/candy_theme.dart';
import '../../core/ui/app_spacing.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: Candy.jellyFill(Candy.surface),
        borderRadius: BorderRadius.circular(radius),
        border: Candy.rim(width: 2, opacity: 0.22),
        boxShadow: [
          BoxShadow(
            color: Candy.bevel(Candy.surface),
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.30),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
