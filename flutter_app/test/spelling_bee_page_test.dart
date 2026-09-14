import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/app.dart';
import 'package:flutter_app/features/games/spelling_bee/data/spelling_bee_word_repository.dart';
import 'package:flutter_app/features/games/spelling_bee/domain/spelling_bee_models.dart';
import 'package:flutter_app/features/games/spelling_bee/state/spelling_bee_controller.dart';
import 'package:flutter_app/features/games/spelling_bee/state/spelling_bee_game_state.dart';
import 'package:flutter_app/features/games/spelling_bee/widgets/spelling_bee_actions.dart';
import 'package:flutter_app/features/games/spelling_bee/widgets/spelling_bee_found_words.dart';
import 'package:flutter_app/features/games/spelling_bee/widgets/spelling_bee_hive.dart';
import 'package:flutter_app/features/games/spelling_bee/widgets/spelling_bee_message.dart';
import 'package:flutter_app/features/games/spelling_bee/widgets/spelling_bee_progress.dart';
import 'package:flutter_app/widgets/game_chip.dart';

import 'spelling_bee_fixture.dart';

/// The board keeps a caret blinking for as long as a round is running, so
/// `pumpAndSettle` would never come back: these tests step time on instead.
///
/// The trailing tick is for flutter_animate, which defers every freshly
/// mounted animation by a zero timer that would otherwise still be queued
/// when the test ends.
Future<void> _advance(WidgetTester tester, [int milliseconds = 400]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: milliseconds));
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> _openBee(
  WidgetTester tester, {
  SpellingBeeWordRepository? repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        spellingBeeWordRepositoryProvider.overrideWithValue(
          repository ?? FixtureBeeRepository(),
        ),
      ],
      child: const GameNookApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 700));

  await tester.tap(find.text('Spelling Bee'));
  await _advance(tester, 600);

  expect(find.byType(SpellingBeeHive), findsOneWidget);
}

SpellingBeeGameState _game(WidgetTester tester) {
  final element = tester.element(find.byType(SpellingBeeHive));
  return ProviderScope.containerOf(element).read(spellingBeeGameProvider);
}

Future<void> _tapLetter(WidgetTester tester, String letter) async {
  await tester.tap(
    find.descendant(
      of: find.byType(SpellingBeeHive),
      matching: find.text(letter),
    ),
  );
  await tester.pump(const Duration(milliseconds: 120));
}

Future<void> _spell(WidgetTester tester, String word) async {
  for (final letter in word.split('')) {
    await _tapLetter(tester, letter);
  }
}

Future<void> _submit(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await _advance(tester, 500);
}

/// Lets the toast time out, so no timer is left pending at the end of a test.
Future<void> _clearToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(milliseconds: 400));
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

      await _openBee(tester);

      expect(find.byType(SpellingBeeProgress), findsOneWidget);
      expect(find.byType(SpellingBeeActions), findsOneWidget);
      expect(find.byType(SpellingBeeFoundWords), findsOneWidget);
      // Seven tiles, one letter each.
      final game = _game(tester);
      for (final letter in game.puzzle.letters) {
        expect(
          find.descendant(
            of: find.byType(SpellingBeeHive),
            matching: find.text(letter),
          ),
          findsOneWidget,
          reason: 'missing tile $letter',
        );
      }
    });
  }

  testWidgets('tapping the hive spells a word that then scores', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openBee(tester);
    final word = _game(tester).puzzle.wordsOf(BeeTier.normal).first;

    await _spell(tester, word);
    expect(_game(tester).input, word);

    await _submit(tester);

    final game = _game(tester);
    expect(game.found.single.word, word);
    expect(game.input, isEmpty);
    // The word joins the list, and the toast says what it paid.
    expect(
      find.descendant(
        of: find.byType(SpellingBeeFoundWords),
        matching: find.text(word),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(SpellingBeeToast),
        matching: find.text('+${game.found.single.points}'),
      ),
      findsOneWidget,
    );
    await _clearToast(tester);
  });

  testWidgets('the delete button takes the last letter back', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openBee(tester);
    final center = _game(tester).puzzle.centerLetter;

    await _tapLetter(tester, center);
    await _tapLetter(tester, center);
    expect(_game(tester).input, center * 2);

    await tester.tap(find.text('Delete'));
    await _advance(tester, 200);
    expect(_game(tester).input, center);
  });

  testWidgets('a letter tapped again before the board redraws still counts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openBee(tester);
    final center = _game(tester).puzzle.centerLetter;
    final tile = find.descendant(
      of: find.byType(SpellingBeeHive),
      matching: find.text(center),
    );

    // The second finger goes down before the frame that answers the first
    // tap has been drawn, which is what tapping quickly actually looks like.
    await tester.tap(tile);
    final second = await tester.startGesture(tester.getCenter(tile));
    await tester.pump(const Duration(milliseconds: 16));
    await second.up();
    await _advance(tester, 120);

    expect(_game(tester).input, center * 2);
  });

  testWidgets('a word that spells nothing is turned down with a reason', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openBee(tester);
    final center = _game(tester).puzzle.centerLetter;

    await _spell(tester, center * 4);
    await _submit(tester);

    expect(find.text('Not in the word list'), findsOneWidget);
    // The letters stay long enough to be read shaking, then leave the line so
    // the next word can be typed straight away.
    expect(_game(tester).input, center * 4);
    await tester.pump(const Duration(milliseconds: 400));
    expect(_game(tester).input, isEmpty);

    await _clearToast(tester);
    expect(find.text('Not in the word list'), findsNothing);
  });

  testWidgets('a word cleared off the line does not take new letters with it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openBee(tester);
    final game = _game(tester);
    final center = game.puzzle.centerLetter;

    await _spell(tester, center * 4);
    await _submit(tester);
    // Typing again before the rejected word times out keeps what was typed.
    await _tapLetter(tester, game.outerLetters.first);
    await tester.pump(const Duration(milliseconds: 600));

    expect(_game(tester).input, '${center * 4}${game.outerLetters.first}');
    await _clearToast(tester);
  });

  testWidgets('a word without the middle letter names it', (tester) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openBee(tester);
    final game = _game(tester);

    await _spell(tester, game.outerLetters.take(4).join());
    await _submit(tester);

    expect(
      find.text('Missing the middle letter ${game.puzzle.centerLetter}'),
      findsOneWidget,
    );
    // Every word that is turned down leaves the line once it has shaken,
    // whatever was wrong with it.
    await tester.pump(const Duration(milliseconds: 400));
    expect(_game(tester).input, isEmpty);

    await _clearToast(tester);
  });

  testWidgets('a word that is too short leaves the line as well', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openBee(tester);
    final center = _game(tester).puzzle.centerLetter;

    await _spell(tester, center * (kBeeMinWordLength - 1));
    await _submit(tester);

    expect(find.text('At least $kBeeMinWordLength letters'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(_game(tester).input, isEmpty);

    await _clearToast(tester);
  });

  testWidgets('the shake leaves the line with the word that earned it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openBee(tester);
    final center = _game(tester).puzzle.centerLetter;
    final word = _game(tester).puzzle.wordsOf(BeeTier.normal).first;
    const shake = ValueKey('reject-1');

    await _spell(tester, center * 4);
    await _submit(tester);
    expect(find.byKey(shake), findsOneWidget);

    // Once the word is gone the bare caret is left standing still, rather
    // than shaking a second time in its place.
    await tester.pump(const Duration(milliseconds: 400));
    await _advance(tester, 400);
    expect(_game(tester).input, isEmpty);
    expect(find.byKey(shake), findsNothing);
    await _clearToast(tester);

    // And a word that counts is not shaken for the one that did not.
    await _spell(tester, word);
    expect(find.byKey(shake), findsNothing);
    await _submit(tester);
    expect(find.byKey(shake), findsNothing);
    expect(_game(tester).found.single.word, word);
    await _clearToast(tester);
  });

  testWidgets('shuffling rearranges the outer letters only', (tester) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openBee(tester);
    final before = _game(tester);

    await tester.tap(find.byIcon(Icons.autorenew_rounded));
    await _advance(tester, 700);

    final after = _game(tester);
    expect(after.outerLetters, isNot(orderedEquals(before.outerLetters)));
    expect(after.puzzle.centerLetter, before.puzzle.centerLetter);
  });

  testWidgets('giving up shows the words that were there to find', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openBee(tester);
    final missed = _game(tester).puzzle.wordsOf(BeeTier.difficult).first;
    expect(find.text(missed), findsNothing);

    await tester.tap(find.text('All words'));
    await _advance(tester, 600);

    expect(_game(tester).revealed, isTrue);
    expect(find.byType(SpellingBeeResultBanner), findsOneWidget);
    expect(find.text('Round over'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SpellingBeeFoundWords),
        matching: find.text(missed),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a new game deals a fresh round', (tester) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openBee(tester);
    final word = _game(tester).puzzle.wordsOf(BeeTier.normal).first;
    await _spell(tester, word);
    await _submit(tester);
    expect(_game(tester).totalScore, greaterThan(0));
    await _clearToast(tester);

    await tester.tap(
      find.ancestor(of: find.text('New game'), matching: find.byType(GameChip)),
    );
    await _advance(tester, 700);

    expect(_game(tester).totalScore, 0);
    expect(
      find.descendant(
        of: find.byType(SpellingBeeFoundWords),
        matching: find.text(word),
      ),
      findsNothing,
    );
  });

  testWidgets('the board speaks German when the app does', (tester) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openBee(
      tester,
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

    await tester.tap(find.byTooltip('Language'));
    await _advance(tester, 400);
    await tester.tap(find.text('Deutsch').last);
    await _advance(tester, 700);

    expect(find.text('Neues Spiel'), findsOneWidget);
    expect(find.text('Alle Wörter'), findsOneWidget);
    expect(find.text('Punkte'.toUpperCase()), findsOneWidget);
    expect(_game(tester).puzzle.letters, {
      'S',
      'P',
      'R',
      'A',
      'C',
      'H',
      'E',
    });
  });
}
