import 'dart:math';

import 'sudoku_geometry.dart';
import 'sudoku_models.dart';
import 'sudoku_solver.dart';

/// The share of the cells a board can spare that each difficulty actually takes
/// away.
///
/// The measure is relative rather than a flat fraction of the board because how
/// empty a sudoku can be left shrinks as it grows: a 4×4 can give up three
/// quarters of its cells and still be worked out step by step, a 25×25 a little
/// over half. Digging as deep as the board allows and then handing a share of
/// the cells back gives the same three rungs at every size.
const Map<SudokuDifficulty, double> kSudokuHoleShares = {
  SudokuDifficulty.easy: 0.62,
  SudokuDifficulty.medium: 0.84,
  SudokuDifficulty.hard: 1.0,
};

/// Search nodes one attempt at the opening board may cost, and how many
/// attempts it gets.
///
/// Filling the board at random is the one part of generating a puzzle that
/// searches at all, and how long it takes depends entirely on the luck of the
/// first few cells. Starting over on a fresh draw beats letting one unlucky
/// attempt backtrack its way out, so the budget per attempt is deliberately
/// short and there are several of them.
const int kSudokuFillBudget = 100000;
const int kSudokuFillAttempts = 6;

/// Deals a puzzle of [size] dug out to [difficulty].
///
/// Every puzzle has exactly one solution *and* can be worked out without ever
/// guessing: each step is a cell with one value left, or a value with one cell
/// left in its row, column or box. Difficulty is how much of the board is left
/// empty, which is what decides how hard those steps are to spot.
SudokuPuzzle generateSudoku({
  required SudokuSize size,
  required SudokuDifficulty difficulty,
  Random? random,
}) {
  final rng = random ?? Random();
  final geometry = SudokuGeometry.of(size);
  final solver = SudokuSolver(geometry);

  final solution = _buildSolution(geometry, solver, rng);
  final givens = _dig(geometry, solver, solution, difficulty, rng);

  return SudokuPuzzle(
    size: size,
    difficulty: difficulty,
    givens: givens,
    solution: solution,
  );
}

/// A finished, valid board.
///
/// Filling a grid at random is what gives a genuinely arbitrary board, rather
/// than one of the family a formula can produce. Each attempt is seeded and then
/// completed by search; a draw that does not come out within its budget is
/// dropped for a fresh one, and the shuffled base pattern below is there in case
/// none of them lands.
List<int> _buildSolution(
  SudokuGeometry geometry,
  SudokuSolver solver,
  Random random,
) {
  for (var attempt = 0; attempt < kSudokuFillAttempts; attempt++) {
    final grid = List<int>.filled(geometry.cellCount, 0);
    _seedDiagonal(geometry, grid, random);

    final filled = solver.findSolution(
      grid,
      shuffle: random,
      budget: kSudokuFillBudget,
    );
    if (filled != null) return filled;
  }
  return _patternSolution(geometry.size, random);
}

/// Writes a random permutation into each box down the diagonal.
///
/// Those boxes share no row and no column, so whatever goes in them is legal,
/// and having them settled cuts the choices left for everything else down
/// sharply — on a 25×25 board it is the difference between filling it in a blink
/// and searching for a second or more. It does not guarantee the rest can be
/// completed (on a 4×4 there is barely any room to recover), which is what the
/// attempts around it are for.
void _seedDiagonal(SudokuGeometry geometry, List<int> grid, Random random) {
  final size = geometry.size;

  for (var box = 0; box < min(size.bandCount, size.stackCount); box++) {
    final values = [for (var value = 1; value <= size.length; value++) value]
      ..shuffle(random);
    var slot = 0;

    for (var row = 0; row < size.boxHeight; row++) {
      for (var column = 0; column < size.boxWidth; column++) {
        grid[geometry.indexOf(
          box * size.boxHeight + row,
          box * size.boxWidth + column,
        )] = values[slot++];
      }
    }
  }
}

/// Empties [solution] as far as it will go, then puts back the share of the
/// cells that [difficulty] does not want taken.
///
/// A cell is only ever removed once the smaller puzzle has been shown to be
/// solvable a step at a time, and the finished board it starts from is, so every
/// puzzle along the way is too — including the one that comes back, since
/// handing a cell back can only ever make the reasoning easier.
List<int> _dig(
  SudokuGeometry geometry,
  SudokuSolver solver,
  List<int> solution,
  SudokuDifficulty difficulty,
  Random random,
) {
  final givens = List<int>.of(solution);
  final order = List<int>.generate(geometry.cellCount, (index) => index)
    ..shuffle(random);
  final removed = <int>[];

  for (final index in order) {
    final value = givens[index];
    givens[index] = 0;
    if (solver.isSolvableWithSingles(givens)) {
      removed.add(index);
    } else {
      givens[index] = value;
    }
  }

  // Which cells come back is drawn afresh rather than taken from the tail of
  // the dig, where the cells that were the hardest to part with have collected.
  final keep = (removed.length * kSudokuHoleShares[difficulty]!).round();
  removed.shuffle(random);
  for (final index in removed.skip(keep)) {
    givens[index] = solution[index];
  }

  return givens;
}

/// A valid board built from the closed form `boxWidth * (r % boxHeight) +
/// r ~/ boxHeight + c`, then shuffled by the moves that cannot break it:
/// relabelling the values, reordering the rows inside a band and the bands
/// themselves, and the same for columns and stacks.
///
/// It is only the fallback for [_buildSolution] — every row of the base grid is
/// a rotation of every other, and no amount of shuffling fully hides that — but
/// it is valid for any box shape and costs one pass over the board.
List<int> _patternSolution(SudokuSize size, Random random) {
  final length = size.length;
  final symbols = [for (var value = 1; value <= length; value++) value]
    ..shuffle(random);

  final rowOrder = _shuffledLines(size.bandCount, size.boxHeight, random);
  final columnOrder = _shuffledLines(size.stackCount, size.boxWidth, random);

  final grid = List<int>.filled(size.cellCount, 0);
  for (var row = 0; row < length; row++) {
    for (var column = 0; column < length; column++) {
      final sourceRow = rowOrder[row];
      final base =
          (size.boxWidth * (sourceRow % size.boxHeight) +
              sourceRow ~/ size.boxHeight +
              columnOrder[column]) %
          length;
      grid[row * length + column] = symbols[base];
    }
  }
  return grid;
}

/// Row (or column) indices with the groups shuffled and the lines inside each
/// group shuffled within it, so that whole boxes stay whole.
List<int> _shuffledLines(int groupCount, int groupSize, Random random) {
  final groups = [for (var group = 0; group < groupCount; group++) group]
    ..shuffle(random);

  return [
    for (final group in groups)
      ...[
        for (var line = 0; line < groupSize; line++) group * groupSize + line,
      ]..shuffle(random),
  ];
}
