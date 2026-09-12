import 'spelling_bee_models.dart';

/// Checks a submitted word against the puzzle, from the most basic rule to
/// the most specific, so the player is always told the first thing that is
/// actually wrong with what they typed.
///
/// Returns `null` when the word counts.
BeeRejection? validateBeeWord(
  String word,
  BeePuzzle puzzle,
  Set<String> alreadyFound,
) {
  if (word.length < kBeeMinWordLength) {
    return const BeeRejection(BeeRejectionKind.tooShort);
  }

  for (var i = 0; i < word.length; i++) {
    if (!puzzle.letters.contains(word[i])) {
      return BeeRejection(BeeRejectionKind.badLetters, letter: word[i]);
    }
  }

  if (!word.contains(puzzle.centerLetter)) {
    return BeeRejection(
      BeeRejectionKind.missingCenter,
      letter: puzzle.centerLetter,
    );
  }

  if (alreadyFound.contains(word)) {
    return const BeeRejection(BeeRejectionKind.alreadyFound);
  }

  if (puzzle.tierOf(word) == null) {
    return const BeeRejection(BeeRejectionKind.notAWord);
  }

  return null;
}

/// How far a tier's bar has been filled, `0..1`.
double beeTierProgress(int score, int maxScore) {
  if (maxScore <= 0) return 0;
  return (score / maxScore).clamp(0.0, 1.0);
}
