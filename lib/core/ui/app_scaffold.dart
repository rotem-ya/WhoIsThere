import 'package:flutter/material.dart';

import '../theme/candy_theme.dart';

class AppScaffold extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Gradient? backgroundGradient;
  final bool safeArea;

  const AppScaffold({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.backgroundGradient,
    this.safeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: child,
    );

    // Default to the unified Candy ground so every screen shares the same
    // look; a screen may still override with its own color or gradient.
    final gradient = backgroundGradient ??
        (backgroundColor == null ? Candy.bg : null);

    return Scaffold(
      backgroundColor: backgroundColor ?? Candy.bgBottom,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: gradient),
        child: safeArea ? SafeArea(child: content) : content,
      ),
    );
  }
}
