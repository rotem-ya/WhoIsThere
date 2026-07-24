import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../theme/candy_theme.dart';

class AppScaffold extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final content = Padding(
      padding: padding,
      child: child,
    );

    final variant = ref.watch(bgVariantProvider);

    // Default to the player's chosen Candy ground so every screen shares the
    // same look; a screen may still override with its own color or gradient.
    final gradient = backgroundGradient ??
        (backgroundColor == null ? Candy.bgVariant(variant) : null);

    return Scaffold(
      backgroundColor: backgroundColor ?? Candy.bgVariantBottom(variant),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: gradient),
        child: safeArea ? SafeArea(child: content) : content,
      ),
    );
  }
}
