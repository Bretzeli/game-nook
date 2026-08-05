import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/l10n/locale_notifier.dart';
import 'package:flutter_app/features/games/wordle/data/wordle_word_repository.dart';
import 'package:flutter_app/features/games/wordle/domain/wordle_models.dart';
import 'package:flutter_app/features/games/wordle/domain/wordle_rules.dart';
import 'package:flutter_app/features/games/wordle/state/wordle_controller.dart';
import 'package:flutter_app/features/games/wordle/state/wordle_game_state.dart';
import 'package:flutter_app/features/games/wordle/state/wordle_settings.dart';

/// Waits until the controller has a solution loaded from the bundled lists.
///
/// A restart keeps the previous board on screen while the new word list is
/// read, so [afterRound] is needed to tell the old game from the new one.
Future<WordleGameState> _ready(
  ProviderContainer container, {
  int afterRound = 0,
}) async {
  bool isReady(WordleGameState state) =>
      state.phase != WordlePhase.loading && state.round > afterRound;

  final completer = Completer<WordleGameState>();
  final subscription = container.listen<WordleGameState>(wordleGameProvider, (
    _,
    next,
  ) {
    if (isReady(next) && !completer.isCompleted) completer.complete(next);
  }, fireImmediately: true);
  addTearDown(subscription.close);

  final state = container.read(wordleGameProvider);
  if (isReady(state)) return state;
  return completer.future.timeout(const Duration(seconds: 60));
}

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
    expect(state.wordLength, kWordleDefaultLength);
    expect(state.solution.length, kWordleDefaultLength);
    expect(state.input, List.filled(kWordleDefaultLength, ''));

    final pool = await container
        .read(wordleWordRepositoryProvider)
        .solutionPool('en', WordleDifficulty.normal, kWordleDefaultLength);
    expect(pool, contains(state.solution));
  });

  test('accepts any word from all.txt regardless of difficulty', () async {
    final container = makeContainer();
    final state = await _ready(container);
    final controller = container.read(wordleGameProvider.notifier);

    // Present in all.txt but not in the six letter guessable list.
    final pool = await container
        .read(wordleWordRepositoryProvider)
        .solutionPool('en', WordleDifficulty.normal, kWordleDefaultLength);
    final guess = state.acceptedWords.firstWhere(
      (word) => !pool.contains(word) && word != state.solution,
    );

    for (final letter in guess.split('')) {
      controller.typeLetter(letter);
    }
    expect(controller.submit(), isNull);
    expect(container.read(wordleGameProvider).rows.single.word, guess);
  });

  test('rejects words that are in no list', () async {
    final container = makeContainer();
    await _ready(container);
    final controller = container.read(wordleGameProvider.notifier);

    for (final letter in 'ZZZZZZ'.split('')) {
      controller.typeLetter(letter);
    }

    expect(controller.submit()?.kind, WordleRejectionKind.notInWordList);
    expect(container.read(wordleGameProvider).rows, isEmpty);
  });

  test('typing overwrites from the selected slot', () async {
    final container = makeContainer();
    await _ready(container);
    final controller = container.read(wordleGameProvider.notifier);

    for (final letter in 'CRANE'.split('')) {
      controller.typeLetter(letter);
    }
    expect(container.read(wordleGameProvider).typedWord, 'CRANE');

    controller.selectSlot(2);
    controller.typeLetter('O');
    expect(container.read(wordleGameProvider).typedWord, 'CRONE');
    expect(container.read(wordleGameProvider).cursor, 3);

    // Backspace clears the slot left of the caret, like a text field.
    controller.backspace();
    expect(container.read(wordleGameProvider).input[2], '');
    expect(container.read(wordleGameProvider).cursor, 2);
  });

  test('giving up fills in the solution and ends the round', () async {
    final container = makeContainer();
    final state = await _ready(container);
    final controller = container.read(wordleGameProvider.notifier);

    controller.giveUp();

    final after = container.read(wordleGameProvider);
    expect(after.phase, WordlePhase.lost);
    expect(after.rows.single.word, state.solution);
    expect(after.rows.single.isSolution, isTrue);
    expect(after.attemptsUsed, 0);
  });

  test('changing the word length starts a new game', () async {
    final container = makeContainer();
    final first = await _ready(container);

    container.read(wordleGameProvider.notifier).changeWordLength(6);
    final second = await _ready(container, afterRound: first.round);

    expect(second.wordLength, 6);
    expect(second.solution.length, 6);
    expect(second.round, greaterThan(first.round));
    expect(container.read(wordleSettingsProvider).wordLength, 6);
  });

  test('a longer word grants extra attempts', () async {
    final container = makeContainer();
    final first = await _ready(container);
    expect(first.maxAttempts, kWordleMaxAttempts);

    container.read(wordleGameProvider.notifier).changeWordLength(8);
    final second = await _ready(container, afterRound: first.round);

    expect(second.wordLength, 8);
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
    final opener = state.acceptedWords.firstWhere(
      (word) => word != state.solution,
    );
    type(opener);
    expect(controller.submit(), isNull);

    final constraints = HardModeConstraints.fromRows(
      container.read(wordleGameProvider).rows,
    );
    final ignoresHints = state.acceptedWords.firstWhere(
      (word) => word != state.solution && constraints.validate(word) != null,
    );

    // Switched on mid-game, the very next guess has to obey.
    settings.setHardMode(true);
    type(ignoresHints);
    expect(controller.submit()?.kind, WordleRejectionKind.hardMode);
    expect(container.read(wordleGameProvider).rows, hasLength(1));

    // Switched off again, the same guess goes through.
    settings.setHardMode(false);
    expect(controller.submit(), isNull);
    expect(container.read(wordleGameProvider).rows, hasLength(2));
  });

  test('changing the difficulty keeps the running game', () async {
    final container = makeContainer();
    final before = await _ready(container);
    final controller = container.read(wordleGameProvider.notifier);

    controller.typeLetter('A');
    controller.changeDifficulty(WordleDifficulty.allWords);

    final after = container.read(wordleGameProvider);
    expect(after.round, before.round);
    expect(after.solution, before.solution);
    expect(after.typedWord, 'A');
    expect(container.read(wordleSettingsProvider).difficulty,
        WordleDifficulty.allWords);
  });

  test('switching the language starts a German game', () async {
    final container = makeContainer();
    await _ready(container);

    container.read(appLocaleProvider.notifier).setLocale(const Locale('de'));
    final german = await _ready(container);

    expect(german.languageCode, 'de');
    expect(german.solution.length, kWordleDefaultLength);

    final pool = await container
        .read(wordleWordRepositoryProvider)
        .solutionPool('de', WordleDifficulty.normal, kWordleDefaultLength);
    expect(pool, contains(german.solution));
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
