import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/l10n/locale_notifier.dart';
import 'package:flutter_app/features/games/wordle_shared/data/wordle_word_repository.dart';
import 'package:flutter_app/features/games/wordle/domain/wordle_game_models.dart';
import 'package:flutter_app/features/games/wordle_shared/domain/wordle_models.dart';
import 'package:flutter_app/features/games/wordle_shared/domain/wordle_rules.dart';
import 'package:flutter_app/features/games/wordle/state/wordle_controller.dart';
import 'package:flutter_app/features/games/wordle/state/wordle_game_state.dart';
import 'package:flutter_app/features/games/wordle/state/wordle_settings.dart';

import 'wordle_fixture.dart';

/// Waits until the controller has a solution loaded from the bundled lists.
///
/// A restart keeps the previous board on screen while the new word list is
/// read, so [afterRound] is needed to tell the old game from the new one.
Future<WordleGameState> _ready(
  ProviderContainer container, {
  int afterRound = 0,
}) => waitForState(
  container,
  wordleGameProvider,
  (state) =>
      state.phase != WordlePhase.loading && state.board.round > afterRound,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer makeContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('starts a five letter English game from the guessable list', () async {
    final container = makeContainer();

    final state = await _ready(container);

    expect(state.phase, WordlePhase.playing);
    expect(state.board.wordLength, kWordleDefaultLength);
    expect(state.board.solution.length, kWordleDefaultLength);
    expect(state.board.input, List.filled(kWordleDefaultLength, ''));

    final pool = await container
        .read(wordleWordRepositoryProvider)
        .solutionPool('en', WordleDifficulty.normal, kWordleDefaultLength);
    expect(pool, contains(state.board.solution));
  });

  test('accepts any word from all.txt regardless of difficulty', () async {
    final container = makeContainer();
    final state = await _ready(container);
    final controller = container.read(wordleGameProvider.notifier);

    // Present in all.txt but not in the six letter guessable list.
    final pool = await container
        .read(wordleWordRepositoryProvider)
        .solutionPool('en', WordleDifficulty.normal, kWordleDefaultLength);
    final guess = state.board.acceptedWords.firstWhere(
      (word) => !pool.contains(word) && word != state.board.solution,
    );

    for (final letter in guess.split('')) {
      controller.typeLetter(letter);
    }
    expect(controller.submit(), isNull);
    expect(container.read(wordleGameProvider).board.rows.single.word, guess);
  });

  test('rejects words that are in no list', () async {
    final container = makeContainer();
    await _ready(container);
    final controller = container.read(wordleGameProvider.notifier);

    for (final letter in 'ZZZZZZ'.split('')) {
      controller.typeLetter(letter);
    }

    expect(controller.submit()?.kind, WordleRejectionKind.notInWordList);
    expect(container.read(wordleGameProvider).board.rows, isEmpty);
  });

  test('typing overwrites from the selected slot', () async {
    final container = makeContainer();
    await _ready(container);
    final controller = container.read(wordleGameProvider.notifier);

    for (final letter in 'CRANE'.split('')) {
      controller.typeLetter(letter);
    }
    expect(container.read(wordleGameProvider).board.typedWord, 'CRANE');

    controller.selectSlot(2);
    controller.typeLetter('O');
    expect(container.read(wordleGameProvider).board.typedWord, 'CRONE');
    expect(container.read(wordleGameProvider).board.cursor, 3);

    // Backspace clears whichever slot is currently selected (the one under
    // the caret), not the one before it.
    controller.backspace();
    expect(container.read(wordleGameProvider).board.input[3], '');
    expect(container.read(wordleGameProvider).board.input[2], 'O');
    expect(container.read(wordleGameProvider).board.cursor, 3);

    // With nothing occupying the caret slot, backspace falls back to
    // auto-selecting and clearing the last filled letter.
    controller.backspace();
    expect(container.read(wordleGameProvider).board.input[2], '');
    expect(container.read(wordleGameProvider).board.cursor, 2);
  });

  test('giving up fills in the solution and ends the round', () async {
    final container = makeContainer();
    final state = await _ready(container);
    final controller = container.read(wordleGameProvider.notifier);

    controller.giveUp();

    final after = container.read(wordleGameProvider);
    expect(after.phase, WordlePhase.lost);
    expect(after.board.rows.single.word, state.board.solution);
    expect(after.board.rows.single.isSolution, isTrue);
    expect(after.board.guessCount, 0);
  });

  test('changing the word length starts a new game', () async {
    final container = makeContainer();
    final first = await _ready(container);

    container.read(wordleGameProvider.notifier).changeWordLength(6);
    final second = await _ready(container, afterRound: first.board.round);

    expect(second.board.wordLength, 6);
    expect(second.board.solution.length, 6);
    expect(second.board.round, greaterThan(first.board.round));
    expect(container.read(wordleSettingsProvider).wordLength, 6);
  });

  test('a longer word grants extra attempts', () async {
    final container = makeContainer();
    final first = await _ready(container);
    expect(first.maxAttempts, kWordleMaxAttempts);

    container.read(wordleGameProvider.notifier).changeWordLength(8);
    final second = await _ready(container, afterRound: first.board.round);

    expect(second.board.wordLength, 8);
    expect(second.maxAttempts, kWordleMaxAttempts + 3);
  });

  test('hard mode is applied per guess, not per game', () async {
    final container = makeContainer();
    final state = await _ready(container);
    final controller = container.read(wordleGameProvider.notifier);
    final settings = container.read(wordleSettingsProvider.notifier);

    void type(String word) {
      for (final letter in word.split('')) {
        controller.typeLetter(letter);
      }
    }

    // One guess to put some hints on the board.
    final opener = state.board.acceptedWords.firstWhere(
      (word) => word != state.board.solution,
    );
    type(opener);
    expect(controller.submit(), isNull);

    final constraints = HardModeConstraints.fromRows(
      container.read(wordleGameProvider).board.rows,
    );
    final ignoresHints = state.board.acceptedWords.firstWhere(
      (word) => word != state.board.solution && constraints.validate(word) != null,
    );

    // Switched on mid-game, the very next guess has to obey.
    settings.setHardMode(true);
    type(ignoresHints);
    expect(controller.submit()?.kind, WordleRejectionKind.hardMode);
    expect(container.read(wordleGameProvider).board.rows, hasLength(1));

    // Switched off again, the same guess goes through.
    settings.setHardMode(false);
    expect(controller.submit(), isNull);
    expect(container.read(wordleGameProvider).board.rows, hasLength(2));
  });

  group('hints', () {
    test('fills a word that could still be the solution', () async {
      final container = makeContainer();
      final state = await _ready(container);
      final controller = container.read(wordleGameProvider.notifier);

      expect(controller.hint(), WordleHintOutcome.filled);

      final after = container.read(wordleGameProvider);
      expect(after.hintsUsed, 1);
      expect(after.board.typedWord.length, after.board.wordLength);
      expect(after.board.cursor, after.board.wordLength);
      // Never the answer itself, and always submittable.
      expect(after.board.typedWord, isNot(state.board.solution));
      expect(after.board.acceptedWords, contains(after.board.typedWord));
    });

    test('only suggests words that fit every hint so far', () async {
      final container = makeContainer();
      final state = await _ready(container);
      final controller = container.read(wordleGameProvider.notifier);

      // Play an opener so the board carries real constraints.
      final opener = state.solutionPool.firstWhere(
        (word) =>
            word != state.board.solution && state.board.acceptedWords.contains(word),
      );
      for (final letter in opener.split('')) {
        controller.typeLetter(letter);
      }
      expect(controller.submit(), isNull);

      final rows = container.read(wordleGameProvider).board.rows;
      for (var i = 0; i < 25; i++) {
        final outcome = controller.hint();
        if (outcome == WordleHintOutcome.onlySolutionLeft) break;

        final suggestion = container.read(wordleGameProvider).board.typedWord;
        expect(isConsistentWith(suggestion, rows), isTrue);
        expect(suggestion, isNot(state.board.solution));
      }
    });

    test('a hint is accepted even in hard mode', () async {
      final container = makeContainer();
      final state = await _ready(container);
      final controller = container.read(wordleGameProvider.notifier);
      container.read(wordleSettingsProvider.notifier).setHardMode(true);

      final opener = state.solutionPool.firstWhere(
        (word) =>
            word != state.board.solution && state.board.acceptedWords.contains(word),
      );
      for (final letter in opener.split('')) {
        controller.typeLetter(letter);
      }
      expect(controller.submit(), isNull);

      if (controller.hint() != WordleHintOutcome.filled) return;
      // A hinted word honours every revealed clue by construction, so hard
      // mode must let it through.
      expect(controller.submit(), isNull);
    });

    test('offers to solve once nothing but the solution is left', () async {
      // A pool of exactly two words: guessing the wrong one rules it out and
      // leaves the solution as the only word that still fits.
      final container = ProviderContainer(
        overrides: [
          wordleWordRepositoryProvider.overrideWithValue(
            FixedWordRepository(const ['CRANE', 'SLATE']),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = await _ready(container);
      final controller = container.read(wordleGameProvider.notifier);
      final other = state.solutionPool.firstWhere(
        (word) => word != state.board.solution,
      );

      expect(controller.hint(), WordleHintOutcome.filled);
      expect(container.read(wordleGameProvider).board.typedWord, other);
      expect(controller.submit(), isNull);

      // Nothing closer left to offer.
      expect(controller.hint(), WordleHintOutcome.onlySolutionLeft);
      // Asking alone neither fills the row nor spends a hint.
      expect(container.read(wordleGameProvider).board.typedWord, isEmpty);
      expect(container.read(wordleGameProvider).hintsUsed, 1);

      controller.fillSolution();
      expect(container.read(wordleGameProvider).board.typedWord, state.board.solution);
      expect(container.read(wordleGameProvider).hintsUsed, 2);
    });

    test('the counter resets with a new game', () async {
      final container = makeContainer();
      final first = await _ready(container);
      final controller = container.read(wordleGameProvider.notifier);

      controller.hint();
      expect(container.read(wordleGameProvider).hintsUsed, 1);

      controller.newGame();
      final second = await _ready(container, afterRound: first.board.round);
      expect(second.hintsUsed, 0);
    });

    test('does nothing once the round is over', () async {
      final container = makeContainer();
      await _ready(container);
      final controller = container.read(wordleGameProvider.notifier);

      controller.giveUp();

      expect(controller.hint(), WordleHintOutcome.unavailable);
      expect(container.read(wordleGameProvider).hintsUsed, 0);
    });
  });

  test('changing the difficulty keeps the running game', () async {
    final container = makeContainer();
    final before = await _ready(container);
    final controller = container.read(wordleGameProvider.notifier);

    controller.typeLetter('A');
    controller.changeDifficulty(WordleDifficulty.allWords);

    final after = container.read(wordleGameProvider);
    expect(after.board.round, before.board.round);
    expect(after.board.solution, before.board.solution);
    expect(after.board.typedWord, 'A');
    expect(container.read(wordleSettingsProvider).difficulty,
        WordleDifficulty.allWords);
  });

  test('switching the language starts a German game', () async {
    final container = makeContainer();
    await _ready(container);

    container.read(appLocaleProvider.notifier).setLocale(const Locale('de'));
    final german = await _ready(container);

    expect(german.board.languageCode, 'de');
    expect(german.board.solution.length, kWordleDefaultLength);

    final pool = await container
        .read(wordleWordRepositoryProvider)
        .solutionPool('de', WordleDifficulty.normal, kWordleDefaultLength);
    expect(pool, contains(german.board.solution));
  });

  group('word lists', () {
    late WordleWordRepository repository;

    setUp(() => repository = WordleWordRepository());

    test('only offers lengths with at least 20 words', () async {
      final lengths = await repository.availableLengths(
        'en',
        WordleDifficulty.normal,
      );

      expect(lengths, contains(kWordleDefaultLength));
      for (final length in lengths) {
        final pool = await repository.solutionPool(
          'en',
          WordleDifficulty.normal,
          length,
        );
        expect(pool.length, greaterThanOrEqualTo(kWordleMinWordsPerLength));
      }

      // The English guessable list runs out of long words.
      final counts = <int, int>{};
      for (var length = kWordleMinLength; length <= kWordleMaxLength; length++) {
        counts[length] = (await repository.solutionPool(
          'en',
          WordleDifficulty.normal,
          length,
        )).length;
      }
      for (final entry in counts.entries) {
        expect(
          lengths.contains(entry.key),
          entry.value >= kWordleMinWordsPerLength,
          reason: 'length ${entry.key} has ${entry.value} words',
        );
      }
    });

    test('normalises German entries', () async {
      final pool = await repository.solutionPool(
        'de',
        WordleDifficulty.normal,
        5,
      );

      expect(pool, isNotEmpty);
      expect(pool.every((word) => word.length == 5), isTrue);
      // Upper case throughout — but ß stays ß so it keeps taking one tile.
      expect(pool.any((word) => RegExp('[a-z]').hasMatch(word)), isFalse);
      expect(pool.any((word) => word.contains('Ä') || word.contains('Ü')),
          isTrue);
      expect(pool.toSet().length, pool.length);
    });
  });
}
