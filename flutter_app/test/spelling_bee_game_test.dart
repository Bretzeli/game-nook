import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/l10n/locale_notifier.dart';
import 'package:flutter_app/features/games/spelling_bee/data/spelling_bee_word_repository.dart';
import 'package:flutter_app/features/games/spelling_bee/domain/spelling_bee_models.dart';
import 'package:flutter_app/features/games/spelling_bee/state/spelling_bee_controller.dart';
import 'package:flutter_app/features/games/spelling_bee/state/spelling_bee_game_state.dart';

import 'spelling_bee_fixture.dart';

/// Waits until a puzzle has been dealt.
///
/// A restart keeps the old board on screen while the lists are read, so
/// [afterRound] is what tells the new puzzle from the old one.
Future<SpellingBeeGameState> _ready(
  ProviderContainer container, {
  int afterRound = 0,
}) async {
  bool isReady(SpellingBeeGameState state) =>
      state.phase != BeePhase.loading && state.round > afterRound;

  final completer = Completer<SpellingBeeGameState>();
  final subscription = container.listen<SpellingBeeGameState>(
    spellingBeeGameProvider,
    (_, next) {
      if (isReady(next) && !completer.isCompleted) completer.complete(next);
    },
    fireImmediately: true,
  );
  addTearDown(subscription.close);

  final state = container.read(spellingBeeGameProvider);
  if (isReady(state)) return state;
  return completer.future.timeout(const Duration(seconds: 30));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer makeContainer({SpellingBeeWordRepository? repository}) {
    final container = ProviderContainer(
      overrides: [
        spellingBeeWordRepositoryProvider.overrideWithValue(
          repository ?? FixtureBeeRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  SpellingBeeController controllerOf(ProviderContainer container) =>
      container.read(spellingBeeGameProvider.notifier);

  void type(ProviderContainer container, String word) {
    final controller = controllerOf(container);
    for (final letter in word.split('')) {
      controller.typeLetter(letter);
    }
  }

  /// Types [word] and submits it, returning why it was turned down.
  BeeRejection? play(ProviderContainer container, String word) {
    type(container, word);
    return controllerOf(container).submit();
  }

  test('a puzzle is dealt with seven letters and words to find', () async {
    final container = makeContainer();
    final game = await _ready(container);

    expect(game.phase, BeePhase.playing);
    expect(game.puzzle.letters, hasLength(kBeeLetterCount));
    expect(game.outerLetters, hasLength(kBeeOuterLetterCount));
    expect(game.puzzle.wordsOf(BeeTier.normal), isNotEmpty);
    expect(game.totalScore, 0);
  });

  test('a listed word scores into the bar of its own tier', () async {
    final container = makeContainer();
    final game = await _ready(container);
    final word = game.puzzle.wordsOf(BeeTier.normal).first;

    expect(play(container, word), isNull);

    final next = container.read(spellingBeeGameProvider);
    expect(next.found.single.word, word);
    expect(next.scoreOf(BeeTier.normal), beeWordPoints(word, game.puzzle.letters));
    expect(next.scoreOf(BeeTier.difficult), 0);
    expect(next.input, isEmpty);
    expect(next.progressOf(BeeTier.normal), greaterThan(0));
  });

  test('a word on neither list pays the rare bonus', () async {
    final container = makeContainer();
    final game = await _ready(container);
    final word = game.puzzle.bonusWords.first;

    expect(play(container, word), isNull);

    final next = container.read(spellingBeeGameProvider);
    expect(next.found.single.tier, BeeTier.bonus);
    expect(
      next.scoreOf(BeeTier.bonus),
      beeWordPoints(word, game.puzzle.letters) + kBeeRareBonus,
    );
    // Bonus words are extra credit: they never move a listed bar.
    expect(next.progressOf(BeeTier.normal), 0);
  });

  test('a pangram pays the whole hive on top', () async {
    final container = makeContainer();
    await _ready(container);

    expect(play(container, 'PRODUCE'), isNull);

    final found = container.read(spellingBeeGameProvider).found.single;
    expect(found.isPangram, isTrue);
    expect(found.points, 7 + kBeePangramBonus);
  });

  test('every way of getting a word wrong has its own reason', () async {
    final container = makeContainer();
    final game = await _ready(container);
    final center = game.puzzle.centerLetter;
    final outer = game.outerLetters;
    final controller = controllerOf(container);

    expect(play(container, center * 3)?.kind, BeeRejectionKind.tooShort);
    controller.clearInput();

    // Four letters of the hive that leave the middle one out.
    expect(
      play(container, outer.take(4).join())?.kind,
      BeeRejectionKind.missingCenter,
    );
    controller.clearInput();

    expect(
      play(container, '$center${'Z' * 3}')?.kind,
      BeeRejectionKind.badLetters,
    );
    controller.clearInput();

    expect(play(container, center * 4)?.kind, BeeRejectionKind.notAWord);
    controller.clearInput();

    final word = game.puzzle.wordsOf(BeeTier.normal).first;
    expect(play(container, word), isNull);
    expect(play(container, word)?.kind, BeeRejectionKind.alreadyFound);
  });

  test('a rejected word stays on the line to be fixed', () async {
    final container = makeContainer();
    await _ready(container);

    expect(play(container, 'ZZZZ'), isNotNull);
    expect(container.read(spellingBeeGameProvider).input, 'ZZZZ');

    controllerOf(container).backspace();
    expect(container.read(spellingBeeGameProvider).input, 'ZZZ');
  });

  test('shuffling moves the letters without changing the puzzle', () async {
    final container = makeContainer();
    final game = await _ready(container);
    final before = [...game.outerLetters];

    controllerOf(container).shuffle();

    final next = container.read(spellingBeeGameProvider);
    expect(next.outerLetters, isNot(orderedEquals(before)));
    expect(next.outerLetters.toSet(), before.toSet());
    expect(next.puzzle.centerLetter, game.puzzle.centerLetter);
    expect(next.round, game.round);
  });

  test('giving up ends the round and opens the list', () async {
    final container = makeContainer();
    await _ready(container);

    controllerOf(container).revealAll();

    final next = container.read(spellingBeeGameProvider);
    expect(next.phase, BeePhase.finished);
    expect(next.revealed, isTrue);
    expect(next.isPlaying, isFalse);
    // The round is over, so nothing else is taken.
    expect(play(container, 'PRODUCE'), isNull);
    expect(container.read(spellingBeeGameProvider).found, isEmpty);
  });

  test('finding every listed word ends the round by itself', () async {
    final container = makeContainer();
    final game = await _ready(container);

    for (final word in game.puzzle.listedWords.keys) {
      expect(play(container, word), isNull, reason: word);
    }

    final next = container.read(spellingBeeGameProvider);
    expect(next.isComplete, isTrue);
    expect(next.phase, BeePhase.finished);
    expect(next.revealed, isFalse);
    for (final tier in kBeeListedTiers) {
      expect(next.progressOf(tier), 1);
    }
  });

  test('a new game deals a new round and clears the score', () async {
    final container = makeContainer();
    final game = await _ready(container);
    expect(play(container, game.puzzle.wordsOf(BeeTier.normal).first), isNull);

    controllerOf(container).newGame();
    final next = await _ready(container, afterRound: game.round);

    expect(next.round, greaterThan(game.round));
    expect(next.found, isEmpty);
    expect(next.totalScore, 0);
    expect(next.phase, BeePhase.playing);
  });

  test('switching the language deals a puzzle from the new lists', () async {
    final container = makeContainer(
      repository: FixtureBeeRepository(
        byLanguage: {
          'de': buildFixtureIndex(
            languageCode: 'de',
            normal: ['SPRACHE', 'HASE', 'RACHE', 'SPRACH'],
            difficult: ['ASCHE'],
            bonus: ['HEER'],
          ),
        },
      ),
    );
    final game = await _ready(container);
    expect(game.puzzle.letters, {'P', 'R', 'O', 'D', 'U', 'C', 'E'});

    container.read(appLocaleProvider.notifier).setLocale(const Locale('de'));
    final next = await _ready(container, afterRound: game.round);

    expect(next.languageCode, 'de');
    expect(next.puzzle.letters, {'S', 'P', 'R', 'A', 'C', 'H', 'E'});
  });

  test('a word can only be as long as the hive can spell', () async {
    final container = makeContainer();
    await _ready(container);

    type(container, 'C' * (kBeeMaxInputLength + 6));
    expect(
      container.read(spellingBeeGameProvider).input.length,
      kBeeMaxInputLength,
    );
  });
}
