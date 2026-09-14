import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/app.dart';
import 'package:flutter_app/core/dictionary/dictionary_repository.dart';
import 'package:flutter_app/core/dictionary/word_definition_dialog.dart';
import 'package:flutter_app/features/games/wordle_shared/data/wordle_word_repository.dart';
import 'package:flutter_app/features/games/wordle/state/wordle_controller.dart';
import 'package:flutter_app/widgets/game_chip.dart';
import 'package:flutter_app/features/games/wordle_shared/widgets/wordle_grid.dart';
import 'package:flutter_app/features/games/wordle_shared/widgets/wordle_keyboard.dart';
import 'package:flutter_app/features/games/wordle_shared/widgets/wordle_tile.dart';

import 'wordle_fixture.dart';

Future<void> _openWordle(
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

  await tester.tap(find.text('Wordle'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  expect(find.byType(WordleGrid), findsOneWidget);
}

Future<void> _tapKey(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(WordleKeyboard),
      matching: find.text(label),
    ),
  );
  await tester.pump(const Duration(milliseconds: 150));
}

Finder _onBoard(String letter) => find.descendant(
  of: find.byType(WordleGrid),
  matching: find.text(letter),
);

Finder _hintChip() =>
    find.ancestor(of: find.text('Hint'), matching: find.byType(GameChip));

void main() {
  for (final (name, size) in const [
    ('phone', Size(390, 844)),
    ('tablet', Size(834, 1112)),
    ('desktop', Size(1600, 900)),
  ]) {
    testWidgets('lays out without overflow on $name', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _openWordle(tester);

      expect(find.byType(WordleKeyboard), findsOneWidget);
      // Six rows of tiles for the default five letter word.
      expect(find.byType(WordleTile), findsNWidgets(30));
    });
  }

  testWidgets('the on-screen keyboard types into the board', (tester) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openWordle(tester);

    await _tapKey(tester, 'C');
    await _tapKey(tester, 'R');
    expect(_onBoard('C'), findsOneWidget);
    expect(_onBoard('R'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(WordleKeyboard),
        matching: find.byIcon(Icons.backspace_outlined),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));

    expect(_onBoard('R'), findsNothing);
    expect(_onBoard('C'), findsOneWidget);
  });

  testWidgets('a physical keyboard types and submits', (tester) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openWordle(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.pump(const Duration(milliseconds: 150));
    expect(_onBoard('S'), findsOneWidget);

    // Enter on an unfinished row is turned down with a message.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Not enough letters'), findsOneWidget);
    expect(_onBoard('S'), findsOneWidget);

    // The message clears itself again.
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    expect(find.text('Not enough letters'), findsNothing);
  });

  testWidgets('a win is announced only after the row has flipped', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openWordle(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(WordleGrid)),
      listen: false,
    );
    final solution = container.read(wordleGameProvider).board.solution;
    for (final letter in solution.split('')) {
      container.read(wordleGameProvider.notifier).typeLetter(letter);
    }
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Still turning over: the result must not give itself away yet.
    expect(find.text('Genius!'), findsNothing);

    await tester.pump(revealDurationFor(solution.length));
    await settle(tester);

    expect(find.text('Genius!'), findsOneWidget);
    expect(find.text('In 1 of 6 tries'), findsOneWidget);
  });

  testWidgets('a win does not overflow the board on a short phone', (
    tester,
  ) async {
    // Tight enough vertically that the grid's tile size is height-bound,
    // which is what exposes a stray pixel on the winning row's animation.
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openWordle(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(WordleGrid)),
      listen: false,
    );
    final solution = container.read(wordleGameProvider).board.solution;
    for (final letter in solution.split('')) {
      container.read(wordleGameProvider.notifier).typeLetter(letter);
    }
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    // Push well past the flip *and* the win row's bow/shimmer animation,
    // where the shimmer effect's own padding used to overflow the Column.
    await tester.pump(revealDurationFor(solution.length));
    await tester.pump(const Duration(milliseconds: 1500));
    await settle(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the winning row settles back into its own place', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openWordle(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(WordleGrid)),
      listen: false,
    );
    final controller = container.read(wordleGameProvider.notifier);
    final game = container.read(wordleGameProvider);
    final columns = game.board.wordLength;

    Future<void> play(String word) async {
      for (final letter in word.split('')) {
        controller.typeLetter(letter);
      }
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(revealDurationFor(columns));
      await settle(tester);
    }

    // A wrong opener first, so the winning row has a scored row directly
    // above it — the one it would overlap if it never came back down.
    await play(
      game.solutionPool.firstWhere(
        (word) =>
            word != game.board.solution && game.board.acceptedWords.contains(word),
      ),
    );
    await play(game.board.solution);
    // Let the bow and its shimmer run all the way out.
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);

    // Painted position, not layout: the lift is a paint-time transform.
    double rowTop(int row) =>
        tester.getTopLeft(find.byType(WordleTile).at(row * columns)).dy;

    // Two untouched rows give the true row pitch to compare against.
    final pitch = rowTop(3) - rowTop(2);
    expect(pitch, greaterThan(0));
    expect(
      rowTop(1) - rowTop(0),
      closeTo(pitch, 0.5),
      reason: 'the winning row must come to rest one full row below its '
          'neighbour, not overlapping it',
    );
  });

  testWidgets('giving up writes the solution onto the board', (tester) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openWordle(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(WordleGrid)),
      listen: false,
    );
    final solution = container.read(wordleGameProvider).board.solution;

    await tester.tap(find.text('Give up'));
    await tester.pump();
    await tester.pump(revealDurationFor(solution.length));
    await settle(tester);

    expect(find.text('Bad luck!'), findsOneWidget);
    expect(find.text(solution), findsOneWidget);
    expect(container.read(wordleGameProvider).board.rows.single.isSolution, isTrue);
  });

  testWidgets('the revealed solution can be looked up in the dictionary', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openWordle(tester, dictionary: FakeDictionary(knows: true));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(WordleGrid)),
      listen: false,
    );
    final solution = container.read(wordleGameProvider).board.solution;

    await tester.tap(find.text('Give up'));
    await tester.pump();
    await tester.pump(revealDurationFor(solution.length));
    await settle(tester);

    expect(find.byIcon(Icons.question_mark_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.question_mark_rounded));
    await settle(tester);

    expect(find.byType(WordDefinitionDialog), findsOneWidget);
    expect(find.text('Dictionary'), findsOneWidget);
    expect(find.text('a large long-necked wading bird'), findsOneWidget);
    expect(find.textContaining('a crane took off'), findsOneWidget);
    expect(find.text('heron'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await settle(tester);

    expect(find.byType(WordDefinitionDialog), findsNothing);
    // The banner is still there to ask again from.
    expect(find.byIcon(Icons.question_mark_rounded), findsOneWidget);
  });

  testWidgets('a win offers the explanation too', (tester) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openWordle(tester, dictionary: FakeDictionary(knows: true));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(WordleGrid)),
      listen: false,
    );
    final solution = container.read(wordleGameProvider).board.solution;
    for (final letter in solution.split('')) {
      container.read(wordleGameProvider.notifier).typeLetter(letter);
    }
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    // Nothing before the row has turned over — the banner carries the button.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byIcon(Icons.question_mark_rounded), findsNothing);

    await tester.pump(revealDurationFor(solution.length));
    await settle(tester);

    expect(find.text('Genius!'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.question_mark_rounded));
    await settle(tester);

    expect(find.byType(WordDefinitionDialog), findsOneWidget);
  });

  testWidgets('a word the dictionary has nothing on offers no explanation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openWordle(tester, dictionary: FakeDictionary(knows: false));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(WordleGrid)),
      listen: false,
    );
    final solution = container.read(wordleGameProvider).board.solution;

    await tester.tap(find.text('Give up'));
    await tester.pump();
    await tester.pump(revealDurationFor(solution.length));
    await settle(tester);

    expect(find.text('Bad luck!'), findsOneWidget);
    expect(find.byIcon(Icons.question_mark_rounded), findsNothing);
  });

  testWidgets('leaving and returning keeps the scored rows', (tester) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openWordle(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(WordleGrid)),
      listen: false,
    );
    final controller = container.read(wordleGameProvider.notifier);
    for (final letter in 'CRANE'.split('')) {
      controller.typeLetter(letter);
    }
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(revealDurationFor(5));
    await settle(tester);

    await tester.tap(find.byTooltip('Back to home'));
    await settle(tester);
    await tester.tap(find.text('Wordle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The guess is still there, and still wearing its colours.
    expect(_onBoard('C'), findsOneWidget);
    final tile = tester.widget<WordleTile>(
      find
          .descendant(of: find.byType(WordleGrid), matching: find.byType(WordleTile))
          .first,
    );
    expect(tile.status, isNotNull);
  });

  testWidgets('the hint button fills a row and counts up', (tester) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openWordle(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(WordleGrid)),
      listen: false,
    );
    expect(container.read(wordleGameProvider).board.typedWord, isEmpty);

    // The counter starts at zero and lives inside the hint button itself.
    expect(
      find.descendant(of: _hintChip(), matching: find.text('0')),
      findsOneWidget,
    );

    await tester.tap(find.text('Hint'));
    await tester.pump(const Duration(milliseconds: 300));

    final game = container.read(wordleGameProvider);
    expect(game.board.typedWord.length, game.board.wordLength);
    expect(game.board.typedWord, isNot(game.board.solution));
    expect(game.hintsUsed, 1);
    expect(
      find.descendant(of: _hintChip(), matching: find.text('1')),
      findsOneWidget,
    );

    // The filled word is a legal guess.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(revealDurationFor(game.board.wordLength));
    await settle(tester);
    expect(container.read(wordleGameProvider).board.rows, hasLength(1));
  });

  testWidgets('the hint offers to solve when only the solution is left', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openWordle(tester, repository: FixedWordRepository(const ['CRANE', 'SLATE']));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(WordleGrid)),
      listen: false,
    );
    final solution = container.read(wordleGameProvider).board.solution;

    // Burn the only alternative, so the solution is all that is left.
    await tester.tap(find.text('Hint'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(revealDurationFor(solution.length));
    await settle(tester);

    await tester.tap(find.text('Hint'));
    await settle(tester);

    expect(find.text('Only the solution is left'), findsOneWidget);

    // Declining leaves the row alone.
    await tester.tap(find.text('Keep trying'));
    await settle(tester);
    expect(container.read(wordleGameProvider).board.typedWord, isEmpty);

    await tester.tap(find.text('Hint'));
    await settle(tester);
    await tester.tap(find.text('Fill it in'));
    await settle(tester);

    expect(container.read(wordleGameProvider).board.typedWord, solution);
    expect(container.read(wordleGameProvider).hintsUsed, 2);
  });

  testWidgets('the German keyboard offers umlaut keys', (tester) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openWordle(tester, languages: const ['en', 'de']);

    await tester.tap(find.byTooltip('Language'));
    await settle(tester);
    await tester.tap(find.text('Deutsch').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    for (final letter in ['Ü', 'Ö', 'Ä', 'ß', 'Z', 'Y']) {
      expect(
        find.descendant(
          of: find.byType(WordleKeyboard),
          matching: find.text(letter),
        ),
        findsOneWidget,
        reason: 'missing $letter key',
      );
    }
    expect(find.text('Neues Spiel'), findsOneWidget);
  });
}
