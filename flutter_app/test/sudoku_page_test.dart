import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/app.dart';
import 'package:flutter_app/features/games/sudoku/domain/sudoku_models.dart';
import 'package:flutter_app/features/games/sudoku/state/sudoku_controller.dart';
import 'package:flutter_app/features/games/sudoku/state/sudoku_game_state.dart';
import 'package:flutter_app/features/games/sudoku/state/sudoku_settings.dart';
import 'package:flutter_app/features/games/sudoku/widgets/sudoku_board_view.dart';
import 'package:flutter_app/features/games/sudoku/widgets/sudoku_cell_view.dart';
import 'package:flutter_app/features/games/sudoku/widgets/sudoku_keypad.dart';
import 'package:flutter_app/features/games/sudoku/widgets/sudoku_message.dart';

import 'sudoku_fixture.dart';

/// The result banner and the toasts animate, and a toast is on a timer, so the
/// tests step time on rather than waiting for everything to come to rest.
Future<void> _advance(WidgetTester tester, [int milliseconds = 400]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: milliseconds));
  await tester.pump(const Duration(milliseconds: 1));
}

/// Lets a toast time out, so no timer is left pending at the end of a test.
Future<void> _clearToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _openSudoku(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sudokuPuzzleFactoryProvider.overrideWithValue(FixtureSudokuFactory()),
      ],
      child: const GameNookApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 700));

  await tester.tap(find.text('Sudoku'));
  await _advance(tester, 600);

  expect(find.byType(SudokuBoardView), findsOneWidget);
}

SudokuGameState _game(WidgetTester tester) {
  final element = tester.element(find.byType(SudokuBoardView));
  return ProviderScope.containerOf(element).read(sudokuGameProvider);
}

SudokuSettings _settings(WidgetTester tester) {
  final element = tester.element(find.byType(SudokuBoardView));
  return ProviderScope.containerOf(element).read(sudokuSettingsProvider);
}

int _firstEmpty(WidgetTester tester) =>
    _game(tester).cells.indexWhere((cell) => cell.isEmpty);

Future<void> _tapCell(WidgetTester tester, int index) async {
  await tester.tap(find.byType(SudokuCellView).at(index));
  await tester.pump(const Duration(milliseconds: 60));
}

Future<void> _tapKey(WidgetTester tester, int value) async {
  await tester.tap(
    find.descendant(
      of: find.byType(SudokuKeypad),
      matching: find.byKey(ValueKey('sudoku-key-$value')),
    ),
  );
  await tester.pump(const Duration(milliseconds: 60));
}

/// Taps a chip by the label it carries.
Future<void> _tapChip(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await _advance(tester, 300);
}

/// Switches the board over to [label], e.g. "12x12" written with a times sign.
Future<void> _chooseSize(WidgetTester tester, String label) async {
  final current = _settings(tester).size;
  await _tapChip(tester, '${current.length}×${current.length}');
  await tester.tap(find.text(label).last);
  await _advance(tester, 900);
}

Offset _keyAt(WidgetTester tester, int value) =>
    tester.getTopLeft(find.byKey(ValueKey('sudoku-key-$value')));

double _cellSize(WidgetTester tester) =>
    tester.getSize(find.byType(SudokuCellView).first).width;

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

      await _openSudoku(tester);

      final game = _game(tester);
      expect(find.byType(SudokuCellView), findsNWidgets(game.cells.length));
      expect(find.byType(SudokuKeypad), findsOneWidget);
      expect(find.byType(SudokuStatusLine), findsOneWidget);
      // One key per value, and the eraser.
      expect(find.byKey(const ValueKey('sudoku-key-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('sudoku-erase')), findsOneWidget);
    });
  }

  testWidgets('the largest board still lays out on a phone', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openSudoku(tester);
    await _tapChip(tester, '9×9');
    await tester.tap(find.text('25×25').last);
    await _advance(tester, 900);

    expect(_game(tester).size, SudokuSize.twentyFive);
    expect(find.byType(SudokuCellView), findsNWidgets(625));
    // Values past nine are two-digit numbers, not letters.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('sudoku-key-25')),
        matching: find.text('25'),
      ),
      findsOneWidget,
    );
    expect(find.text('A'), findsNothing);
    expect(find.text('Q'), findsNothing);
  });

  testWidgets('tapping a cell and a key fills it in', (tester) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openSudoku(tester);
    final index = _firstEmpty(tester);

    await _tapCell(tester, index);
    expect(_game(tester).selected, index);

    final answer = _game(tester).puzzle.solution[index];
    await _tapKey(tester, answer);

    expect(_game(tester).cells[index].value, answer);
    expect(
      find.descendant(
        of: find.byType(SudokuCellView).at(index),
        matching: find.text(sudokuSymbol(answer)),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the eraser empties the selected cell', (tester) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openSudoku(tester);
    final index = _firstEmpty(tester);

    await _tapCell(tester, index);
    await _tapKey(tester, 1);
    expect(_game(tester).cells[index].value, 1);

    await tester.tap(find.byKey(const ValueKey('sudoku-erase')));
    await tester.pump(const Duration(milliseconds: 60));
    expect(_game(tester).cells[index].isEmpty, isTrue);
  });

  testWidgets('the keyboard types, moves and erases', (tester) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openSudoku(tester);
    final index = _firstEmpty(tester);
    await _tapCell(tester, index);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.pump(const Duration(milliseconds: 60));
    expect(_game(tester).cells[index].value, 4);

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump(const Duration(milliseconds: 60));
    expect(_game(tester).cells[index].isEmpty, isTrue);

    // Arrows walk the board.
    final geometry = _game(tester).geometry;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      _game(tester).selected,
      geometry.indexOf(geometry.rowOf(index), geometry.columnOf(index) + 1),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 60));
    expect(_game(tester).selected, isNull);
  });

  testWidgets('notes go in from the keypad and from shift', (tester) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openSudoku(tester);
    final index = _firstEmpty(tester);
    await _tapCell(tester, index);

    // Shift writes one pencil mark without leaving the normal mode.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit7);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump(const Duration(milliseconds: 60));

    expect(_game(tester).cells[index].notes, {7});
    expect(_game(tester).cells[index].isEmpty, isTrue);
    expect(_settings(tester).notesMode, isFalse);

    // The chip switches the keypad over to pencil marks.
    await _tapChip(tester, 'Notes');
    expect(_settings(tester).notesMode, isTrue);

    await _tapKey(tester, 2);
    expect(_game(tester).cells[index].notes, {2, 7});

    // Both notes are on the board.
    for (final value in [2, 7]) {
      expect(
        find.descendant(
          of: find.byType(SudokuCellView).at(index),
          matching: find.text(sudokuSymbol(value)),
        ),
        findsOneWidget,
      );
    }

    // And back off again: the same key takes the note away.
    await _tapKey(tester, 2);
    expect(_game(tester).cells[index].notes, {7});
  });

  testWidgets('a pencil mark on a phone is a number, not a dot', (tester) async {
    // The size of phone the board is tightest on: a classic sudoku here is
    // twenty-eight pixels a cell, and the marks still have to be readable.
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openSudoku(tester);
    final index = _firstEmpty(tester);
    await _tapCell(tester, index);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit7);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump(const Duration(milliseconds: 60));

    final mark = find.descendant(
      of: find.byType(SudokuCellView).at(index),
      matching: find.text('7'),
    );
    expect(mark, findsOneWidget, reason: 'the mark was left as a dot');

    // And it fills the ninth of the cell it has to itself, rather than sitting
    // in the middle of it at half the size.
    final fontSize = tester.widget<Text>(mark).style!.fontSize!;
    expect(fontSize, greaterThan(_cellSize(tester) / 3 * 0.7));
  });

  testWidgets('a mark with no room to be written out comes back on zoom', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openSudoku(tester);
    await _chooseSize(tester, '16×16');

    final index = _firstEmpty(tester);
    await _tapCell(tester, index);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit7);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump(const Duration(milliseconds: 60));
    expect(_game(tester).cells[index].notes, {7});

    // Sixteen two-digit marks will not go into a cell this size, so they are
    // dotted in where their numbers would have been.
    expect(
      find.descendant(
        of: find.byType(SudokuCellView).at(index),
        matching: find.text('7'),
      ),
      findsNothing,
    );

    for (var step = 0; step < 3; step++) {
      await tester.tap(find.byKey(const ValueKey('sudoku-zoom-in')));
      await _advance(tester, 300);
    }

    expect(
      find.descendant(
        of: find.byType(SudokuCellView).at(index),
        matching: find.text('7'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('checking a cell says whether it is right', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openSudoku(tester);
    final index = _firstEmpty(tester);
    final answer = _game(tester).puzzle.solution[index];

    await _tapCell(tester, index);
    await _tapKey(tester, answer);
    await _tapChip(tester, 'Check cell');

    expect(find.text('That one is right'), findsOneWidget);
    expect(_game(tester).cells[index].mark, SudokuMark.correct);
    await _clearToast(tester);

    // A wrong value gets said so, and stays marked.
    await _tapKey(tester, answer);
    await _tapKey(tester, answer == 1 ? 2 : 1);
    await _tapChip(tester, 'Check cell');

    expect(find.text('That one is wrong'), findsOneWidget);
    expect(_game(tester).cells[index].mark, SudokuMark.wrong);
    await _clearToast(tester);
  });

  testWidgets('checking everything counts what is wrong', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openSudoku(tester);
    final game = _game(tester);
    final empties = [
      for (var index = 0; index < game.cells.length; index++)
        if (game.cells[index].isEmpty) index,
    ];

    for (final index in empties.take(2)) {
      await _tapCell(tester, index);
      await _tapKey(tester, game.puzzle.solution[index]);
    }
    await _tapCell(tester, empties[2]);
    await _tapKey(tester, game.puzzle.solution[empties[2]] == 1 ? 2 : 1);

    await _tapChip(tester, 'Check all');

    expect(find.text('1 cell is wrong'), findsOneWidget);
    await _clearToast(tester);

    // The status line keeps the count once the toast has gone.
    expect(find.byType(SudokuStatusLine), findsOneWidget);
    expect(find.text('1 cell is wrong'), findsOneWidget);
  });

  testWidgets('solve cell fills the cell in and counts up', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openSudoku(tester);
    final index = _firstEmpty(tester);
    final answer = _game(tester).puzzle.solution[index];

    await _tapCell(tester, index);
    await _tapChip(tester, 'Solve cell');

    expect(_game(tester).cells[index].value, answer);
    expect(_game(tester).cells[index].isRevealed, isTrue);
    expect(_game(tester).hintsUsed, 1);
  });

  testWidgets('giving up fills the board and closes the round', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openSudoku(tester);
    expect(find.byType(SudokuResultBanner), findsNothing);

    await _tapChip(tester, 'Give up');
    await _advance(tester, 900);

    expect(_game(tester).isRevealed, isTrue);
    expect(_game(tester).emptyCount, 0);
    expect(find.byType(SudokuResultBanner), findsOneWidget);
    expect(find.text('Round over'), findsOneWidget);
  });

  testWidgets('filling the last cell in is a win', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openSudoku(tester);
    // Smaller board, so that filling it in by hand is a handful of taps.
    await _tapChip(tester, '9×9');
    await tester.tap(find.text('4×4').last);
    await _advance(tester, 600);

    final game = _game(tester);
    expect(game.size, SudokuSize.four);

    for (var index = 0; index < game.cells.length; index++) {
      if (!game.cells[index].isEmpty) continue;
      await _tapCell(tester, index);
      await _tapKey(tester, game.puzzle.solution[index]);
    }
    await _advance(tester, 900);

    expect(_game(tester).isSolved, isTrue);
    expect(find.byType(SudokuResultBanner), findsOneWidget);
    expect(find.text('Solved!'), findsOneWidget);
  });

  testWidgets('a new game deals a fresh board', (tester) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openSudoku(tester);
    final index = _firstEmpty(tester);
    await _tapCell(tester, index);
    await _tapKey(tester, 1);
    expect(_game(tester).cells[index].value, 1);

    await _tapChip(tester, 'New game');
    await _advance(tester, 700);

    expect(_game(tester).round, 2);
    expect(_game(tester).selected, isNull);
  });

  testWidgets('the keys are a pad in the shape of the board box', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openSudoku(tester);

    // A classic sudoku gets a three by three pad: 1..3 on one row, 4 under 1.
    expect(_keyAt(tester, 1).dy, _keyAt(tester, 2).dy);
    expect(_keyAt(tester, 2).dy, _keyAt(tester, 3).dy);
    expect(_keyAt(tester, 4).dy, greaterThan(_keyAt(tester, 1).dy));
    expect(_keyAt(tester, 4).dx, _keyAt(tester, 1).dx);
    expect(_keyAt(tester, 7).dy, greaterThan(_keyAt(tester, 4).dy));

    // And they are big enough to hit with a thumb.
    expect(
      tester.getSize(find.byKey(const ValueKey('sudoku-key-1'))).width,
      greaterThanOrEqualTo(40),
    );
  });

  testWidgets('notes and erase sit with the keys, under the board', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openSudoku(tester);

    final boardBottom = tester.getBottomLeft(find.byType(SudokuBoardView)).dy;
    final notes = tester.getTopLeft(find.byKey(const ValueKey('sudoku-notes')));

    expect(find.byKey(const ValueKey('sudoku-notes')), findsOneWidget);
    expect(notes.dy, greaterThan(boardBottom - 1));
    expect(notes.dy, lessThan(_keyAt(tester, 1).dy));
  });

  testWidgets('a two-digit value goes in from its own key', (tester) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openSudoku(tester);
    await _chooseSize(tester, '12×12');
    expect(_game(tester).size, SudokuSize.twelve);

    final index = _firstEmpty(tester);
    await _tapCell(tester, index);
    await _tapKey(tester, 12);

    expect(_game(tester).cells[index].value, 12);
    expect(
      find.descendant(
        of: find.byType(SudokuCellView).at(index),
        matching: find.text('12'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('two digits typed together name one value', (tester) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openSudoku(tester);
    await _chooseSize(tester, '12×12');

    final index = _firstEmpty(tester);
    await _tapCell(tester, index);

    // The first digit is written at once, and the second replaces it with the
    // pair the two of them make.
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pump(const Duration(milliseconds: 80));
    expect(_game(tester).cells[index].value, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pump(const Duration(milliseconds: 80));
    expect(_game(tester).cells[index].value, 12);

    // Once the pair has timed out, the next digit stands on its own.
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.pump(const Duration(milliseconds: 80));
    expect(_game(tester).cells[index].value, 3);

    // And a pair that would run off the end of the board is not a pair: a
    // 12x12 has no 34, so the 4 stands alone.
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.pump(const Duration(milliseconds: 80));
    expect(_game(tester).cells[index].value, 4);
  });

  testWidgets('two digits typed together make one pencil mark', (tester) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openSudoku(tester);
    await _chooseSize(tester, '12×12');

    final index = _firstEmpty(tester);
    await _tapCell(tester, index);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump(const Duration(milliseconds: 80));

    // The 1 pencilled in a moment ago comes back off when it becomes a 10.
    expect(_game(tester).cells[index].notes, {10});
  });

  testWidgets('the bigger boards can be zoomed into', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openSudoku(tester);
    // A classic sudoku reads well enough as it is.
    expect(find.byKey(const ValueKey('sudoku-zoom-in')), findsNothing);

    await _chooseSize(tester, '16×16');
    expect(find.byKey(const ValueKey('sudoku-zoom-in')), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);

    final before = _cellSize(tester);
    await tester.tap(find.byKey(const ValueKey('sudoku-zoom-in')));
    await _advance(tester, 400);

    expect(find.text('150%'), findsOneWidget);
    expect(_cellSize(tester), greaterThan(before));
    // Zoomed past what the screen holds, the board is there to be dragged.
    expect(
      find.descendant(
        of: find.byType(SudokuBoardView),
        matching: find.byType(SingleChildScrollView),
      ),
      findsWidgets,
    );

    await tester.tap(find.byKey(const ValueKey('sudoku-zoom-out')));
    await _advance(tester, 400);
    expect(_cellSize(tester), before);
  });

  testWidgets('a new board starts back at its own size', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openSudoku(tester);
    await _chooseSize(tester, '16×16');

    await tester.tap(find.byKey(const ValueKey('sudoku-zoom-in')));
    await _advance(tester, 400);
    expect(find.text('150%'), findsOneWidget);

    await _tapChip(tester, 'New game');
    await _advance(tester, 900);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('the board speaks German when the app does', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openSudoku(tester);

    await tester.tap(find.byTooltip('Language'));
    await _advance(tester, 400);
    await tester.tap(find.text('Deutsch').last);
    await _advance(tester, 700);

    expect(find.text('Neues Spiel'), findsOneWidget);
    expect(find.text('Notizen'), findsOneWidget);
    expect(find.text('Alles prüfen'), findsOneWidget);
    expect(find.text('Feld lösen'), findsOneWidget);
    expect(find.text('Aufgeben'), findsOneWidget);
    expect(find.text('Mittel'), findsOneWidget);

    // Switching the language is not a new game: the board carries on.
    expect(_game(tester).round, 1);

    await _tapChip(tester, 'Aufgeben');
    await _advance(tester, 900);
    expect(find.text('Runde beendet'), findsOneWidget);
  });
}
