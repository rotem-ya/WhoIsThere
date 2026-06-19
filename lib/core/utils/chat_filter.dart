/// Very small, best-effort profanity mask for the in-game text chat. Not a
/// content-moderation system — just blanks out the most common Hebrew/English
/// swear words so casual abuse doesn't show verbatim. Easy to extend.
class ChatFilter {
  ChatFilter._();

  static const List<String> _bad = [
    // Hebrew (common)
    'זין', 'זיין', 'כוס', 'כוסון', 'שרמוטה', 'בן זונה', 'בנזונה', 'זונה',
    'מניאק', 'מטומטם', 'חרא', 'מפגר', 'נכה', 'דביל', 'אידיוט', 'תזדיין',
    'תמות', 'לך תמות', 'הומו', 'לסבית',
    // English (common)
    'fuck', 'fucker', 'fucking', 'shit', 'bitch', 'asshole', 'cunt', 'dick',
    'bastard', 'slut', 'whore', 'retard', 'faggot',
  ];

  /// Returns the text with any blacklisted word replaced by bullets, trimmed and
  /// length-capped. Returns empty if nothing usable remains.
  static String clean(String input) {
    var text = input.trim();
    if (text.length > 120) text = text.substring(0, 120);
    if (text.isEmpty) return '';
    for (final w in _bad) {
      if (w.trim().isEmpty) continue;
      final re = RegExp(RegExp.escape(w), caseSensitive: false);
      text = text.replaceAll(re, '•' * w.length);
    }
    return text;
  }
}
