/// A hive holds one centre letter plus six outer ones.
const int kBeeLetterCount = 7;
const int kBeeOuterLetterCount = kBeeLetterCount - 1;

/// Shorter than this and a word is not worth looking for.
const int kBeeMinWordLength = 4;

/// A word that uses every letter of the hive is worth the whole alphabet of
/// the puzzle, so it pays like it.
const int kBeePangramBonus = 7;

/// Words neither list knows are the reward for a wide vocabulary: they score
/// their length like any other word, plus this.
const int kBeeRareBonus = 3;

/// Which of the two listed word pools a word belongs to — or neither.
enum BeeTier {
  /// Everyday words: the yellow bar, and the one a round is really about.
  normal,

  /// Words the language knows but rarely uses: the silver bar.
  difficult,

  /// Anything else the language accepts. These are never listed (there are
  /// hundreds per puzzle) and never asked for — they only pay bonus points.
  bonus,
}

/// The two tiers that have a bar of their own, in the order they are shown.
const List<BeeTier> kBeeListedTiers = [BeeTier.normal, BeeTier.difficult];

enum BeePhase { loading, playing, finished, failed }

/// One puzzle: seven letters and every word they can spell.
class BeePuzzle {
  BeePuzzle({
    required this.languageCode,
    required this.centerLetter,
    required this.outerLetters,
    required this.listedWords,
    required this.bonusWords,
  }) : letters = {centerLetter, ...outerLetters},
       maxPoints = {
         for (final tier in kBeeListedTiers)
           tier: _sumPoints(
             listedWords.entries
                 .where((entry) => entry.value == tier)
                 .map((entry) => entry.key),
             {centerLetter, ...outerLetters},
           ),
       };

  BeePuzzle.empty()
    : languageCode = 'en',
      centerLetter = '',
      outerLetters = const [],
      letters = const {},
      listedWords = const {},
      bonusWords = const {},
      maxPoints = const {BeeTier.normal: 0, BeeTier.difficult: 0};

  final String languageCode;
  final String centerLetter;

  /// The six letters around the centre, in no particular order — the hive
  /// decides how to arrange them and may shuffle them at any time.
  final List<String> outerLetters;

  final Set<String> letters;

  /// Every word of the two listed tiers, and which one it belongs to.
  final Map<String, BeeTier> listedWords;

  /// Words that are accepted but not listed; see [BeeTier.bonus].
  final Set<String> bonusWords;

  /// Points a tier is worth in full — the maximum of its bar.
  final Map<BeeTier, int> maxPoints;

  bool get isEmpty => centerLetter.isEmpty;

  /// The tier [word] scores in, or `null` when it is not a word here.
  BeeTier? tierOf(String word) {
    final listed = listedWords[word];
    if (listed != null) return listed;
    return bonusWords.contains(word) ? BeeTier.bonus : null;
  }

  List<String> wordsOf(BeeTier tier) => [
    for (final entry in listedWords.entries)
      if (entry.value == tier) entry.key,
  ]..sort();

  int wordCountOf(BeeTier tier) =>
      listedWords.values.where((value) => value == tier).length;

  static int _sumPoints(Iterable<String> words, Set<String> letters) {
    var total = 0;
    for (final word in words) {
      total += beeWordPoints(word, letters);
    }
    return total;
  }
}

/// A word the player found, with what it was worth when they found it.
class BeeFoundWord {
  const BeeFoundWord({
    required this.word,
    required this.tier,
    required this.points,
    required this.isPangram,
  });

  final String word;
  final BeeTier tier;
  final int points;
  final bool isPangram;
}

/// Why a submitted word was not accepted.
enum BeeRejectionKind {
  tooShort,

  /// Spelled from hive letters, but without the one in the middle.
  missingCenter,

  /// Uses a letter the hive does not offer.
  badLetters,

  notAWord,
  alreadyFound,
}

class BeeRejection {
  const BeeRejection(this.kind, {this.letter = ''});

  final BeeRejectionKind kind;

  /// The letter at fault, for the kinds that can name one.
  final String letter;
}

/// Base value of [word] in a hive of [letters]: four letters are worth a
/// point, anything longer a point per letter, and using all seven letters
/// pays [kBeePangramBonus] on top.
int beeWordPoints(String word, Set<String> letters) {
  final base = word.length <= kBeeMinWordLength ? 1 : word.length;
  return base + (isBeePangram(word, letters) ? kBeePangramBonus : 0);
}

/// What [word] is worth to the player, including the bonus a rare word pays.
int beeScoreFor(String word, BeeTier tier, Set<String> letters) =>
    beeWordPoints(word, letters) +
    (tier == BeeTier.bonus ? kBeeRareBonus : 0);

bool isBeePangram(String word, Set<String> letters) =>
    letters.isNotEmpty && word.split('').toSet().containsAll(letters);
