import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/l10n/locale_notifier.dart';
import 'package:flutter_app/features/games/dont_wordle/domain/dont_wordle_models.dart';
import 'package:flutter_app/features/games/dont_wordle/state/dont_wordle_controller.dart';
import 'package:flutter_app/features/games/dont_wordle/state/dont_wordle_game_state.dart';
import 'package:flutter_app/features/games/dont_wordle/state/dont_wordle_settings.dart';
import 'package:flutter_app/features/games/wordle/state/wordle_settings.dart';
import 'package:flutter_app/features/games/wordle_shared/data/wordle_word_repository.dart';
import 'package:flutter_app/features/games/wordle_shared/domain/wordle_models.dart';
import 'package:flutter_app/features/games/wordle_shared/domain/wordle_rules.dart';

import 'wordle_fixture.dart';

/// The two words a solution can be. Guessing one of them leaves only the
/// other as a possible solution.
const _solutions = ['CRANE', 'SLATE'];

/// A solution only once difficult words are allowed.
const _difficult = 'TRACE';

/// Fits the hints either solution gives the other one (??A?E), without being
/// a solution itself — so it keeps a round going after the other solution
/// has been guessed.
const _companion = 'AWAKE';

/// Accepted guesses sharing no letter with any word above, so playing one
/// never rules any of them out — and, each using a letter of its own, never
/// breaks hard mode either.
const _misses = [
  'BBBBB',
  'DDDDD',
  'FFFFF',
  'GGGGG',
  'HHHHH',
  'IIIII',
  'JJJJJ',
  'MMMMM',
];

FixedWordRepository _fixedRepository() => FixedWordRepository(
  _solutions,
  difficultWords: const [_difficult],
  extraGuesses: const [_companion, ..._misses, 'BBBBE', 'DDDDE'],
);

ProviderContainer _container({WordleWordRepository? repository}) {
  final container = ProviderContainer(
    overrides: [
      if (repository != null)
        wordleWordRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<DontWordleGameState> _ready(
  ProviderContainer container, {
  int afterRound = 0,
}) => waitForState(
  container,
  dontWordleGameProvider,
  (state) =>
      state.status != DontWordleStatus.loading &&
      state.board.round > afterRound,
);

/// Types [word] as the next guess and submits it.
WordleRejection? _play(ProviderContainer container, String word) {
  final controller = container.read(dontWordleGameProvider.notifier);
  typeWord(controller, word);
  return controller.submit();
}

DontWordleGameState _state(ProviderContainer container) =>
    container.read(dontWordleGameProvider);

String _other(DontWordleGameState state) =>
    _solutions.firstWhere((word) => word != state.board.solution);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('draws from the normal list and counts the words of every list', () async {
    final container = _container();
    // Wordle's own choice of list must not leak into this game.
    container
        .read(wordleSettingsProvider.notifier)
        .setDifficulty(WordleDifficulty.allWords);

    final state = await _ready(container);
    final repository = container.read(wordleWordRepositoryProvider);
    final pool = await repository.solutionPool(
      'en',
      WordleDifficulty.normal,
      kWordleDefaultLength,
    );
    final accepted = await repository.acceptedWords('en', kWordleDefaultLength);

    expect(pool, contains(state.board.solution));
    expect(state.progress.wordsLeft, (
      words: accepted.length,
      solutions: pool.length,
    ));
    expect(state.avoidAttempts, kDontWordleDefaultGuesses);
    expect(state.rowCountAfter(0), kDontWordleDefaultGuesses);
  });

  test('each guess narrows both counts to the words that still fit', () async {
    final container = _container();
    final state = await _ready(container);

    final guess = state.possibleSolutions.firstWhere(
      (word) => word != state.board.solution,
    );
    expect(_play(container, guess), isNull);

    final after = _state(container);
    final rows = after.board.rows;
    expect(after.possibleWords, contains(after.board.solution));
    expect(after.possibleWords, isNot(contains(guess)));
    expect(
      after.possibleWords.every((word) => isConsistentWith(word, rows)),
      isTrue,
    );
    expect(
      after.board.acceptedWords
          .where((word) => isConsistentWith(word, rows))
          .length,
      after.possibleWords.length,
    );
    expect(
      after.possibleSolutions.every(after.possibleWords.contains),
      isTrue,
    );
    expect(after.wordsLeft.last, (
      words: after.possibleWords.length,
      solutions: after.possibleSolutions.length,
    ));
  });

  test('the number of guesses is the player\'s, not the word length\'s', () async {
    final container = _container();
    final first = await _ready(container);
    final controller = container.read(dontWordleGameProvider.notifier);

    controller.changeWordLength(8);
    final longer = await _ready(container, afterRound: first.board.round);
    expect(longer.board.wordLength, 8);
    expect(longer.avoidAttempts, kDontWordleDefaultGuesses);

    controller.changeGuesses(9);
    final more = await _ready(container, afterRound: longer.board.round);
    expect(more.avoidAttempts, 9);
    expect(more.rowCountAfter(0), 9);
    expect(container.read(dontWordleSettingsProvider).guesses, 9);
    // Wordle keeps its own settings.
    expect(container.read(wordleSettingsProvider).wordLength, 5);
  });

  test('difficult words can be the solution from the next game on', () async {
    final container = _container(repository: _fixedRepository());
    final first = await _ready(container);
    expect(first.progress.wordsLeft.solutions, _solutions.length);

    container.read(dontWordleGameProvider.notifier).setDifficultWords(true);
    // The running round keeps the solutions it was dealt.
    expect(_state(container).board.round, first.board.round);
    expect(_state(container).possibleSolutions, isNot(contains(_difficult)));

    container.read(dontWordleGameProvider.notifier).newGame();
    final second = await _ready(container, afterRound: first.board.round);
    expect(second.possibleSolutions, contains(_difficult));
    expect(second.progress.wordsLeft.solutions, _solutions.length + 1);
  });

  test('hard mode is always on', () async {
    final container = _container(repository: _fixedRepository());
    await _ready(container);

    // Both solutions end in E, so this pins E to the last slot.
    expect(_play(container, 'BBBBE'), isNull);

    final rejection = _play(container, 'DDDDD');
    expect(rejection?.kind, WordleRejectionKind.hardMode);
    expect(rejection?.violation?.kind, HardModeViolationKind.fixedPosition);
    expect(_state(container).board.rows, hasLength(1));

    final controller = container.read(dontWordleGameProvider.notifier);
    controller.backspace();
    controller.typeLetter('E');
    expect(controller.submit(), isNull);
    expect(_state(container).board.rows, hasLength(2));
  });

  test('a word can only be guessed once', () async {
    final container = _container(repository: _fixedRepository());
    await _ready(container);

    expect(_play(container, 'BBBBB'), isNull);
    expect(_play(container, 'BBBBB')?.kind, WordleRejectionKind.alreadyGuessed);
    expect(_state(container).board.rows, hasLength(1));
  });

  test('guessing the solution loses the round', () async {
    final container = _container(repository: _fixedRepository());
    final state = await _ready(container);
    final controller = container.read(dontWordleGameProvider.notifier);

    expect(_play(container, state.board.solution), isNull);

    final after = _state(container);
    expect(after.progress.outcome, DontWordleOutcome.hitSolution);
    expect(after.acceptsInput, isFalse);
    expect(after.canGiveUp, isFalse);
    expect(after.canHint, isFalse);
    // The board is closed for good.
    expect(controller.typeLetter('B'), isFalse);
    expect(controller.submit(), isNull);
    expect(_state(container).board.rows, hasLength(1));
  });

  test('only a guess that leaves no other word of any list corners', () async {
    final container = _container(repository: _fixedRepository());
    final state = await _ready(container);

    expect(_play(container, _other(state)), isNull);

    // No other solution fits any more, but the companion still does.
    final squeezed = _state(container);
    expect(squeezed.progress.wordsLeft, (words: 2, solutions: 1));
    expect(squeezed.progress.isFinished, isFalse);

    expect(_play(container, _companion), isNull);

    final cornered = _state(container);
    expect(cornered.progress.wordsLeft, (words: 1, solutions: 1));
    expect(cornered.progress.outcome, DontWordleOutcome.cornered);
    expect(cornered.rowCountAfter(cornered.board.rows.length), 6);
  });

  test('surviving earns two more rows to find the word', () async {
    final container = _container(repository: _fixedRepository());
    final state = await _ready(container);

    for (final word in _misses.take(kDontWordleDefaultGuesses)) {
      expect(_play(container, word), isNull, reason: word);
    }

    final survived = _state(container);
    expect(survived.progress.phase, DontWordlePhase.finding);
    expect(survived.progress.attempts, kDontWordleFindAttempts);
    // The rows join only with the last guess to survive.
    expect(survived.rowCountAfter(5), kDontWordleDefaultGuesses);
    expect(
      survived.rowCountAfter(6),
      kDontWordleDefaultGuesses + kDontWordleFindAttempts,
    );

    expect(_play(container, state.board.solution), isNull);

    final solved = _state(container);
    expect(solved.progress.outcome, DontWordleOutcome.solved);
    expect(solved.progress.attempt, 1);
    expect(solved.acceptsInput, isFalse);
  });

  test('missing both tries still counts as survived', () async {
    final container = _container(repository: _fixedRepository());
    await _ready(container);

    for (final word in _misses) {
      expect(_play(container, word), isNull, reason: word);
    }

    final after = _state(container);
    expect(after.progress.outcome, DontWordleOutcome.survived);
    expect(after.rowCountAfter(after.board.rows.length), 8);
  });

  group('hints', () {
    test('fill in another possible solution while there is one', () async {
      final container = _container(repository: _fixedRepository());
      final state = await _ready(container);
      final controller = container.read(dontWordleGameProvider.notifier);

      expect(controller.hint(), isTrue);

      final after = _state(container);
      expect(after.board.typedWord, _other(state));
      expect(after.hintsUsed, 1);
      // Always a legal guess, even in hard mode.
      expect(controller.submit(), isNull);
    });

    test('fall back to any word that fits, but never the solution', () async {
      final container = _container(repository: _fixedRepository());
      final state = await _ready(container);
      final controller = container.read(dontWordleGameProvider.notifier);
      _play(container, _other(state));

      expect(controller.hint(), isTrue);
      expect(_state(container).board.typedWord, _companion);
      expect(controller.submit(), isNull);
    });

    test('are counted per round', () async {
      final container = _container(repository: _fixedRepository());
      final first = await _ready(container);
      final controller = container.read(dontWordleGameProvider.notifier);

      controller.hint();
      controller.hint();
      expect(_state(container).hintsUsed, 2);

      controller.newGame();
      final second = await _ready(container, afterRound: first.board.round);
      expect(second.hintsUsed, 0);
    });
  });

  test('giving up reveals the solution and ends the round', () async {
    final container = _container(repository: _fixedRepository());
    final state = await _ready(container);

    _play(container, 'BBBBB');
    container.read(dontWordleGameProvider.notifier).giveUp();

    final after = _state(container);
    expect(after.progress.outcome, DontWordleOutcome.gaveUp);
    expect(after.board.rows.last.word, state.board.solution);
    expect(after.board.rows.last.isSolution, isTrue);
    expect(after.board.guessCount, 1);
  });

  test('a new game starts over with every word in play', () async {
    final container = _container(repository: _fixedRepository());
    final first = await _ready(container);
    _play(container, first.board.solution);

    container.read(dontWordleGameProvider.notifier).newGame();
    final second = await _ready(container, afterRound: first.board.round);

    expect(second.board.rows, isEmpty);
    expect(second.wordsLeft, [first.wordsLeft.first]);
    expect(second.acceptsInput, isTrue);
  });

  test('switching the language starts a German game', () async {
    final container = _container();
    await _ready(container);

    container.read(appLocaleProvider.notifier).setLocale(const Locale('de'));
    final german = await _ready(container);

    expect(german.board.languageCode, 'de');
    final pool = await container
        .read(wordleWordRepositoryProvider)
        .solutionPool('de', WordleDifficulty.normal, kWordleDefaultLength);
    expect(pool, contains(german.board.solution));
    expect(german.progress.wordsLeft.solutions, pool.length);
  });
}
