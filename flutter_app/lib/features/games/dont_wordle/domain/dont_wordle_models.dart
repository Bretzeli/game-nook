/// Tries the player gets to actually find the word once they have survived.
const int kDontWordleFindAttempts = 2;

/// Guesses to survive, as the player can set them. Unlike Wordle, the word
/// length does not change them.
const int kDontWordleDefaultGuesses = 6;
const int kDontWordleMinGuesses = 3;
const int kDontWordleMaxGuesses = 10;

/// Whether a round has its word lists.
enum DontWordleStatus { loading, ready, failed }

/// The two parts of a round, and its end.
enum DontWordlePhase {
  /// Guessing without hitting the solution — and without leaving it as the
  /// only word that still fits every hint.
  avoiding,

  /// Survived: a couple of tries to actually find the word.
  finding,

  finished,
}

/// How a finished round ended.
enum DontWordleOutcome {
  /// Survived, then found the word.
  solved,

  /// Survived, but did not find the word.
  survived,

  /// Guessed the solution while avoiding it.
  hitSolution,

  /// A guess left the solution as the only word, of every list, that still
  /// fits — while more guesses still had to miss it.
  cornered,

  gaveUp,
}

/// How many words still fit every hint at some point of a round.
typedef DontWordleWordsLeft = ({
  /// Words from every word list.
  int words,

  /// Words that can actually be the solution.
  int solutions,
});

/// Where a round stands.
class DontWordleProgress {
  const DontWordleProgress({
    required this.phase,
    required this.attempt,
    required this.attempts,
    required this.wordsLeft,
    required this.hasSurvived,
    this.outcome,
  });

  final DontWordlePhase phase;

  /// The one-based number, within its part of the round, of the guess coming
  /// up — or, once finished, of the guess that ended the round.
  final int attempt;

  /// How many guesses that part of the round allows.
  final int attempts;

  final DontWordleWordsLeft wordsLeft;

  /// Whether every guess to survive has been made without losing — which is
  /// what earns the tries to find the word.
  final bool hasSurvived;

  /// How the round ended; set exactly when [phase] is finished.
  final DontWordleOutcome? outcome;

  bool get isFinished => phase == DontWordlePhase.finished;
}
