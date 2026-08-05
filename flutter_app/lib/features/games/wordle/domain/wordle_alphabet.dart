/// Letter handling for the languages the word lists are shipped in.
///
/// Every word (from the asset lists as well as from user input) is normalised
/// to upper case so that comparisons stay a plain string equality check. All
/// supported letters live in the Unicode BMP, so a normalised word can safely
/// be indexed with `word[i]`.
abstract final class WordleAlphabet {
  static const _englishLetters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _germanLetters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÜß';

  /// The keys the on-screen keyboard offers for [languageCode].
  static String lettersFor(String languageCode) =>
      isGerman(languageCode) ? _germanLetters : _englishLetters;

  static bool isGerman(String languageCode) => languageCode == 'de';

  /// Normalises a single typed character, or `null` when it is not a letter
  /// of that language.
  static String? normalizeChar(String char, String languageCode) {
    if (char.length != 1) return null;
    final unit = _normalizeUnit(char.codeUnitAt(0), isGerman(languageCode));
    return unit == null ? null : String.fromCharCode(unit);
  }

  /// Normalises a raw word list entry, or `null` when it contains anything
  /// that is not a letter of that language.
  static String? normalizeWord(String raw, String languageCode) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final german = isGerman(languageCode);
    final units = List<int>.filled(trimmed.length, 0);
    for (var i = 0; i < trimmed.length; i++) {
      final unit = _normalizeUnit(trimmed.codeUnitAt(i), german);
      if (unit == null) return null;
      units[i] = unit;
    }
    return String.fromCharCodes(units);
  }

  static int? _normalizeUnit(int unit, bool german) {
    if (unit >= 0x41 && unit <= 0x5A) return unit; // A-Z
    if (unit >= 0x61 && unit <= 0x7A) return unit - 32; // a-z
    if (!german) return null;
    return switch (unit) {
      0xE4 => 0xC4, // ä -> Ä
      0xF6 => 0xD6, // ö -> Ö
      0xFC => 0xDC, // ü -> Ü
      0xC4 || 0xD6 || 0xDC || 0xDF => unit, // Ä Ö Ü ß
      0x1E9E => 0xDF, // ẞ -> ß (kept single-width for the grid)
      _ => null,
    };
  }
}
