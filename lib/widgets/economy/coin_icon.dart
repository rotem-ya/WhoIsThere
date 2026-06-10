import 'package:flutter/material.dart';

/// Unified coin icon. Replaces the 🪙 emoji, which the OS renders differently
/// per platform (Apple draws an angled coin that looks like a crescent/"moon"
/// on iOS, Google a flat coin on Android). A Material glyph renders identically
/// on both platforms.
class CoinIcon extends StatelessWidget {
  final double size;
  final Color color;
  const CoinIcon({super.key, this.size = 16, this.color = const Color(0xFFFFC107)});

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.monetization_on, size: size, color: color);
}

/// Inline coin for use inside [Text.rich] / [TextSpan], so the coin sits on the
/// text baseline exactly where the emoji used to be.
WidgetSpan coinSpan({double size = 14, Color color = const Color(0xFFFFC107)}) =>
    WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: CoinIcon(size: size, color: color),
      ),
    );
