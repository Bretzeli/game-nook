import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/games/sudoku/domain/sudoku_models.dart';
import 'package:flutter_app/features/games/sudoku/state/sudoku_controller.dart';
import 'package:flutter_app/features/games/sudoku/state/sudoku_game_state.dart';
import 'package:flutter_app/features/games/sudoku/state/sudoku_settings.dart';

import 'sudoku_fixture.dart';

/// The controller hands the frame back before it deals, so that the board can
/// put a spinner up first. These tests pump for it rather than wait on a timer.
void main() {
  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        sudokuPuzzleFactoryProvider.overrideWithValue(FixtureSudokuFactory()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  SudokuController controllerOf(ProviderContainer container) =>
      container.read(sudokuGameProvider.notifier);

  SudokuGameState gameOf(ProviderContainer container) =>
      container.read(sudokuGameProvider);

  /// Waits for a board to be dealt.
  Future<SudokuGameState> deal(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    container.read(sudokuGameProvider);
    await tester.pump();
    await tester.pump();

    final game = gameOf(container);
    expect(game.isPlaying, isTrue, reason: 'no board was dealt');
    return game;
  }

  int firstEmpty(SudokuGameState game) =>
      game.cells.indexWhere((cell) => cell.isEmpty);

  int firstGiven(SudokuGameState game) =>
      game.cells.indexWhere((cell) => cell.isGiven);

  /// Any value that does not belong at [index].
  int wrongValueAt(SudokuGameState game, int index) {
    final answer = game.puzzle.solution[index];
    return answer == 1 ? 2 : 1;
  }

  group('dealing', () {
    testWidgets('the board starts as the puzzle was dealt', (tester) async {
      final container = makeContainer();
      final game = await deal(tester, container);

      expect(game.cells.length, game.puzzle.givens.length);
      expect(game.round, 1);
      expect(game.hintsUsed, 0);
      expect(game.selected, isNull);

      for (var index = 0; index < game.cells.length; index++) {
        final cell = game.cells[index];
        final given = game.puzzle.givens[index];
        expect(cell.value, given);
        expect(cell.isGiven, given != 0);
        expect(cell.isEditable, given == 0);
      }
      expect(game.emptyCount, game.puzzle.holeCount);
    });

    testWidgets('a new game deals a different board', (tester) async {
      final container = makeContainer();
      final first = await deal(tester, container);
      final before = first.puzzle.solution;

      controllerOf(container).newGame();
      await tester.pump();
      await tester.pump();

      final second = gameOf(container);
      expect(second.round, 2);
      expect(second.puzzle.solution, isNot(before));
    });

    testWidgets('a different size deals a board of that size', (tester) async {
      final container = makeContainer();
      await deal(tester, container);

      controllerOf(container).changeSize(SudokuSize.four);
      await tester.pump();
      await tester.pump();

      final game = gameOf(container);
      expect(game.size, SudokuSize.four);
      expect(game.cells.length, 16);
      expect(container.read(sudokuSettingsProvider).size, SudokuSize.four);
    });

    testWidgets('a different difficulty deals a new board', (tester) async {
      final container = makeContainer();
      await deal(tester, container);

      controllerOf(container).changeDifficulty(SudokuDifficulty.hard);
      await tester.pump();
      await tester.pump();

      final game = gameOf(container);
      expect(game.round, 2);
      expect(game.puzzle.difficulty, SudokuDifficulty.hard);
    });
  });

  group('filling cells in', () {
    testWidgets('a value goes into the selected cell', (tester) async {
      final container = makeContainer();
      final game = await deal(tester, container);
      final index = firstEmpty(game);
      final controller = controllerOf(container);

      controller.select(index);
      controller.place(3);

      expect(gameOf(container).cells[index].value, 3);
      expect(gameOf(container).cells[index].isRevealed, isFalse);
    });

    testWidgets('entering the same value again takes it back out', (
      tester,
    ) async {
      final container = makeContainer();
      final game = await deal(tester, container);
      final index = firstEmpty(game);
      final controller = controllerOf(container);

      controller.select(index);
      controller.place(3);
      controller.place(3);

      expect(gameOf(container).cells[index].isEmpty, isTrue);
    });

    testWidgets('a given cannot be written over', (tester) async {
      final container = makeContainer();
      final game = await deal(tester, container);
      final index = firstGiven(game);
      final before = game.cells[index].value;
      final controller = controllerOf(container);

      controller.select(index);
      controller.place(before == 1 ? 2 : 1);
      controller.erase();

      expect(gameOf(container).cells[index].value, before);
    });

    testWidgets('a value outside the board is refused', (tester) async {
      final container = makeContainer();
      final game = await deal(tester, container);
      final index = firstEmpty(game);
      final controller = controllerOf(container);

      controller.select(index);
      controller.place(game.length + 1);
      controller.place(0);

      expect(gameOf(container).cells[index].isEmpty, isTrue);
    });

    testWidgets('nothing happens while no cell is picked out', (tester) async {
      final container = makeContainer();
      final game = await deal(tester, container);
      final controller = controllerOf(container);

      controller.place(5);
      controller.toggleNote(5);
      controller.erase();

      expect(gameOf(container).emptyCount, game.emptyCount);
    });

    testWidgets('the keypad counts down as a value is placed', (tester) async {
      final container = makeContainer();
      final game = await deal(tester, container);
      final index = firstEmpty(game);
      final value = game.puzzle.solution[index];
      final before = game.remainingOf(value);
      final controller = controllerOf(container);

      controller.select(index);
      controller.place(value);

      expect(gameOf(container).remainingOf(value), before - 1);
    });
  });

  group('notes', () {
    testWidgets('a note goes on and comes off again', (tester) async {
      final container = makeContainer();
      final game = await deal(tester, container);
      final index = firstEmpty(game);
      final controller = controllerOf(container);

      controller.select(index);
      controller.toggleNote(4);
      controller.toggleNote(7);
      expect(gameOf(container).cells[index].notes, {4, 7});

      controller.toggleNote(4);
      expect(gameOf(container).cells[index].notes, {7});
    });

    testWidgets('notes mode sends a value key to the pencil marks', (
      tester,
    ) async {
      final container = makeContainer();
      final game = await deal(tester, container);
      final index = firstEmpty(game);
      final controller = controllerOf(container);

      controller.setNotesMode(true);
      controller.select(index);
      controller.enter(6);

      expect(gameOf(container).cells[index].notes, {6});
      expect(gameOf(container).cells[index].isEmpty, isTrue);

      controller.toggleNotesMode();
      controller.enter(6);
      expect(gameOf(container).cells[index].value, 6);
      expect(gameOf(container).cells[index].notes, isEmpty);
    });

    testWidgets('a cell that holds a value takes no notes', (tester) async {
      final container = makeContainer();
      final game = await deal(tester, container);
      final index = firstEmpty(game);
      final controller = controllerOf(container);

      controller.select(index);
      controller.place(2);
      controller.toggleNote(5);

      expect(gameOf(container).cells[index].notes, isEmpty);
    });

    testWidgets('placing a value clears that note from its peers', (
      tester,
    ) async {
      final container = makeContainer();
      final game = await deal(tester, container);
      final controller = controllerOf(container);

      final index = firstEmpty(game);
      final peers = game.geometry.peersOf(index);
      final peer = peers.firstWhere((peer) => game.cells[peer].isEmpty);
      final elsewhere = List<int>.generate(
        game.cells.length,
        (index) => index,
      ).firstWhere(
        (other) =>
            other != index && !peers.contains(other) && game.cells[other].isEmpty,
      );

      // The same note in a cell that sees the change and in one that does not.
      for (final target in [peer, elsewhere]) {
        controller.select(target);
        controller.toggleNote(5);
      }

      controller.select(index);
      controller.place(5);

      expect(gameOf(container).cells[peer].notes, isEmpty);
      expect(gameOf(container).cells[elsewhere].notes, {5});
    });

    testWidgets('erasing clears the value first, then the notes', (
      tester,
    ) async {
      final container = makeContainer();
      final game = await deal(tester, container);
      final index = firstEmpty(game);
      final controller = controllerOf(container);

      controller.select(index);
      controller.toggleNote(3);
      controller.place(8);
      expect(gameOf(container).cells[index].value, 8);

      controller.erase();
      expect(gameOf(container).cells[index].isEmpty, isTrue);
      expect(gameOf(container).cells[index].notes, isEmpty);

      controller.toggleNote(3);
      controller.erase();
      expect(gameOf(container).cells[index].notes, isEmpty);
    });
  });

  group('checking', () {
    testWidgets('a checked cell is marked right or wrong', (tester) async {
      final container = makeContainer();
      final game = await deal(tester, container);
      final index = firstEmpty(game);
      final controller = controllerOf(container);

      controller.select(index);
      controller.place(game.puzzle.solution[index]);
      expect(controller.checkSelected().wrong, 0);
      expect(gameOf(container).cells[index].mark, SudokuMark.correct);

      controller.place(wrongValueAt(game, index));
      // Changing the cell takes the mark off with it.
      expect(gameOf(container).cells[index].mark, SudokuMark.none);

      expect(controller.checkSelected().wrong, 1);
      expect(gameOf(container).cells[index].mark, SudokuMark.wrong);
    });

    testWidgets('checking everything counts what is wrong', (tester) async {
      final container = makeContainer();
      final game = await deal(tester, container);
      final empties = [
        for (var index = 0; index < game.cells.length; index++)
          if (game.cells[index].isEmpty) index,
      ];
      final controller = controllerOf(container);

      for (final index in empties.take(3)) {
        controller.select(index);
        controller.place(game.puzzle.solution[index]);
      }
      for (final index in empties.skip(3).take(2)) {
        controller.select(index);
        controller.place(wrongValueAt(game, index));
      }

      final result = controller.checkAll();
      expect(result.checked, 5);
      expect(result.wrong, 2);
      expect(gameOf(container).wrongCount, 2);
    });

    testWidgets('a check with nothing filled in says so', (tester) async {
      final container = makeContainer();
      await deal(tester, container);

      final result = controllerOf(container).checkAll();
      expect(result.isEmpty, isTrue);
      expect(gameOf(container).hasMarks, isFalse);
    });

    testWidgets('the green marks clear but the red ones stay', (tester) async {
      final container = makeContainer();
      final game = await deal(tester, container);
      final empties = [
        for (var index = 0; index < game.cells.length; index++)
          if (game.cells[index].isEmpty) index,
      ];
      final controller = controllerOf(container);

      controller.select(empties[0]);
      controller.place(game.puzzle.solution[empties[0]]);
      controller.select(empties[1]);
      controller.place(wrongValueAt(game, empties[1]));
      controller.checkAll();

      controller.clearCorrectMarks();

      expect(gameOf(container).cells[empties[0]].mark, SudokuMark.none);
      expect(gameOf(container).cells[empties[1]].mark, SudokuMark.wrong);
    });

    testWidgets('a given is never something to be right or wrong about', (
      tester,
    ) async {
      final container = makeContainer();
      final game = await deal(tester, container);
      final controller = controllerOf(container);

      controller.select(firstGiven(game));
      expect(gameOf(container).canCheckSelected, isFalse);
      expect(controller.checkSelected().isEmpty, isTrue);
    });
  });

  group('help', () {
    testWidgets('solving a cell fills it in and locks it', (tester) async {
      final container = makeContainer();
      final game = await deal(tester, container);
      final index = firstEmpty(game);
      final controller = controllerOf(container);

      controller.select(index);
      controller.revealSelected();

      final cell = gameOf(container).cells[index];
      expect(cell.value, game.puzzle.solution[index]);
      expect(cell.isRevealed, isTrue);
      expect(cell.isEditable, isFalse);
      expect(gameOf(container).hintsUsed, 1);

      // And it cannot be undone by the player.
      controller.erase();
      expect(gameOf(container).cells[index].value, game.puzzle.solution[index]);
    });

    testWidgets('solving a cell clears the note it rules out', (tester) async {
      final container = makeContainer();
      final game = await deal(tester, container);
      final controller = controllerOf(container);

      final index = firstEmpty(game);
      final answer = game.puzzle.solution[index];
      final peer = game.geometry
          .peersOf(index)
          .firstWhere((peer) => game.cells[peer].isEmpty);

      controller.select(peer);
      controller.toggleNote(answer);
      controller.select(index);
      controller.revealSelected();

      expect(gameOf(container).cells[peer].notes, isEmpty);
    });

    testWidgets('a cell that is already right cannot be solved again', (
      tester,
    ) async {
      final container = makeContainer();
      final game = await deal(tester, container);
      final index = firstEmpty(game);
      final controller = controllerOf(container);

      controller.select(index);
      controller.place(game.puzzle.solution[index]);

      expect(gameOf(container).canRevealSelected, isFalse);
      controller.revealSelected();
      expect(gameOf(container).hintsUsed, 0);
    });

    testWidgets('giving up fills the board and ends the round', (tester) async {
      final container = makeContainer();
      final game = await deal(tester, container);
      final empties = [
        for (var index = 0; index < game.cells.length; index++)
          if (game.cells[index].isEmpty) index,
      ];
      final controller = controllerOf(container);

      // One right and one wrong, to show what happens to each.
      controller.select(empties[0]);
      controller.place(game.puzzle.solution[empties[0]]);
      controller.select(empties[1]);
      controller.place(wrongValueAt(game, empties[1]));

      controller.giveUp();
      final after = gameOf(container);

      expect(after.isRevealed, isTrue);
      expect(after.isFinished, isTrue);
      expect(after.emptyCount, 0);
      for (var index = 0; index < after.cells.length; index++) {
        expect(after.cells[index].value, game.puzzle.solution[index]);
      }
      // What the player got right stays theirs; what they got wrong is handed
      // over.
      expect(after.cells[empties[0]].isRevealed, isFalse);
      expect(after.cells[empties[1]].isRevealed, isTrue);

      // And the board is closed to further entry.
      controller.select(empties[2]);
      controller.place(1);
      expect(gameOf(container).cells[empties[2]].value, after.cells[empties[2]].value);
    });
  });

  group('finishing', () {
    testWidgets('filling the last cell in wins', (tester) async {
      final container = makeContainer();
      final game = await deal(tester, container);
      final controller = controllerOf(container);

      for (var index = 0; index < game.cells.length; index++) {
        if (!game.cells[index].isEmpty) continue;
        controller.select(index);
        controller.place(game.puzzle.solution[index]);
      }

      final after = gameOf(container);
      expect(after.isSolved, isTrue);
      expect(after.isFinished, isTrue);
      expect(after.emptyCount, 0);
    });

    testWidgets('a board filled in wrongly is not a win', (tester) async {
      final container = makeContainer();
      final game = await deal(tester, container);
      final controller = controllerOf(container);
      final empties = [
        for (var index = 0; index < game.cells.length; index++)
          if (game.cells[index].isEmpty) index,
      ];

      for (final index in empties) {
        controller.select(index);
        controller.place(
          index == empties.last
              ? wrongValueAt(game, index)
              : game.puzzle.solution[index],
        );
      }

      expect(gameOf(container).isSolved, isFalse);
      expect(gameOf(container).isPlaying, isTrue);
    });
  });

  group('the selection', () {
    testWidgets('moves a step at a time and stops at the edges', (
      tester,
    ) async {
      final container = makeContainer();
      final game = await deal(tester, container);
      final controller = controllerOf(container);
      final geometry = game.geometry;

      // Nothing picked out yet: the first move lands on the top left.
      controller.moveSelection(rows: 1);
      expect(gameOf(container).selected, 0);

      controller.moveSelection(columns: 1);
      expect(gameOf(container).selected, geometry.indexOf(0, 1));
      controller.moveSelection(rows: 1);
      expect(gameOf(container).selected, geometry.indexOf(1, 1));

      controller.moveSelection(rows: -1);
      controller.moveSelection(rows: -1);
      expect(gameOf(container).selected, geometry.indexOf(0, 1));

      controller.clearSelection();
      expect(gameOf(container).selected, isNull);
    });

    testWidgets('a cell outside the board is not selectable', (tester) async {
      final container = makeContainer();
      final game = await deal(tester, container);
      final controller = controllerOf(container);

      controller.select(-1);
      controller.select(game.cells.length);
      expect(gameOf(container).selected, isNull);
    });
  });
}
