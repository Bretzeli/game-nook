import 'dart:math';

import '../../../../core/words/word_alphabet.dart';
import 'spelling_bee_models.dart';
import 'spelling_bee_word_index.dart';

/// How many letter sets are tried before the best one seen has to do.
const int kBeeBuildAttempts = 80;

/// A round should be winnable in one sitting without being over in three
/// words, so the yellow bar decides whether a letter set is worth playing.
const int kBeeMinNormalWords = 12;
const int kBeeMaxNormalWords = 40;

/// Below this there is too little to look for, however the words are split.
const int kBeeMinListedWords = 28;

/// Draws a puzzle: seven letters, the words they spell, and how those words
/// are split across the tiers.
///
/// The letter set is seeded from a pangram in the *normal* list, which pins
/// down two things at once — the seven letters can spell at least one word,
/// and that word is an everyday one, so the pangram bonus is within reach
/// rather than a lottery on some dictionary curiosity.
BeePuzzle buildBeePuzzle(BeeWordIndex index, Random random) {
  if (index.isEmpty) return BeePuzzle.empty();

  final alphabet = index.alphabet;
  final seeds = _seedLetterSets(index);
  if (seeds.isEmpty) return BeePuzzle.empty();

  _Candidate? best;
  for (var attempt = 0; attempt < kBeeBuildAttempts; attempt++) {
    final letters = seeds[random.nextInt(seeds.length)];
    final candidate = _evaluate(index, letters, _pickCenter(letters, random));
    if (candidate.isPlayable) {
      best = candidate;
      break;
    }
    if (best == null || candidate.beats(best)) best = candidate;
  }
  final chosen = best!;

  final bonusWords = <String>{};
  index.accepted.forEachWordIn(chosen.letters, chosen.center, (word) {
    if (word.length >= kBeeMinWordLength &&
        !chosen.listedWords.containsKey(word)) {
      bonusWords.add(word);
    }
  });

  final centerLetter = beeLettersOf(chosen.center, alphabet).first;
  final outerLetters = beeLettersOf(chosen.letters, alphabet)
    ..remove(centerLetter)
    ..shuffle(random);

  return BeePuzzle(
    languageCode: index.languageCode,
    centerLetter: centerLetter,
    outerLetters: outerLetters,
    listedWords: chosen.listedWords,
    bonusWords: bonusWords,
  );
}

_Candidate _evaluate(BeeWordIndex index, int letters, int center) {
  final words = <String, BeeTier>{};

  void collect(BeeWordSet set, BeeTier tier) {
    set.forEachWordIn(letters, center, (word) {
      if (word.length < kBeeMinWordLength) return;
      words.putIfAbsent(word, () => tier);
    });
  }

  collect(index.normal, BeeTier.normal);
  final normalCount = words.length;
  collect(index.difficult, BeeTier.difficult);

  return _Candidate(
    letters: letters,
    center: center,
    listedWords: words,
    normalCount: normalCount,
  );
}

/// Distinct seven-letter sets that at least one everyday word spells.
///
/// English drops any set containing an S: with it, half of what there is to
/// find is the plural of the other half. German keeps it — an S there is a
/// letter like any other rather than a plural machine.
List<int> _seedLetterSets(BeeWordIndex index) {
  final alphabet = index.alphabet;
  final banned = WordAlphabet.isGerman(index.languageCode)
      ? 0
      : 1 << alphabet.indexOf('S');

  // Falls back to the wider lists so that a language (or a test) whose common
  // list holds no pangram at all still gets a puzzle.
  for (final set in [index.normal, index.difficult, index.accepted]) {
    final masks = set.masks;
    if (masks == null) continue;
    final seeds = <int>{};
    for (var i = 0; i < masks.length; i++) {
      final mask = masks[i];
      if (mask & banned != 0) continue;
      if (beeLetterCount(mask) == kBeeLetterCount) seeds.add(mask);
    }
    if (seeds.isNotEmpty) return seeds.toList();
  }
  return const [];
}

int _pickCenter(int letters, Random random) {
  final bits = <int>[];
  for (var bit = 0; bit < 32; bit++) {
    if (letters & (1 << bit) != 0) bits.add(1 << bit);
  }
  return bits[random.nextInt(bits.length)];
}

/// One letter set with one centre letter, and what it would play like.
class _Candidate {
  const _Candidate({
    required this.letters,
    required this.center,
    required this.listedWords,
    required this.normalCount,
  });

  final int letters;
  final int center;
  final Map<String, BeeTier> listedWords;
  final int normalCount;

  bool get isPlayable =>
      normalCount >= kBeeMinNormalWords &&
      normalCount <= kBeeMaxNormalWords &&
      listedWords.length >= kBeeMinListedWords;

  /// Ranks the fallbacks: a fuller yellow bar first (but no credit for
  /// overshooting what one sitting can hold), then more to find overall.
  bool beats(_Candidate other) {
    final mine = min(normalCount, kBeeMaxNormalWords);
    final theirs = min(other.normalCount, kBeeMaxNormalWords);
    if (mine != theirs) return mine > theirs;
    return listedWords.length > other.listedWords.length;
  }
}
