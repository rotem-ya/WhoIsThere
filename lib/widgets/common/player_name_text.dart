import 'package:flutter/material.dart';

/// Renders a player's name as plain text.
///
/// Name-colour cosmetics were removed from the store; names now always render
/// in the given [base] style. [styleId] is accepted (and ignored) so existing
/// call sites keep compiling without change.
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
    return Text(text,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
        style: base);
  }
}
