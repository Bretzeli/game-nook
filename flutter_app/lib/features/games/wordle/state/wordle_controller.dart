import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/locale_notifier.dart';
import '../../wordle_shared/domain/wordle_board.dart';
import '../../wordle_shared/domain/wordle_models.dart';
import '../../wordle_shared/domain/wordle_rules.dart';
import '../../wordle_shared/state/wordle_board_controller.dart';
import '../domain/wordle_game_models.dart';
import 'wordle_game_state.dart';
import 'wordle_settings.dart';

class WordleGameController extends Notifier<WordleGameState>
    with WordleBoardController<WordleGameState> {
  final Random _random = Random();

  @override
  WordleGameState build() {
    ref.keepAlive();

    // Switching the app language switches the word lists, which means a fresh
    // game — rebuilding this provider is exactly that.
    final languageCode = ref.watch(appLocaleProvider).languageCode;
    final settings = ref.read(wordleSettingsProvider);

    _start(
      languageCode: languageCode,
      wordLength: settings.wordLength,
      difficulty: settings.difficulty,
    );

    return WordleGameState.loading(
      languageCode: languageCode,
      wordLength: settings.wordLength,
      difficulty: settings.difficulty,
    );
  }

  /// Starts a new round with the currently selected settings.
  @override
  void newGame() {
    final settings = ref.read(wordleSettingsProvider);
    _start(
      languageCode: state.board.languageCode,
      wordLength: settings.wordLength,
      difficulty: settings.difficulty,
    );
  }

  /// A different word length needs a different solution, so it restarts.
  void changeWordLength(int length) {
    if (length == ref.read(wordleSettingsProvider).wordLength) return;
    ref.read(wordleSettingsProvider.notifier).setWordLength(length);
    newGame();
  }

  /// The difficulty only decides where the *next* solution comes from, so the
  /// running game is left untouched.
  void changeDifficulty(WordleDifficulty difficulty) {
    ref.read(wordleSettingsProvider.notifier).setDifficulty(difficulty);
  }

  void setHardMode(bool enabled) {
    ref.read(wordleSettingsProvider.notifier).setHardMode(enabled);
  }

  @override
  WordleRejection? submit() {
    if (!state.isPlaying) return null;

    final rejection = state.board.validateInput(
      hardMode: ref.read(wordleSettingsProvider).hardMode,
    );
    if (rejection != null) return rejection;

    final board = state.board.submitInput();
    final won = board.rows.last.word == board.solution;

    state = state.copyWith(
      board: board,
      phase: won
          ? WordlePhase.won
          : board.rows.length >= state.maxAttempts
          ? WordlePhase.lost
          : WordlePhase.playing,
    );
    return null;
  }

  /// Fills the row being typed with a word that could still be the solution.
  ///
  /// Anything the board already ruled out is skipped, so a hint always moves
  /// the player closer; the solution itself is held back so a hint never wins
  /// the game outright. When nothing but the solution is left there is nothing
  /// closer to offer, and the caller gets to ask whether to solve instead.
  WordleHintOutcome hint() {
    final board = state.board;
    if (!state.isPlaying || !board.hasSolution) {
      return WordleHintOutcome.unavailable;
    }

    final candidates = <String>[
      for (final word in state.solutionPool)
        if (word != board.solution &&
            // Only offer words the player would actually be allowed to submit.
            board.acceptedWords.contains(word) &&
            isConsistentWith(word, board.rows))
          word,
    ];

    if (candidates.isEmpty) return WordleHintOutcome.onlySolutionLeft;

    _fillInput(candidates[_random.nextInt(candidates.length)]);
    return WordleHintOutcome.filled;
  }

  /// Writes the solution into the row after the player took up the offer to
  /// solve. It still counts as a hint, and is still theirs to submit.
  void fillSolution() {
    if (!state.isPlaying || !state.board.hasSolution) return;
    _fillInput(state.board.solution);
  }

  void _fillInput(String word) {
    state = state.copyWith(
      board: state.board.fillInput(word),
      hintsUsed: state.hintsUsed + 1,
    );
  }

  /// Ends the round and writes the solution into the next free row.
  void giveUp() {
    if (!state.canGiveUp) return;
    state = state.copyWith(
      board: state.board.revealSolution(),
      phase: WordlePhase.lost,
    );
  }

  Future<void> _start({
    required String languageCode,
    required int wordLength,
    required WordleDifficulty difficulty,
  }) {
    return loadRound(
      languageCode: languageCode,
      difficulty: difficulty,
      wordLength: wordLength,
      onLoaded: (words) {
        if (words.wordLength != wordLength) {
          ref
              .read(wordleSettingsProvider.notifier)
              .setWordLength(words.wordLength);
        }

        final pool = words.solutionPool;
        state = WordleGameState(
          board: WordleBoard.start(
            languageCode: languageCode,
            solution: pool[_random.nextInt(pool.length)],
            acceptedWords: words.acceptedWords,
            round: state.board.round + 1,
          ),
          difficulty: difficulty,
          phase: WordlePhase.playing,
          solutionPool: pool,
          hintsUsed: 0,
        );
      },
      onFailed: () => state = WordleGameState.loading(
        languageCode: languageCode,
        wordLength: wordLength,
        difficulty: difficulty,
        failed: true,
      ),
    );
  }
}

final wordleGameProvider =
    NotifierProvider<WordleGameController, WordleGameState>(
      WordleGameController.new,
    );
