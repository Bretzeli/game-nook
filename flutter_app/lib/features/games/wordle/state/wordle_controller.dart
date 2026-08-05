import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/locale_notifier.dart';
import '../data/wordle_word_repository.dart';
import '../domain/wordle_alphabet.dart';
import '../domain/wordle_models.dart';
import '../domain/wordle_rules.dart';
import 'wordle_game_state.dart';
import 'wordle_settings.dart';

final wordleWordRepositoryProvider = Provider<WordleWordRepository>((ref) {
  ref.keepAlive();
  return WordleWordRepository();
});

/// Word lengths the picker may offer for the current language and difficulty.
final wordleAvailableLengthsProvider = FutureProvider<List<int>>((ref) async {
  final languageCode = ref.watch(appLocaleProvider).languageCode;
  final difficulty = ref.watch(
    wordleSettingsProvider.select((settings) => settings.difficulty),
  );
  return ref
      .watch(wordleWordRepositoryProvider)
      .availableLengths(languageCode, difficulty);
});

class WordleGameController extends Notifier<WordleGameState> {
  final Random _random = Random();
  int _loadToken = 0;

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
  void newGame() {
    final settings = ref.read(wordleSettingsProvider);
    _start(
      languageCode: state.languageCode,
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

  void typeLetter(String character) {
    if (!state.isPlaying || state.cursor >= state.wordLength) return;
    final letter = WordleAlphabet.normalizeChar(character, state.languageCode);
    if (letter == null) return;

    final input = [...state.input];
    input[state.cursor] = letter;
    state = state.copyWith(input: input, cursor: state.cursor + 1);
  }

  void backspace() {
    if (!state.isPlaying) return;
    final target = state.cursor > 0 ? state.cursor - 1 : 0;
    final input = [...state.input];
    input[target] = '';
    state = state.copyWith(input: input, cursor: target);
  }

  /// Lets the player overwrite from a specific slot instead of the start.
  void selectSlot(int index) {
    if (!state.isPlaying || index < 0 || index >= state.wordLength) return;
    state = state.copyWith(cursor: index);
  }

  void moveCursor(int delta) {
    if (!state.isPlaying) return;
    final target = (state.cursor + delta).clamp(0, state.wordLength);
    if (target == state.cursor) return;
    state = state.copyWith(cursor: target);
  }

  /// Submits the typed row. Returns `null` when it was accepted, otherwise the
  /// reason it was turned down.
  WordleRejection? submit() {
    if (!state.isPlaying) return null;
    if (!state.isInputComplete) return const WordleRejection.tooShort();

    final guess = state.typedWord;
    if (!state.acceptedWords.contains(guess) && guess != state.solution) {
      return const WordleRejection.notInWordList();
    }

    if (ref.read(wordleSettingsProvider).hardMode) {
      final violation = HardModeConstraints.fromRows(state.rows).validate(guess);
      if (violation != null) return WordleRejection.hardMode(violation);
    }

    final rows = [
      ...state.rows,
      WordleRow(word: guess, statuses: evaluateGuess(guess, state.solution)),
    ];
    final won = guess == state.solution;

    state = state.copyWith(
      rows: rows,
      input: List<String>.filled(state.wordLength, ''),
      cursor: 0,
      phase: won
          ? WordlePhase.won
          : rows.length >= state.maxAttempts
          ? WordlePhase.lost
          : WordlePhase.playing,
    );
    return null;
  }

  /// Ends the round and writes the solution into the next free row.
  void giveUp() {
    if (!state.canGiveUp) return;

    final rows = [
      ...state.rows,
      WordleRow(
        word: state.solution,
        statuses: List<LetterStatus>.filled(
          state.wordLength,
          LetterStatus.correct,
        ),
        isSolution: true,
      ),
    ];

    state = state.copyWith(
      rows: rows,
      input: List<String>.filled(state.wordLength, ''),
      cursor: 0,
      phase: WordlePhase.lost,
    );
  }

  Future<void> _start({
    required String languageCode,
    required int wordLength,
    required WordleDifficulty difficulty,
  }) async {
    final token = ++_loadToken;
    // Captured while it is guaranteed to be valid: after an await this tells
    // us whether the provider was disposed or rebuilt in the meantime.
    final ref = this.ref;
    final repository = ref.read(wordleWordRepositoryProvider);

    try {
      final lengths = await repository.availableLengths(
        languageCode,
        difficulty,
      );
      final length = _resolveLength(lengths, wordLength);

      final pool = await repository.solutionPool(
        languageCode,
        difficulty,
        length,
      );
      final accepted = await repository.acceptedWords(languageCode, length);
      if (token != _loadToken || !ref.mounted) return;

      if (pool.isEmpty) {
        state = WordleGameState.loading(
          languageCode: languageCode,
          wordLength: wordLength,
          difficulty: difficulty,
        ).copyWith(phase: WordlePhase.failed);
        return;
      }

      if (length != wordLength) {
        ref.read(wordleSettingsProvider.notifier).setWordLength(length);
      }

      state = WordleGameState(
        languageCode: languageCode,
        wordLength: length,
        difficulty: difficulty,
        phase: WordlePhase.playing,
        solution: pool[_random.nextInt(pool.length)],
        rows: const [],
        input: List<String>.filled(length, ''),
        cursor: 0,
        acceptedWords: accepted,
        round: state.round + 1,
      );
    } catch (_) {
      if (token != _loadToken || !ref.mounted) return;
      state = WordleGameState.loading(
        languageCode: languageCode,
        wordLength: wordLength,
        difficulty: difficulty,
      ).copyWith(phase: WordlePhase.failed);
    }
  }

  /// Falls back to the closest usable length when the selected one does not
  /// have enough words in the current list (which can happen after switching
  /// language or difficulty).
  int _resolveLength(List<int> available, int requested) {
    if (available.isEmpty || available.contains(requested)) return requested;
    return available.reduce(
      (a, b) => (a - requested).abs() <= (b - requested).abs() ? a : b,
    );
  }
}

final wordleGameProvider =
    NotifierProvider<WordleGameController, WordleGameState>(
      WordleGameController.new,
    );
