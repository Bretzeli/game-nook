import '../../wordle_shared/domain/wordle_board.dart';
import '../../wordle_shared/state/wordle_board_controller.dart';
import '../domain/dont_wordle_models.dart';
import '../domain/dont_wordle_rules.dart';

class DontWordleGameState implements WordleBoardState<DontWordleGameState> {
  DontWordleGameState({
    required this.board,
    required this.status,
    required this.avoidAttempts,
    required this.possibleWords,
    required this.possibleSolutions,
    required this.wordsLeft,
    required this.hintsUsed,
  }) : progress = dontWordleProgress(
         rows: board.rows,
         solution: board.solution,
         wordsLeft: wordsLeft,
         avoidAttempts: avoidAttempts,
       );

  /// A fresh round in which every word is still in play.
  DontWordleGameState.start({
    required WordleBoard board,
    required int avoidAttempts,
    required List<String> solutionPool,
  }) : this(
         board: board,
         status: DontWordleStatus.ready,
         avoidAttempts: avoidAttempts,
         possibleWords: board.acceptedWords.toList(growable: false),
         possibleSolutions: solutionPool,
         wordsLeft: [
           (words: board.acceptedWords.length, solutions: solutionPool.length),
         ],
         hintsUsed: 0,
       );

  /// A game waiting for its word lists — or, when [failed], one whose lists
  /// could not be read.
  DontWordleGameState.loading({
    required String languageCode,
    required int wordLength,
    required int avoidAttempts,
    bool failed = false,
  }) : this(
         board: WordleBoard.empty(
           languageCode: languageCode,
           wordLength: wordLength,
         ),
         status: failed ? DontWordleStatus.failed : DontWordleStatus.loading,
         avoidAttempts: avoidAttempts,
         possibleWords: const [],
         possibleSolutions: const [],
         wordsLeft: const [],
         hintsUsed: 0,
       );

  @override
  final WordleBoard board;

  final DontWordleStatus status;

  /// Guesses to survive in this round.
  final int avoidAttempts;

  /// Words from every word list that still fit every hint.
  final List<String> possibleWords;

  /// Words that still fit every hint and can actually be the solution — the
  /// solution always among them.
  final List<String> possibleSolutions;

  /// How many of both there were before the first guess and after each guess
  /// since.
  final List<DontWordleWordsLeft> wordsLeft;

  /// Hints taken in this round, shown on the hint button.
  final int hintsUsed;

  /// Where the round stands after every row on the board.
  final DontWordleProgress progress;

  bool get isReady => status == DontWordleStatus.ready;

  bool get canGiveUp => acceptsInput;

  /// Whether a hint has anything to offer: some word other than the solution
  /// still fits.
  bool get canHint => acceptsInput && possibleWords.length > 1;

  /// Where the round stood after its first [revealedRows] rows — what the
  /// player may know while later rows are still turning over.
  DontWordleProgress progressAfter(int revealedRows) => dontWordleProgress(
    rows: board.rows.take(revealedRows),
    solution: board.solution,
    wordsLeft: wordsLeft,
    avoidAttempts: avoidAttempts,
  );

  /// Rows on the board after [revealedRows] have turned over: the ones to
  /// survive, joined by the ones to find the word once they are earned.
  int rowCountAfter(int revealedRows) =>
      avoidAttempts +
      (progressAfter(revealedRows).hasSurvived ? kDontWordleFindAttempts : 0);

  @override
  bool get acceptsInput => isReady && !progress.isFinished;

  @override
  DontWordleGameState withBoard(WordleBoard board) => copyWith(board: board);

  DontWordleGameState copyWith({
    WordleBoard? board,
    List<String>? possibleWords,
    List<String>? possibleSolutions,
    List<DontWordleWordsLeft>? wordsLeft,
    int? hintsUsed,
  }) {
    return DontWordleGameState(
      board: board ?? this.board,
      status: status,
      avoidAttempts: avoidAttempts,
      possibleWords: possibleWords ?? this.possibleWords,
      possibleSolutions: possibleSolutions ?? this.possibleSolutions,
      wordsLeft: wordsLeft ?? this.wordsLeft,
      hintsUsed: hintsUsed ?? this.hintsUsed,
    );
  }
}
