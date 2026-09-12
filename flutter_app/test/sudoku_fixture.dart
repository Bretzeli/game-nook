import 'dart:math';

import 'package:flutter_app/features/games/sudoku/domain/sudoku_generator.dart';
import 'package:flutter_app/features/games/sudoku/domain/sudoku_models.dart';
import 'package:flutter_app/features/games/sudoku/state/sudoku_controller.dart';

/// Deals the real thing, but from a fixed seed, so a test gets a board that is
/// the same every run and still has every property a dealt puzzle has.
///
/// Each call moves the seed on, so asking for a new game really does deal a
/// different board.
class FixtureSudokuFactory extends SudokuPuzzleFactory {
  FixtureSudokuFactory({this.seed = 20250912});

  final int seed;

  /// How many boards have been asked for.
  int deals = 0;

  @override
  SudokuPuzzle create({
    required SudokuSize size,
    required SudokuDifficulty difficulty,
  }) {
    deals++;
    return generateSudoku(
      size: size,
      difficulty: difficulty,
      random: Random(seed + deals),
    );
  }
}

/// Reads a board written out as text, with `.` for a cell that is empty.
/// Whitespace is ignored, so a puzzle can be laid out as the square it is.
List<int> parseGrid(String text, int length) {
  final grid = <int>[];
  for (final rune in text.split('')) {
    if (rune.trim().isEmpty) continue;
    grid.add(rune == '.' ? 0 : sudokuValueOf(rune, length)!);
  }
  return grid;
}

/// The sudoku from the Wikipedia article, which has exactly one solution.
const String kKnownPuzzle = '''
53..7....
6..195...
.98....6.
8...6...3
4..8.3..1
7...2...6
.6....28.
...419..5
....8..79
''';

const String kKnownSolution = '''
534678912
672195348
198342567
859761423
426853791
713924856
961537284
287419635
345286179
''';
