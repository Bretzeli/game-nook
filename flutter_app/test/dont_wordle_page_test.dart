import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/app.dart';
import 'package:flutter_app/core/dictionary/dictionary_repository.dart';
import 'package:flutter_app/core/dictionary/word_definition_dialog.dart';
import 'package:flutter_app/features/games/dont_wordle/state/dont_wordle_controller.dart';
import 'package:flutter_app/features/games/wordle_shared/data/wordle_word_repository.dart';
import 'package:flutter_app/features/games/wordle_shared/widgets/wordle_grid.dart';
import 'package:flutter_app/features/games/wordle_shared/widgets/wordle_keyboard.dart';
import 'package:flutter_app/features/games/wordle_shared/widgets/wordle_tile.dart';
import 'package:flutter_app/widgets/game_chip.dart';

import 'wordle_fixture.dart';

const _solutions = ['CRANE', 'SLATE'];

/// Fits the hints either solution gives the other one, without being a
/// solution itself.
const _companion = 'AWAKE';

/// Guesses sharing no letter with the words above: each one is survived.
const _misses = ['BBBBB', 'DDDDD', 'FFFFF', 'GGGGG', 'HHHHH', 'IIIII'];

FixedWordRepository _fixedRepository() => FixedWordRepository(
  _solutions,
  difficultWords: const ['TRACE'],
  extraGuesses: const [_companion, ..._misses, 'BBBBE'],
);

/// Opens the game from the home page and hands back the app's container.
Future<ProviderContainer> _openDontWordle(
  WidgetTester tester, {
  List<String> languages = const ['en'],
  WordleWordRepository? repository,
  DictionaryRepository? dictionary,
}) async {
  final resolved = repository ?? await warmWordRepository(tester, languages);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        wordleWordRepositoryProvider.overrideWithValue(resolved),
        dictionaryRepositoryProvider.overrideWithValue(
          dictionary ?? FakeDictionary(knows: false),
        ),
      ],
      child: const GameNookApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 700));

  await tester.tap(find.text("Don't Wordle"));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  expect(find.byType(WordleGrid), findsOneWidget);
  return ProviderScope.containerOf(
    tester.element(find.byType(WordleGrid)),
    listen: false,
  );
}

void _useSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Types [word] and presses enter, without waiting for anything.
Future<void> _submit(
  WidgetTester tester,
  ProviderContainer container,
  String word,
) async {
  typeWord(container.read(dontWordleGameProvider.notifier), word);
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pump();
}

/// Plays [word] and lets its row turn over completely.
Future<void> _guess(
  WidgetTester tester,
  ProviderContainer container,
  String word,
) async {
  await _submit(tester, container, word);
  await tester.pump(revealDurationFor(word.length));
  await settle(tester);
}

String _solution(ProviderContainer container) =>
    container.read(dontWordleGameProvider).board.solution;

Finder _chip(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(GameChip));

void main() {
  for (final (name, size) in const [
    ('phone', Size(390, 844)),
    ('short phone', Size(390, 700)),
    ('tablet', Size(834, 1112)),
    ('desktop', Size(1600, 900)),
  ]) {
    testWidgets('lays out without overflow on $name', (tester) async {
      _useSize(tester, size);

      await _openDontWordle(tester);

      expect(find.byType(WordleKeyboard), findsOneWidget);
      // Only the six rows to survive: the ones to find the word are earned.
      expect(find.byType(WordleTile), findsNWidgets(30));
      expect(find.textContaining('words left'), findsOneWidget);
      expect(find.textContaining('possible solutions'), findsOneWidget);
      // Hard mode is simply always on, and the rules need no signpost.
      expect(find.text('Hard mode'), findsNothing);
      expect(find.textContaining('Avoid the word'), findsNothing);
    });
  }

  testWidgets('tiles keep their size on a wide but short screen', (
    tester,
  ) async {
    // Wide enough for gaps sized by the width alone to crowd out the tiles.
    _useSize(tester, const Size(1600, 900));
    await _openDontWordle(tester);

    final tiles = find.byType(WordleTile);
    final size = tester.getSize(tiles.first).height;
    final pitch =
        tester.getTopLeft(tiles.at(5)).dy - tester.getTopLeft(tiles.at(0)).dy;

    expect(size, greaterThan(28));
    expect(pitch - size, lessThanOrEqualTo(size * 0.2));
  });

  testWidgets('the rows to find the word join once survival has turned over', (
    tester,
  ) async {
    _useSize(tester, const Size(834, 1112));
    final container = await _openDontWordle(
      tester,
      repository: _fixedRepository(),
    );
    final solution = _solution(container);

    for (final word in _misses.take(5)) {
      await _guess(tester, container, word);
    }
    expect(find.byType(WordleTile), findsNWidgets(30));

    await _submit(tester, container, _misses.last);
    await tester.pump(const Duration(milliseconds: 100));
    // Still turning over: nothing may give the survival away yet.
    expect(find.byType(WordleTile), findsNWidgets(30));
    expect(find.text('You survived! Now find the word'), findsNothing);

    await tester.pump(revealDurationFor(solution.length));
    await tester.pump(kRowsResizeDuration);
    await settle(tester);

    expect(find.byType(WordleTile), findsNWidgets(40));
    expect(find.text('You survived! Now find the word'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _guess(tester, container, solution);

    expect(find.text('Flawless!'), findsOneWidget);
    expect(find.text('Survived, then found it on try 1 of 2'), findsOneWidget);
  });

  testWidgets('both counters wait for the flip, and only no other word corners', (
    tester,
  ) async {
    _useSize(tester, const Size(834, 1112));
    final container = await _openDontWordle(
      tester,
      repository: _fixedRepository(),
    );
    final other = _solutions.firstWhere((w) => w != _solution(container));

    // Both solutions, the difficult one, the companion, six misses and BBBBE.
    expect(find.text('11 words left'), findsOneWidget);
    expect(find.text('2 possible solutions'), findsOneWidget);

    await _submit(tester, container, other);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('11 words left'), findsOneWidget);
    expect(find.text('2 possible solutions'), findsOneWidget);

    await tester.pump(revealDurationFor(5));
    await settle(tester);
    expect(find.text('2 words left'), findsOneWidget);
    expect(find.text('1 possible solution'), findsOneWidget);
    expect(find.text('Cornered!'), findsNothing);

    await _guess(tester, container, _companion);

    expect(find.text('1 word left'), findsOneWidget);
    expect(find.text('Cornered!'), findsOneWidget);
    expect(find.text(_solution(container)), findsOneWidget);
  });

  testWidgets('a hint fills in a word and counts up', (tester) async {
    _useSize(tester, const Size(834, 1112));
    final container = await _openDontWordle(
      tester,
      repository: _fixedRepository(),
    );
    final other = _solutions.firstWhere((w) => w != _solution(container));

    expect(
      find.descendant(of: _chip('Hint'), matching: find.text('0')),
      findsOneWidget,
    );

    await tester.tap(find.text('Hint'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(dontWordleGameProvider).board.typedWord, other);
    expect(
      find.descendant(of: _chip('Hint'), matching: find.text('1')),
      findsOneWidget,
    );

    // The word it filled in is a legal guess.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(revealDurationFor(5));
    await settle(tester);
    expect(container.read(dontWordleGameProvider).board.rows, hasLength(1));
  });

  testWidgets('the number of guesses shapes the board', (tester) async {
    _useSize(tester, const Size(834, 1112));
    await _openDontWordle(tester, repository: _fixedRepository());

    await tester.tap(find.text('6 guesses'));
    await settle(tester);
    expect(find.text('A different number starts a new game'), findsOneWidget);

    await tester.tap(find.text('4 guesses').last);
    await settle(tester);

    expect(find.byType(WordleTile), findsNWidgets(20));
    expect(find.text('4 guesses'), findsOneWidget);
  });

  testWidgets('difficult words join the solutions from the next game', (
    tester,
  ) async {
    _useSize(tester, const Size(834, 1112));
    await _openDontWordle(tester, repository: _fixedRepository());

    await tester.tap(find.text('Normal'));
    await settle(tester);
    expect(find.text('Applies from the next game on'), findsOneWidget);
    await tester.tap(find.text('Difficult').last);
    await settle(tester);

    expect(find.text('Difficult'), findsOneWidget);
    expect(find.text('2 possible solutions'), findsOneWidget);

    await tester.tap(find.text('New game'));
    await settle(tester);

    expect(find.text('3 possible solutions'), findsOneWidget);
  });

  testWidgets('turned-down guesses explain themselves', (tester) async {
    _useSize(tester, const Size(834, 1112));
    final container = await _openDontWordle(
      tester,
      repository: _fixedRepository(),
    );
    final controller = container.read(dontWordleGameProvider.notifier);

    // Both solutions end in E, which pins it to the last slot.
    await _guess(tester, container, 'BBBBE');

    await _submit(tester, container, 'DDDDD');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('5th letter must be E'), findsOneWidget);

    for (var i = 0; i < 5; i++) {
      controller.backspace();
    }
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);

    await _submit(tester, container, 'BBBBE');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Already guessed'), findsOneWidget);
    expect(container.read(dontWordleGameProvider).board.rows, hasLength(1));
  });

  testWidgets('hitting the word loses, and the word can be looked up', (
    tester,
  ) async {
    _useSize(tester, const Size(834, 1112));
    final container = await _openDontWordle(
      tester,
      repository: _fixedRepository(),
      dictionary: FakeDictionary(knows: true),
    );
    final solution = _solution(container);

    await _guess(tester, container, solution);

    expect(find.text('Oops, that was the word!'), findsOneWidget);
    expect(find.text(solution), findsOneWidget);
    // Lost while avoiding it, so the rows to find it never appear.
    expect(find.byType(WordleTile), findsNWidgets(30));

    await tester.tap(find.byIcon(Icons.question_mark_rounded));
    await settle(tester);

    expect(find.byType(WordDefinitionDialog), findsOneWidget);
    expect(find.text('a large long-necked wading bird'), findsOneWidget);
  });

  testWidgets('giving up reveals the word', (tester) async {
    _useSize(tester, const Size(834, 1112));
    final container = await _openDontWordle(
      tester,
      repository: _fixedRepository(),
    );
    final solution = _solution(container);

    await tester.tap(find.text('Give up'));
    await tester.pump();
    await tester.pump(revealDurationFor(solution.length));
    await settle(tester);

    expect(find.text('Bad luck!'), findsOneWidget);
    expect(find.text(solution), findsOneWidget);

    await tester.tap(find.text('New game').last);
    await settle(tester);

    expect(find.text('Bad luck!'), findsNothing);
    expect(find.text('11 words left'), findsOneWidget);
  });

  testWidgets('plays in German with its own keyboard', (tester) async {
    _useSize(tester, const Size(834, 1112));
    await _openDontWordle(tester, languages: const ['en', 'de']);

    await tester.tap(find.byTooltip('Language'));
    await settle(tester);
    await tester.tap(find.text('Deutsch').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);

    expect(find.textContaining('Wörter übrig'), findsOneWidget);
    expect(find.textContaining('mögliche Lösungen'), findsOneWidget);
    expect(find.text('6 Versuche'), findsOneWidget);
    expect(find.text('Tipp'), findsOneWidget);
    for (final letter in ['Ü', 'Ö', 'Ä', 'ß']) {
      expect(
        find.descendant(
          of: find.byType(WordleKeyboard),
          matching: find.text(letter),
        ),
        findsOneWidget,
        reason: 'missing $letter key',
      );
    }
  });
}
