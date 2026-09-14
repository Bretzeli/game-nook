import 'dart:math';

import '../../wordle_shared/domain/wordle_models.dart';
import 'dont_wordle_models.dart';

/// Where a round stands once [rows] have been played against [solution].
///
/// [wordsLeft] holds how many words fit every hint before the first guess and
/// after each one since. The round is lost the moment a guess hits the
/// solution, or leaves it as the only word of every list that still fits
/// while more guesses still have to miss it. After [avoidAttempts] guesses
/// survived, [findAttempts] more are for actually finding it — however few
/// words are left by then.
///
/// Deriving this from the rows rather than storing it keeps it in step with
/// the board, down to showing the round as it stood a few rows ago while the
/// latest ones are still turning over.
DontWordleProgress dontWordleProgress({
  required Iterable<WordleRow> rows,
  required String solution,
  required List<DontWordleWordsLeft> wordsLeft,
  required int avoidAttempts,
  int findAttempts = kDontWordleFindAttempts,
}) {
  var guesses = 0;

  /// The round at its [guess]th guess, counted over both parts.
  DontWordleProgress at(int guess, [DontWordleOutcome? outcome]) {
    final avoiding = guess <= avoidAttempts;
    return DontWordleProgress(
      phase: outcome != null
          ? DontWordlePhase.finished
          : avoiding
          ? DontWordlePhase.avoiding
          : DontWordlePhase.finding,
      outcome: outcome,
      attempt: avoiding ? guess : guess - avoidAttempts,
      attempts: avoiding ? avoidAttempts : findAttempts,
      wordsLeft: wordsLeft.isEmpty
          ? (words: 0, solutions: 0)
          : wordsLeft[min(guesses, wordsLeft.length - 1)],
      hasSurvived:
          guesses >= avoidAttempts &&
          outcome != DontWordleOutcome.hitSolution &&
          outcome != DontWordleOutcome.cornered,
    );
  }

  for (final row in rows) {
    if (row.isSolution) return at(guesses + 1, DontWordleOutcome.gaveUp);

    guesses++;
    final hit = row.word == solution;
    if (guesses <= avoidAttempts) {
      if (hit) return at(guesses, DontWordleOutcome.hitSolution);
      // Only a guess still to be made has to miss a word that is the only one
      // left; after the last of them, that word is simply the one to find.
      if (guesses < avoidAttempts &&
          wordsLeft.length > guesses &&
          wordsLeft[guesses].words <= 1) {
        return at(guesses, DontWordleOutcome.cornered);
      }
    } else if (hit) {
      return at(guesses, DontWordleOutcome.solved);
    }
  }

  if (guesses >= avoidAttempts + findAttempts) {
    return at(guesses, DontWordleOutcome.survived);
  }
  return at(guesses + 1);
}

/// The word a hint fills in: one that fits every hint but is not [solution]
/// — preferably one that could have been the solution, otherwise any word of
/// the lists. `null` when nothing but the solution fits.
///
/// [possibleSolutions] and [possibleWords] are the words of the solution list
/// and of every list that still fit, as the round keeps them.
String? dontWordleHintWord({
  required List<String> possibleSolutions,
  required List<String> possibleWords,
  required String solution,
  required Random random,
}) {
  for (final words in [possibleSolutions, possibleWords]) {
    final others = words.length - (words.contains(solution) ? 1 : 0);
    if (others <= 0) continue;

    // Picks the n-th word that is not the solution without copying the list.
    var skip = random.nextInt(others);
    for (final word in words) {
      if (word == solution) continue;
      if (skip-- == 0) return word;
    }
  }
  return null;
}
