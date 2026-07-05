import 'package:flutter/material.dart';
import '../../models/name_style.dart';

/// Renders a player's name with an optional cosmetic colour/gradient.
///
/// When [styleId] is null/'none', the [base] style is used unchanged (so
/// context colours like "me = cyan" are preserved). A single-colour style
/// overrides the colour; a multi-colour style paints a gradient via ShaderMask.
class PlayerNameText extends StatelessWidget {
  final String text;
  final TextStyle base;
  final String? styleId;
  final int maxLines;
  final TextOverflow overflow;
  final TextAlign? textAlign;

  const PlayerNameText({
    super.key,
    required this.text,
    required this.base,
    this.styleId,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final style = nameStyleFor(styleId);

    if (style.isNone) {
      return Text(text,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
          style: base);
    }

    if (!style.isGradient) {
      return Text(text,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
          style: base.copyWith(color: style.colors.first));
    }

    // Gradient: paint white text and mask it with the gradient.
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: style.colors,
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
      ).createShader(bounds),
      child: Text(text,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
          style: base.copyWith(color: Colors.white)),
    );
  }
}
