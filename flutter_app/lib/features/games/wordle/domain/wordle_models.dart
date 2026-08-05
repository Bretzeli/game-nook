/// Number of guesses a player gets, matching the game description on the
/// home screen ("guess the word in six tries").
const int kWordleMaxAttempts = 6;

/// Word lengths the length picker offers. Entries are only selectable when the
/// active word list holds at least [kWordleMinWordsPerLength] words of that
/// length.
const int kWordleMinLength = 3;
const int kWordleMaxLength = 11;
const int kWordleDefaultLength = 6;
const int kWordleMinWordsPerLength = 20;

/// How a single letter of a submitted guess relates to the solution.
enum LetterStatus { correct, present, absent }

/// Which asset list the solution is drawn from.
enum WordleDifficulty {
  normal('guessable.txt'),
  difficult('difficult.txt'),
  allWords('all.txt');

  const WordleDifficulty(this.fileName);

  final String fileName;
}

enum WordlePhase { loading, playing, won, lost, failed }

extension WordlePhaseX on WordlePhase {
  bool get isFinished => this == WordlePhase.won || this == WordlePhase.lost;
}

/// A row on the board that has been revealed: either a submitted guess or the
/// solution shown after the player gave up.
class WordleRow {
  const WordleRow({
    required this.word,
    required this.statuses,
    this.isSolution = false,
  });

  final String word;
  final List<LetterStatus> statuses;

  /// `true` when this row was filled in by "give up" rather than guessed, so
  /// it neither counts as a hint nor colours the keyboard.
  final bool isSolution;
}

/// Why a submitted guess was not accepted.
enum WordleRejectionKind { tooShort, notInWordList, hardMode }

enum HardModeViolationKind {
  /// A green letter was moved away from its known position.
  fixedPosition,

  /// A letter known to be in the word is missing.
  missingLetter,

  /// A letter known to be absent was used.
  forbiddenLetter,

  /// A yellow letter was left at the position it was already ruled out for.
  mustMove,
}

class HardModeViolation {
  const HardModeViolation({
    required this.kind,
    required this.letter,
    this.position = 0,
  });

  final HardModeViolationKind kind;
  final String letter;

  /// One-based position, only meaningful for the positional kinds.
  final int position;
}

class WordleRejection {
  const WordleRejection(this.kind, {this.violation});

  const WordleRejection.tooShort() : this(WordleRejectionKind.tooShort);

  const WordleRejection.notInWordList()
    : this(WordleRejectionKind.notInWordList);

  WordleRejection.hardMode(HardModeViolation violation)
    : this(WordleRejectionKind.hardMode, violation: violation);

  final WordleRejectionKind kind;
  final HardModeViolation? violation;
}
