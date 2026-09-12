import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/games/sudoku/domain/sudoku_generator.dart';
import 'package:flutter_app/features/games/sudoku/domain/sudoku_geometry.dart';
import 'package:flutter_app/features/games/sudoku/domain/sudoku_models.dart';
import 'package:flutter_app/features/games/sudoku/domain/sudoku_solver.dart';

import 'sudoku_fixture.dart';

/// Whether every row, column and box of [grid] holds each value exactly once.
bool isLegalAndComplete(SudokuGeometry geometry, List<int> grid) {
  if (grid.length != geometry.cellCount) return false;
  if (grid.any((value) => value < 1 || value > geometry.length)) return false;

  for (final unit in geometry.units) {
    final seen = <int>{};
    for (final index in unit) {
      if (!seen.add(grid[index])) return false;
    }
  }
  return true;
}

void main() {
  group('sizes', () {
    test('a box tiles the board exactly', () {
      for (final size in SudokuSize.values) {
        expect(
          size.boxHeight * size.boxWidth,
          size.length,
          reason: '${size.length} has a box that does not hold every value',
        );
        expect(size.bandCount * size.boxHeight, size.length);
        expect(size.stackCount * size.boxWidth, size.length);
      }
    });

    test('every size the game offers is asked for', () {
      expect(
        SudokuSize.values.map((size) => size.length),
        [4, 6, 9, 12, 16, 25],
      );
      expect(SudokuSize.initial.length, 9);
    });
  });

  group('symbols', () {
    test('there is one glyph per value of the largest board', () {
      expect(kSudokuSymbols.length, SudokuSize.twentyFive.length);
      expect(kSudokuSymbols.split('').toSet().length, kSudokuSymbols.length);
    });

    test('no glyph can be taken for another', () {
      // The board never shows a 0, so O is safe, but 1 and I are not.
      expect(kSudokuSymbols.contains('I'), isFalse);
      expect(kSudokuSymbols.contains('0'), isFalse);
    });

    test('a value survives the round trip through its glyph', () {
      for (var value = 1; value <= kSudokuSymbols.length; value++) {
        expect(sudokuValueOf(sudokuSymbol(value), 25), value);
      }
    });

    test('a glyph the board has no value for is refused', () {
      // A nine-value board knows nothing of the letters.
      expect(sudokuValueOf('A', 9), isNull);
      expect(sudokuValueOf('A', 12), 10);
      expect(sudokuValueOf('I', 25), isNull);
      expect(sudokuValueOf('!', 9), isNull);
      expect(sudokuValueOf('12', 25), isNull);
    });

    test('lower case reads the same as upper case', () {
      expect(sudokuValueOf('a', 16), sudokuValueOf('A', 16));
    });
  });

  group('geometry', () {
    test('peers are the rest of the row, column and box', () {
      final geometry = SudokuGeometry.of(SudokuSize.nine);
      final peers = geometry.peersOf(geometry.indexOf(4, 4));

      // Eight others in each of the three groups, less the overlaps.
      expect(peers.length, 20);
      expect(peers, isNot(contains(geometry.indexOf(4, 4))));
      expect(peers, contains(geometry.indexOf(4, 0)));
      expect(peers, contains(geometry.indexOf(0, 4)));
      expect(peers, contains(geometry.indexOf(3, 3)));
      expect(peers, isNot(contains(geometry.indexOf(0, 0))));
    });

    test('a 6x6 box is two rows by three columns', () {
      final geometry = SudokuGeometry.of(SudokuSize.six);

      expect(geometry.boxOf(geometry.indexOf(0, 0)), 0);
      expect(geometry.boxOf(geometry.indexOf(1, 2)), 0);
      expect(geometry.boxOf(geometry.indexOf(0, 3)), 1);
      expect(geometry.boxOf(geometry.indexOf(2, 0)), 2);
    });

    test('every cell belongs to exactly three groups', () {
      for (final size in SudokuSize.values) {
        final geometry = SudokuGeometry.of(size);
        expect(geometry.units.length, size.length * 3);

        final counts = List<int>.filled(size.cellCount, 0);
        for (final unit in geometry.units) {
          expect(unit.length, size.length);
          for (final index in unit) {
            counts[index]++;
          }
        }
        expect(counts.every((count) => count == 3), isTrue);
      }
    });
  });

  group('solver', () {
    final geometry = SudokuGeometry.of(SudokuSize.nine);
    final solver = SudokuSolver(geometry);

    test('finds the one solution of a known puzzle', () {
      final puzzle = parseGrid(kKnownPuzzle, 9);
      final solution = parseGrid(kKnownSolution, 9);

      expect(solver.findSolution(List<int>.of(puzzle)), solution);
      expect(solver.countSolutions(List<int>.of(puzzle)), 1);
    });

    test('plain reasoning reaches the same answer', () {
      expect(
        solver.solveWithSingles(parseGrid(kKnownPuzzle, 9)),
        parseGrid(kKnownSolution, 9),
      );
    });

    test('a board with too little to go on has more than one answer', () {
      final sparse = List<int>.filled(16, 0);
      sparse[0] = 1;
      final small = SudokuSolver(SudokuGeometry.of(SudokuSize.four));

      expect(small.countSolutions(sparse, limit: 2), 2);
      expect(small.isSolvableWithSingles(sparse), isFalse);
    });

    test('a grid that already breaks a rule has no answer', () {
      final clash = List<int>.filled(81, 0);
      clash[0] = 5;
      clash[1] = 5;

      expect(solver.countSolutions(clash), 0);
      expect(solver.findSolution(clash), isNull);
      expect(solver.isSolvableWithSingles(clash), isFalse);
    });

    test('a puzzle it cannot reason all the way through is left alone', () {
      // One clue short of the known puzzle, which plain singles cannot finish.
      final grid = parseGrid(kKnownPuzzle, 9);
      final before = List<int>.of(grid);

      solver.solveWithSingles(grid);
      expect(grid, before, reason: 'the caller\'s grid was written to');
    });

    test('running out of budget is never read as an answer', () {
      // One node is not enough to settle anything.
      final puzzle = parseGrid(kKnownPuzzle, 9);

      expect(solver.findSolution(puzzle, budget: 1), isNull);
      expect(solver.exhausted, isTrue);
    });
  });

  group('generator', () {
    for (final size in SudokuSize.values) {
      for (final difficulty in SudokuDifficulty.values) {
        test('${size.length}x${size.length} ${difficulty.name} holds up', () {
          final geometry = SudokuGeometry.of(size);
          final solver = SudokuSolver(geometry);
          final puzzle = generateSudoku(
            size: size,
            difficulty: difficulty,
            random: Random(size.length * 31 + difficulty.index),
          );

          expect(puzzle.size, size);
          expect(puzzle.difficulty, difficulty);
          expect(puzzle.givens.length, size.cellCount);
          expect(
            isLegalAndComplete(geometry, puzzle.solution),
            isTrue,
            reason: 'the solution is not a legal full board',
          );

          for (var index = 0; index < puzzle.givens.length; index++) {
            if (puzzle.givens[index] == 0) continue;
            expect(
              puzzle.givens[index],
              puzzle.solution[index],
              reason: 'clue at $index contradicts the solution',
            );
          }

          // The promise the game makes: it can be worked out a step at a time,
          // which is also what leaves it with exactly one answer.
          expect(
            solver.solveWithSingles(List<int>.of(puzzle.givens)),
            puzzle.solution,
            reason: 'it cannot be reasoned out without guessing',
          );
          expect(puzzle.holeCount, greaterThan(0));
        });
      }
    }

    test('one answer, counted the hard way', () {
      // An independent check that reasoning a board out really does mean it has
      // a single answer — by exhaustive search, which only the smaller boards
      // can be put through.
      for (final size in [
        SudokuSize.four,
        SudokuSize.six,
        SudokuSize.nine,
        SudokuSize.twelve,
      ]) {
        final solver = SudokuSolver(SudokuGeometry.of(size));
        for (final difficulty in SudokuDifficulty.values) {
          final puzzle = generateSudoku(
            size: size,
            difficulty: difficulty,
            random: Random(7),
          );
          expect(
            solver.countSolutions(List<int>.of(puzzle.givens), limit: 2),
            1,
            reason: '${size.length} ${difficulty.name} has more than one answer',
          );
        }
      }
    });

    test('the harder it is, the less of the board is given away', () {
      for (final size in SudokuSize.values) {
        final holes = {
          for (final difficulty in SudokuDifficulty.values)
            difficulty: generateSudoku(
              size: size,
              difficulty: difficulty,
              random: Random(3),
            ).holeCount,
        };

        expect(
          holes[SudokuDifficulty.easy]!,
          lessThan(holes[SudokuDifficulty.medium]!),
          reason: 'easy is no fuller than medium on ${size.length}',
        );
        expect(
          holes[SudokuDifficulty.medium]!,
          lessThan(holes[SudokuDifficulty.hard]!),
          reason: 'medium is no fuller than hard on ${size.length}',
        );
      }
    });

    test('two draws are two different boards', () {
      final random = Random(99);
      final first = generateSudoku(
        size: SudokuSize.nine,
        difficulty: SudokuDifficulty.medium,
        random: random,
      );
      final second = generateSudoku(
        size: SudokuSize.nine,
        difficulty: SudokuDifficulty.medium,
        random: random,
      );

      expect(first.solution, isNot(second.solution));
    });
  });
}
