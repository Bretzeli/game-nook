import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/app.dart';
import 'package:flutter_app/features/games/wordle/data/wordle_word_repository.dart';
import 'package:flutter_app/features/games/wordle/domain/wordle_models.dart';
import 'package:flutter_app/features/games/wordle/state/wordle_controller.dart';
import 'package:flutter_app/features/games/wordle/widgets/wordle_grid.dart';
import 'package:flutter_app/features/games/wordle/widgets/wordle_keyboard.dart';
import 'package:flutter_app/features/games/wordle/widgets/wordle_tile.dart';

/// Reading the word lists is real async work that the fake clock inside
/// `testWidgets` cannot drive, so it is done up front and handed to the app as
/// a warm repository. Everything the page then asks for resolves as a
/// microtask, exactly like a second visit to the game does.
Future<WordleWordRepository> _warmRepository(
  WidgetTester tester,
  List<String> languages,
) async {
  final repository = WordleWordRepository();
  await tester.runAsync(() async {
    for (final language in languages) {
      await repository.availableLengths(language, WordleDifficulty.normal);
      await repository.solutionPool(
        language,
        WordleDifficulty.normal,
        kWordleDefaultLength,
      );
      await repository.acceptedWords(language, kWordleDefaultLength);
    }
  });
  return repository;
}

Future<void> _openWordle(
  WidgetTester tester, {
  List<String> languages = const ['en'],
}) async {
  final repository = await _warmRepository(tester, languages);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [wordleWordRepositoryProvider.overrideWithValue(repository)],
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

/// flutter_animate defers a freshly mounted animation by a zero timer, so one
/// settle pass can end with that timer still queued.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pumpAndSettle();
}

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
    await _settle(tester);
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
    final solution = container.read(wordleGameProvider).solution;
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
    await _settle(tester);

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
    final solution = container.read(wordleGameProvider).solution;
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
    await _settle(tester);

    expect(tester.takeException(), isNull);
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
    final solution = container.read(wordleGameProvider).solution;

    await tester.tap(find.text('Give up'));
    await tester.pump();
    await tester.pump(revealDurationFor(solution.length));
    await _settle(tester);

    expect(find.text('Bad luck!'), findsOneWidget);
    expect(find.text(solution), findsOneWidget);
    expect(container.read(wordleGameProvider).rows.single.isSolution, isTrue);
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
    await _settle(tester);

    await tester.tap(find.byTooltip('Back to home'));
    await _settle(tester);
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

  testWidgets('the German keyboard offers umlaut keys', (tester) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openWordle(tester, languages: const ['en', 'de']);

    await tester.tap(find.byTooltip('Language'));
    await _settle(tester);
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
