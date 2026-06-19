import 'package:flutter/material.dart';

/// A deterministic emoji "face" + colour for a player without a photo (bots and
/// guests). Same seed → same avatar, so a player keeps a stable face. Populates
/// the HUD with characters instead of plain grey initials.
class AvatarStyle {
  final String emoji;
  final Color color;
  const AvatarStyle(this.emoji, this.color);
}

const List<String> _avatarEmojis = [
  '😎', '🦊', '🐱', '🐼', '🦁', '🐯', '🐵', '🐸', '🐙', '🦄',
  '🐶', '🐰', '🐨', '🐲', '🦉', '🐝', '🐬', '🦋', '🐧', '🦅',
  '🐢', '🐳', '🦜', '🐹', '🐻', '🐷', '🐔', '🦓', '🦒', '🐊',
];

const List<Color> _avatarColors = [
  Color(0xFF4FC3F7), Color(0xFFFF8A65), Color(0xFFBA68C8), Color(0xFF4DB6AC),
  Color(0xFFFFD54F), Color(0xFF7986CB), Color(0xFFE57373), Color(0xFF81C784),
  Color(0xFFF06292), Color(0xFF64B5F6), Color(0xFFA1887F), Color(0xFF4DD0E1),
];

AvatarStyle avatarFor(String seed) {
  var h = 0;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  final emoji = _avatarEmojis[h % _avatarEmojis.length];
  final color = _avatarColors[(h ~/ 7) % _avatarColors.length];
  return AvatarStyle(emoji, color);
}
