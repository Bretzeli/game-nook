import '../../wordle_shared/domain/wordle_board.dart';
import '../../wordle_shared/domain/wordle_models.dart';
import '../../wordle_shared/state/wordle_board_controller.dart';
import '../domain/wordle_game_models.dart';

class WordleGameState implements WordleBoardState<WordleGameState> {
  const WordleGameState({
    required this.board,
    required this.difficulty,
    required this.phase,
    required this.solutionPool,
    required this.hintsUsed,
  });

  /// A game waiting for its word lists — or, when [failed], one whose lists
  /// could not be read.
  WordleGameState.loading({
    required String languageCode,
    required int wordLength,
    required this.difficulty,
    bool failed = false,
  }) : board = WordleBoard.empty(
         languageCode: languageCode,
         wordLength: wordLength,
       ),
       phase = failed ? WordlePhase.failed : WordlePhase.loading,
       solutionPool = const [],
       hintsUsed = 0;

  @override
  final WordleBoard board;

  final WordleDifficulty difficulty;
  final WordlePhase phase;

  /// The words the solution was drawn from — the set hints pick from, so a
  /// hint is always a word that could plausibly have been the answer.
  final List<String> solutionPool;

  /// Hints taken in this round, shown on the hint button.
  final int hintsUsed;

  bool get isPlaying => phase == WordlePhase.playing;

  bool get canGiveUp => isPlaying && board.hasSolution;

  int get maxAttempts => wordleMaxAttempts(board.wordLength);

  @override
  bool get acceptsInput => isPlaying;

  @override
  WordleGameState withBoard(WordleBoard board) => copyWith(board: board);

  WordleGameState copyWith({
    WordleBoard? board,
    WordlePhase? phase,
    int? hintsUsed,
  }) {
    return WordleGameState(
      board: board ?? this.board,
      difficulty: difficulty,
      phase: phase ?? this.phase,
      solutionPool: solutionPool,
      hintsUsed: hintsUsed ?? this.hintsUsed,
    );
  }
}
