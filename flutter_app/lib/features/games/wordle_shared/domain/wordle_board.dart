import '../../../../core/words/word_alphabet.dart';
import 'wordle_models.dart';
import 'wordle_rules.dart';

/// Everything on a Wordle-style board: the hidden word, the rows revealed so
/// far and the row being typed.
///
/// The board knows how typing, scoring and revealing work but nothing about
/// what a game makes of it — whether a green row wins or loses, how many rows
/// there are — so every game in the family can share it. It is immutable;
/// each change returns a new board, or this very board when nothing changed.
class WordleBoard {
  const WordleBoard({
    required this.languageCode,
    required this.wordLength,
    required this.solution,
    required this.rows,
    required this.input,
    required this.cursor,
    required this.acceptedWords,
    required this.round,
  });

  /// A board without a word yet, while the word lists load or after they
  /// could not be read.
  const WordleBoard.empty({
    required this.languageCode,
    required this.wordLength,
    this.round = 0,
  }) : solution = '',
       rows = const [],
       input = const [],
       cursor = 0,
       acceptedWords = const {};

  /// A fresh round hiding [solution].
  WordleBoard.start({
    required this.languageCode,
    required this.solution,
    required this.acceptedWords,
    required this.round,
  }) : wordLength = solution.length,
       rows = const [],
       input = List<String>.filled(solution.length, ''),
       cursor = 0;

  final String languageCode;
  final int wordLength;
  final String solution;

  /// Rows already submitted (or filled in by giving up), oldest first.
  final List<WordleRow> rows;

  /// The row being typed; empty slots hold an empty string.
  final List<String> input;

  /// Caret position, `0..wordLength`. Equal to [wordLength] once the row is
  /// full, which is when typing stops having an effect.
  final int cursor;

  /// Every word a guess may be.
  final Set<String> acceptedWords;

  /// Bumped for every new game so the board can reset its animations.
  final int round;

  /// Whether there is a word to play against at all.
  bool get hasSolution => solution.isNotEmpty;

  /// Rows the player actually guessed, leaving out a revealed solution.
  int get guessCount => rows.where((row) => !row.isSolution).length;

  String get typedWord => input.join();

  bool get isInputComplete =>
      input.length == wordLength && input.every((letter) => letter.isNotEmpty);

  /// Writes [character] into the selected slot and moves on, if it is a
  /// letter of the board's language and there is a slot left.
  WordleBoard typeLetter(String character) {
    if (!hasSolution || cursor >= wordLength) return this;
    final letter = WordAlphabet.normalizeChar(character, languageCode);
    if (letter == null) return this;

    return _copyWith(
      input: [...input]..[cursor] = letter,
      cursor: cursor + 1,
    );
  }

  WordleBoard backspace() {
    if (!hasSolution) return this;

    // A tapped-on letter is "selected" at the cursor itself; deleting should
    // clear that slot in place rather than the one before it.
    if (cursor < wordLength && input[cursor].isNotEmpty) {
      return _copyWith(input: [...input]..[cursor] = '');
    }

    // Nothing occupies the cursor slot (the normal post-typing position), so
    // fall back to auto-selecting and clearing the last filled letter.
    final target = cursor > 0 ? cursor - 1 : 0;
    if (target == cursor && input[target].isEmpty) return this;
    return _copyWith(input: [...input]..[target] = '', cursor: target);
  }

  /// Lets the player overwrite from a specific slot instead of the start.
  WordleBoard selectSlot(int index) {
    if (!hasSolution || index < 0 || index >= wordLength || index == cursor) {
      return this;
    }
    return _copyWith(cursor: index);
  }

  WordleBoard moveCursor(int delta) {
    if (!hasSolution) return this;
    final target = (cursor + delta).clamp(0, wordLength);
    if (target == cursor) return this;
    return _copyWith(cursor: target);
  }

  /// Replaces the typed row with [word] — a hint, or the solution on request.
  WordleBoard fillInput(String word) {
    if (!hasSolution || word.length != wordLength) return this;
    return _copyWith(input: word.split(''), cursor: wordLength);
  }

  /// Why the typed row cannot be submitted, or `null` when it can.
  ///
  /// [hardMode] demands that every revealed hint is used; [rejectRepeats]
  /// turns down a word that has already been guessed this round.
  WordleRejection? validateInput({
    required bool hardMode,
    bool rejectRepeats = false,
  }) {
    if (!isInputComplete) return const WordleRejection.tooShort();

    final guess = typedWord;
    if (!acceptedWords.contains(guess) && guess != solution) {
      return const WordleRejection.notInWordList();
    }

    if (rejectRepeats &&
        rows.any((row) => !row.isSolution && row.word == guess)) {
      return const WordleRejection.alreadyGuessed();
    }

    if (hardMode) {
      final violation = HardModeConstraints.fromRows(rows).validate(guess);
      if (violation != null) return WordleRejection.hardMode(violation);
    }
    return null;
  }

  /// Scores the typed row, appends it and clears the row for the next guess.
  /// Check [validateInput] first: this does not.
  WordleBoard submitInput() {
    final guess = typedWord;
    return _copyWith(
      rows: [
        ...rows,
        WordleRow(word: guess, statuses: evaluateGuess(guess, solution)),
      ],
      input: List<String>.filled(wordLength, ''),
      cursor: 0,
    );
  }

  /// Writes the solution into the next free row, as giving up does.
  WordleBoard revealSolution() {
    if (!hasSolution) return this;
    return _copyWith(
      rows: [
        ...rows,
        WordleRow(
          word: solution,
          statuses: List<LetterStatus>.filled(
            wordLength,
            LetterStatus.correct,
          ),
          isSolution: true,
        ),
      ],
      input: List<String>.filled(wordLength, ''),
      cursor: 0,
    );
  }

  WordleBoard _copyWith({
    List<WordleRow>? rows,
    List<String>? input,
    int? cursor,
  }) {
    return WordleBoard(
      languageCode: languageCode,
      wordLength: wordLength,
      solution: solution,
      rows: rows ?? this.rows,
      input: input ?? this.input,
      cursor: cursor ?? this.cursor,
      acceptedWords: acceptedWords,
      round: round,
    );
  }
}
