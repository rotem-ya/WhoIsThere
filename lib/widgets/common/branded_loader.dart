import 'package:flutter/material.dart';

import '../../core/theme/candy_theme.dart';

/// A full-screen, on-brand loading state for route-level async loads (so every
/// screen shows the same Candy ground + accent while it resolves, instead of a
/// bare black scaffold with a default-blue spinner).
class BrandedLoader extends StatelessWidget {
  const BrandedLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Candy.bgBottom,
      body: const DecoratedBox(
        decoration: BoxDecoration(gradient: Candy.bg),
        child: Center(child: CircularProgressIndicator(color: Candy.teal)),
      ),
    );
  }
}
