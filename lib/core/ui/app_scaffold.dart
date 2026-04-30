import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

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

    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.background,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: safeArea ? SafeArea(child: content) : content,
      ),
    );
  }
}
