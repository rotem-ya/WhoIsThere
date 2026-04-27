class LetterGridBuilder {
  /// Distributes each character of [answer] evenly across a [gridSize]×[gridSize]
  /// grid. Returns a map of cellIndex → character (String keys for Firestore).
  static Map<String, String> build(String answer, int gridSize) {
    final totalCells = gridSize * gridSize;
    final chars = _toChars(answer);
    if (chars.isEmpty) return {};

    final result = <String, String>{};
    final spacing = totalCells / chars.length;
    for (int i = 0; i < chars.length; i++) {
      final cellIndex = ((i + 0.5) * spacing).round().clamp(0, totalCells - 1);
      result[cellIndex.toString()] = chars[i];
    }
    return result;
  }

  /// Returns the cell index that hosts character at [charIndex].
  static int cellForChar(int charIndex, int totalChars, int gridSize) {
    final totalCells = gridSize * gridSize;
    final spacing = totalCells / totalChars;
    return ((charIndex + 0.5) * spacing).round().clamp(0, totalCells - 1);
  }

  /// Unicode-safe character split (handles Hebrew, emoji, etc.).
  static List<String> _toChars(String s) =>
      s.runes.map(String.fromCharCode).toList();
}
