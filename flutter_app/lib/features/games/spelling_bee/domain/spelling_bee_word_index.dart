import 'dart:typed_data';

import '../../../../core/words/word_alphabet.dart';
import 'spelling_bee_models.dart';

/// A word list with a letter bitmask per word.
///
/// Building a puzzle asks the same question of every word many times over —
/// "can these seven letters spell it?" — which is a single `&` once each word
/// is reduced to the set of letters it uses. The masks are built while the
/// asset is parsed (off the UI isolate) and travel with the words.
class BeeWordSet {
  const BeeWordSet({required this.words, required this.masks});

  const BeeWordSet.empty() : words = const [], masks = null;

  factory BeeWordSet.build(List<String> words, String languageCode) {
    final bits = _bitsFor(languageCode);
    final masks = Uint32List(words.length);
    for (var i = 0; i < words.length; i++) {
      masks[i] = beeLetterMask(words[i], bits);
    }
    return BeeWordSet(words: words, masks: masks);
  }

  final List<String> words;

  /// Bit `i` is set when the word uses letter `i` of its language's alphabet.
  /// `null` only for [BeeWordSet.empty], which holds no words either.
  final Uint32List? masks;

  int get length => words.length;

  /// Calls [visit] for every word that [letters] can spell and that uses the
  /// [center] letter — the two rules every word in a puzzle has to follow.
  void forEachWordIn(int letters, int center, void Function(String) visit) {
    final masks = this.masks;
    if (masks == null) return;
    for (var i = 0; i < masks.length; i++) {
      final mask = masks[i];
      if (mask & center == 0 || mask & ~letters != 0) continue;
      visit(words[i]);
    }
  }
}

/// Everything one language needs to make and judge a puzzle.
class BeeWordIndex {
  const BeeWordIndex({
    required this.languageCode,
    required this.normal,
    required this.difficult,
    required this.accepted,
  });

  const BeeWordIndex.empty(this.languageCode)
    : normal = const BeeWordSet.empty(),
      difficult = const BeeWordSet.empty(),
      accepted = const BeeWordSet.empty();

  final String languageCode;

  /// The two listed tiers, each the source of one bar.
  final BeeWordSet normal;
  final BeeWordSet difficult;

  /// Every word the language accepts. What is in here but in neither list
  /// above scores as [BeeTier.bonus].
  final BeeWordSet accepted;

  bool get isEmpty => normal.length == 0 || accepted.length == 0;

  String get alphabet => WordAlphabet.lettersFor(languageCode);
}

/// Bit index per letter code unit, so a mask can be built with one map lookup
/// per character instead of a scan of the alphabet.
Map<int, int> _bitsFor(String languageCode) {
  final letters = WordAlphabet.lettersFor(languageCode);
  return {
    for (var i = 0; i < letters.length; i++) letters.codeUnitAt(i): i,
  };
}

/// The set of letters [word] uses, as a bitmask over its language's alphabet.
int beeLetterMask(String word, Map<int, int> bits) {
  var mask = 0;
  for (var i = 0; i < word.length; i++) {
    final bit = bits[word.codeUnitAt(i)];
    // Word lists are normalised before they get here, so an unknown letter
    // can only come from a language mix-up: mask it as "uses everything" and
    // the word simply never fits into a hive.
    if (bit == null) return 0xFFFFFFFF;
    mask |= 1 << bit;
  }
  return mask;
}

int beeLetterMaskOf(String word, String languageCode) =>
    beeLetterMask(word, _bitsFor(languageCode));

/// How many letters a mask holds.
int beeLetterCount(int mask) {
  var count = 0;
  var rest = mask;
  while (rest != 0) {
    rest &= rest - 1;
    count++;
  }
  return count;
}

/// The letters of [mask], in alphabetical order.
List<String> beeLettersOf(int mask, String alphabet) => [
  for (var i = 0; i < alphabet.length; i++)
    if (mask & (1 << i) != 0) alphabet[i],
];
