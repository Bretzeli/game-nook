import '../domain/wordle_models.dart';

class WordleGameState {
  const WordleGameState({
    required this.languageCode,
    required this.wordLength,
    required this.difficulty,
    required this.phase,
    required this.solution,
    required this.rows,
    required this.input,
    required this.cursor,
    required this.acceptedWords,
    required this.round,
  });

  WordleGameState.loading({
    required this.languageCode,
    required this.wordLength,
    required this.difficulty,
  }) : phase = WordlePhase.loading,
       solution = '',
       rows = const [],
       input = const [],
       cursor = 0,
       acceptedWords = const {},
       round = 0;

  final String languageCode;
  final int wordLength;
  final WordleDifficulty difficulty;
  final WordlePhase phase;
  final String solution;

  /// Rows already submitted (or filled in by giving up), oldest first.
  final List<WordleRow> rows;

  /// The row being typed; empty slots hold an empty string.
  final List<String> input;

  /// Caret position, `0..wordLength`. Equal to [wordLength] once the row is
  /// full, which is when typing stops having an effect.
  final int cursor;

  final Set<String> acceptedWords;

  /// Bumped for every new game so the board can reset its animations.
  final int round;

  bool get isPlaying => phase == WordlePhase.playing;

  bool get canGiveUp => isPlaying && solution.isNotEmpty;

  int get maxAttempts => wordleMaxAttempts(wordLength);

  int get attemptsUsed => rows.where((row) => !row.isSolution).length;

  String get typedWord => input.join();

  bool get isInputComplete =>
      input.length == wordLength && input.every((letter) => letter.isNotEmpty);

  WordleGameState copyWith({
    WordlePhase? phase,
    List<WordleRow>? rows,
    List<String>? input,
    int? cursor,
  }) {
    return WordleGameState(
      languageCode: languageCode,
      wordLength: wordLength,
      difficulty: difficulty,
      phase: phase ?? this.phase,
      solution: solution,
      rows: rows ?? this.rows,
      input: input ?? this.input,
      cursor: cursor ?? this.cursor,
      acceptedWords: acceptedWords,
      round: round,
    );
  }
}
