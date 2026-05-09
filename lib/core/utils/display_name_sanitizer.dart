import 'dart:math';

class DisplayNameSanitizer {
  // Hebrew U+0590–05FF, Hebrew presentation forms U+FB1D–FB4E, Latin, digits, space.
  static final _validChars = RegExp(
    r'^[֐-׿יִ-פֿa-zA-Z0-9 ]+$',
  );
  // Control chars (U+0000–001F), DEL (U+007F), C1 controls (U+0080–009F),
  // and common invisible Unicode: zero-width space through zero-width joiner,
  // LRM/RLM, Unicode direction markers, BOM.
  static final _invisibleChars = RegExp(
    r'[\x00-\x1f\x7f-\x9f]',
  );
  static final _multiSpace = RegExp(r' {2,}');

  static const _guestPrefixes = ['אורח', 'שחקן'];

  /// Returns the sanitized name, or null if it fails validation.
  static String? sanitize(String? raw) {
    if (raw == null) return null;
    var name = raw
        .replaceAll(_invisibleChars, '')
        .trim()
        .replaceAll(_multiSpace, ' ');
    if (name.length < 2 || name.length > 16) return null;
    if (!_validChars.hasMatch(name)) return null;
    return name;
  }

  /// Generates a random Hebrew guest name: e.g. "אורח452" or "שחקן731".
  static String guestFallback() {
    final rng = Random();
    final prefix = _guestPrefixes[rng.nextInt(_guestPrefixes.length)];
    final suffix = 100 + rng.nextInt(900);
    return '$prefix$suffix';
  }
}
