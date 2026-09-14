import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/locale_notifier.dart';
import '../../wordle_shared/domain/wordle_board.dart';
import '../../wordle_shared/domain/wordle_models.dart';
import '../../wordle_shared/domain/wordle_rules.dart';
import '../../wordle_shared/state/wordle_board_controller.dart';
import '../domain/dont_wordle_rules.dart';
import 'dont_wordle_game_state.dart';
import 'dont_wordle_settings.dart';

/// Wordle turned inside out: the player has to keep missing the word while
/// using every hint they get, and only after surviving may they try to find
/// it.
class DontWordleController extends Notifier<DontWordleGameState>
    with WordleBoardController<DontWordleGameState> {
  final Random _random = Random();

  @override
  DontWordleGameState build() {
    ref.keepAlive();

    // Switching the app language switches the word lists, which means a fresh
    // game — rebuilding this provider is exactly that.
    final languageCode = ref.watch(appLocaleProvider).languageCode;
    final settings = ref.read(dontWordleSettingsProvider);

    _start(languageCode: languageCode, settings: settings);

    return DontWordleGameState.loading(
      languageCode: languageCode,
      wordLength: settings.wordLength,
      avoidAttempts: settings.guesses,
    );
  }

  /// Starts a new round with the current settings.
  @override
  void newGame() {
    _start(
      languageCode: state.board.languageCode,
      settings: ref.read(dontWordleSettingsProvider),
    );
  }

  /// A different word length needs a different solution, so it restarts.
  void changeWordLength(int length) {
    if (length == ref.read(dontWordleSettingsProvider).wordLength) return;
    ref.read(dontWordleSettingsProvider.notifier).setWordLength(length);
    newGame();
  }

  /// A different number of guesses reshapes the board, so it restarts.
  void changeGuesses(int guesses) {
    if (guesses == ref.read(dontWordleSettingsProvider).guesses) return;
    ref.read(dontWordleSettingsProvider.notifier).setGuesses(guesses);
    newGame();
  }

  /// Which words may be the solution only matters when the next one is
  /// drawn, so the running round is left untouched.
  void setDifficultWords(bool enabled) {
    ref.read(dontWordleSettingsProvider.notifier).setDifficultWords(enabled);
  }

  /// Hard mode always applies. A word can also only be tried once: repeating
  /// one would buy a survived guess without anything new on the board.
  @override
  WordleRejection? submit() {
    if (!state.acceptsInput) return null;

    final rejection = state.board.validateInput(
      hardMode: true,
      rejectRepeats: true,
    );
    if (rejection != null) return rejection;

    final board = state.board.submitInput();
    final row = board.rows.last;
    final possibleWords = wordsConsistentWithRow(state.possibleWords, row);
    final possibleSolutions = wordsConsistentWithRow(
      state.possibleSolutions,
      row,
    );

    state = state.copyWith(
      board: board,
      possibleWords: possibleWords,
      possibleSolutions: possibleSolutions,
      wordsLeft: [
        ...state.wordsLeft,
        (words: possibleWords.length, solutions: possibleSolutions.length),
      ],
    );
    return null;
  }

  /// Fills the row being typed with a word that fits every hint but is not
  /// the solution. Returns whether there was one to fill in.
  bool hint() {
    if (!state.canHint) return false;

    final word = dontWordleHintWord(
      possibleSolutions: state.possibleSolutions,
      possibleWords: state.possibleWords,
      solution: state.board.solution,
      random: _random,
    );
    if (word == null) return false;

    state = state.copyWith(
      board: state.board.fillInput(word),
      hintsUsed: state.hintsUsed + 1,
    );
    return true;
  }

  /// Ends the round and writes the solution into the next free row.
  void giveUp() {
    if (!state.canGiveUp) return;
    state = state.copyWith(board: state.board.revealSolution());
  }

  Future<void> _start({
    required String languageCode,
    required DontWordleSettings settings,
  }) {
    return loadRound(
      languageCode: languageCode,
      difficulty: settings.solutionList,
      wordLength: settings.wordLength,
      onLoaded: (words) {
        if (words.wordLength != settings.wordLength) {
          ref
              .read(dontWordleSettingsProvider.notifier)
              .setWordLength(words.wordLength);
        }

        final pool = words.solutionPool;
        state = DontWordleGameState.start(
          board: WordleBoard.start(
            languageCode: languageCode,
            solution: pool[_random.nextInt(pool.length)],
            acceptedWords: words.acceptedWords,
            round: state.board.round + 1,
          ),
          avoidAttempts: settings.guesses,
          solutionPool: pool,
        );
      },
      onFailed: () => state = DontWordleGameState.loading(
        languageCode: languageCode,
        wordLength: settings.wordLength,
        avoidAttempts: settings.guesses,
        failed: true,
      ),
    );
  }
}

final dontWordleGameProvider =
    NotifierProvider<DontWordleController, DontWordleGameState>(
      DontWordleController.new,
    );
