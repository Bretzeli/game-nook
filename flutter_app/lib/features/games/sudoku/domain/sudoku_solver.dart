import 'dart:math';

import 'sudoku_geometry.dart';

/// How many search nodes a single call may spend before it gives up.
///
/// Every caller treats running out as "I could not prove this", never as an
/// answer, so a budget can only ever make a generated puzzle easier — it can
/// never let a broken one through. It is here because the largest boards are
/// generated while the player waits.
const int kSudokuSearchBudget = 200000;

/// Solves and counts solutions of a grid of any supported size.
///
/// A grid is row-major with 0 for an empty cell, and values are 1-based. The
/// candidates of a cell are held as a bitmask — bit `v - 1` for value `v` —
/// which keeps the whole working set to three small integer lists, and stays
/// inside the 32 bits a bitwise operation is good for on the web, since the
/// largest board has 25 values.
///
/// Instances carry scratch state, so one is not safe to share between two
/// searches at the same time; the generator keeps its own.
class SudokuSolver {
  SudokuSolver(this.geometry)
    : _length = geometry.length,
      _fullMask = geometry.fullMask,
      _rowMask = List<int>.filled(geometry.length, 0),
      _columnMask = List<int>.filled(geometry.length, 0),
      _boxMask = List<int>.filled(geometry.length, 0),
      _empties = List<int>.filled(geometry.cellCount, 0);

  final SudokuGeometry geometry;

  final int _length;
  final int _fullMask;
  final List<int> _rowMask;
  final List<int> _columnMask;
  final List<int> _boxMask;

  /// The cells still to be filled. The search swaps the one it is about to
  /// take to the end and shortens [_emptyCount], so a node only ever scans
  /// cells that are still open.
  final List<int> _empties;
  int _emptyCount = 0;

  int _steps = 0;
  int _budget = 0;
  bool _exhausted = false;

  /// Nodes spent since the last [resetSteps], so a caller running many
  /// searches can put a ceiling on the lot of them.
  int _spent = 0;

  List<int>? _firstSolution;
  Random? _random;

  /// Cells [isSolvableWithSingles] has left to fill, and whether it ran into a
  /// cell or a group with no possibility left.
  int _remaining = 0;
  bool _stuck = false;

  int get spentSteps => _spent;

  /// `true` when the last call ran out of budget, and so answered nothing.
  bool get exhausted => _exhausted;

  void resetSteps() => _spent = 0;

  /// The number of solutions of [grid], counted up to [limit].
  ///
  /// [grid] is left exactly as it was found.
  int countSolutions(
    List<int> grid, {
    int limit = 2,
    int budget = kSudokuSearchBudget,
  }) {
    _begin(budget);
    if (!_load(grid)) return 0;
    return _search(grid, limit);
  }

  /// One completion of [grid], or `null` when it has none (or when the search
  /// ran out of budget — see [exhausted]).
  ///
  /// Passing [shuffle] walks the candidates of a cell in a random order, which
  /// is what turns an empty grid into a random finished board.
  List<int>? findSolution(
    List<int> grid, {
    Random? shuffle,
    int budget = kSudokuSearchBudget,
  }) {
    _begin(budget);
    _random = shuffle;
    _firstSolution = null;
    if (_load(grid)) _search(grid, 1);
    final solution = _firstSolution;
    _firstSolution = null;
    _random = null;
    return solution;
  }

  /// The completion of [grid] that plain step-by-step reasoning reaches, or
  /// `null` when that reasoning does not get all the way there.
  ///
  /// It only ever writes a value that has no alternative — a cell with one
  /// candidate left, or a value with one cell left in its row, column or box —
  /// so a grid it completes has exactly one solution, and it is this one. That
  /// is the property the generator digs against, and it means a player can
  /// finish every puzzle without once having to try something out.
  ///
  /// [grid] itself is left as it was found.
  List<int>? solveWithSingles(List<int> grid) {
    if (!_load(grid)) return null;
    final work = List<int>.of(grid);
    _remaining = _emptyCount;
    _stuck = false;

    // Cheapest rule first, and the dearer one only once it stalls: scanning
    // every group costs several times a sweep over the cells, and on the larger
    // boards that difference is most of the generator's work.
    while (_remaining > 0) {
      if (_nakedSingles(work)) continue;
      if (_stuck) return null;
      if (!_hiddenSingles(work)) break;
      if (_stuck) return null;
    }

    return _remaining == 0 ? work : null;
  }

  /// Whether [grid] can be finished by [solveWithSingles].
  bool isSolvableWithSingles(List<int> grid) => solveWithSingles(grid) != null;

  /// Fills in every cell that has one candidate left, in one sweep. Returns
  /// whether anything was placed; sets [_stuck] when a cell has none left.
  bool _nakedSingles(List<int> work) {
    var placed = false;
    for (var index = 0; index < work.length; index++) {
      if (work[index] != 0) continue;
      final mask = _candidatesAt(index);
      if (mask == 0) {
        _stuck = true;
        return placed;
      }
      // More than one bit: nothing forced here yet.
      if (mask & (mask - 1) != 0) continue;
      _fill(work, index, _lowestValue(mask));
      placed = true;
    }
    return placed;
  }

  /// Fills in every value that only one cell of a row, column or box can still
  /// take. Each group is scanned once, collecting the candidates seen in it at
  /// all and those seen more than once — the difference is exactly the values
  /// with a single home left.
  bool _hiddenSingles(List<int> work) {
    var placed = false;

    for (final unit in geometry.units) {
      var taken = 0;
      var once = 0;
      var twice = 0;
      for (final index in unit) {
        final value = work[index];
        if (value != 0) {
          taken |= 1 << (value - 1);
          continue;
        }
        final mask = _candidatesAt(index);
        twice |= once & mask;
        once |= mask;
      }
      // A value still missing from this group with nowhere left to go in it is
      // a dead end.
      if (_fullMask & ~taken & ~once != 0) {
        _stuck = true;
        return placed;
      }

      var unique = once & ~twice;
      while (unique != 0) {
        final value = _lowestValue(unique);
        final bit = 1 << (value - 1);
        unique &= ~bit;
        for (final index in unit) {
          if (work[index] != 0) continue;
          if (_candidatesAt(index) & bit == 0) continue;
          _fill(work, index, value);
          placed = true;
          break;
        }
      }
    }
    return placed;
  }

  void _fill(List<int> work, int index, int value) {
    _place(index, value);
    work[index] = value;
    _remaining--;
  }

  void _begin(int budget) {
    _steps = 0;
    _budget = budget;
    _exhausted = false;
  }

  /// Rebuilds the masks and the list of empty cells from [grid]. Returns
  /// `false` when [grid] already breaks a rule, and so has no solutions.
  bool _load(List<int> grid) {
    for (var i = 0; i < _length; i++) {
      _rowMask[i] = 0;
      _columnMask[i] = 0;
      _boxMask[i] = 0;
    }
    _emptyCount = 0;

    for (var index = 0; index < grid.length; index++) {
      final value = grid[index];
      if (value == 0) {
        _empties[_emptyCount++] = index;
        continue;
      }
      final bit = 1 << (value - 1);
      final row = geometry.rowOf(index);
      final column = geometry.columnOf(index);
      final box = geometry.boxOf(index);
      if (_rowMask[row] & bit != 0 ||
          _columnMask[column] & bit != 0 ||
          _boxMask[box] & bit != 0) {
        return false;
      }
      _rowMask[row] |= bit;
      _columnMask[column] |= bit;
      _boxMask[box] |= bit;
    }
    return true;
  }

  int _candidatesAt(int index) =>
      _fullMask &
      ~(_rowMask[geometry.rowOf(index)] |
          _columnMask[geometry.columnOf(index)] |
          _boxMask[geometry.boxOf(index)]);

  void _place(int index, int value) {
    final bit = 1 << (value - 1);
    _rowMask[geometry.rowOf(index)] |= bit;
    _columnMask[geometry.columnOf(index)] |= bit;
    _boxMask[geometry.boxOf(index)] |= bit;
  }

  void _unplace(int index, int value) {
    final bit = ~(1 << (value - 1));
    _rowMask[geometry.rowOf(index)] &= bit;
    _columnMask[geometry.columnOf(index)] &= bit;
    _boxMask[geometry.boxOf(index)] &= bit;
  }

  /// Depth-first search that always takes the emptiest cell first, counting up
  /// to [limit] solutions. Fewest candidates first is what keeps the largest
  /// boards tractable: a forced cell is filled rather than guessed at, and a
  /// dead end is usually reached within a node or two.
  int _search(List<int> grid, int limit) {
    if (++_steps > _budget) {
      _exhausted = true;
      return 0;
    }
    _spent++;

    if (_emptyCount == 0) {
      _firstSolution ??= List<int>.of(grid);
      return 1;
    }

    var bestSlot = -1;
    var bestMask = 0;
    var bestCount = _length + 1;
    for (var slot = 0; slot < _emptyCount; slot++) {
      final mask = _candidatesAt(_empties[slot]);
      final count = _bitCount(mask);
      if (count == 0) return 0;
      if (count >= bestCount) continue;
      bestSlot = slot;
      bestMask = mask;
      bestCount = count;
      if (count == 1) break;
    }

    final index = _empties[bestSlot];
    _swapOut(bestSlot);

    var found = 0;
    final random = _random;
    if (random == null) {
      for (var value = 1; value <= _length; value++) {
        if (bestMask & (1 << (value - 1)) == 0) continue;
        found += _tryValue(grid, index, value, limit - found);
        if (found >= limit || _exhausted) break;
      }
    } else {
      for (final value in _valuesOf(bestMask)..shuffle(random)) {
        found += _tryValue(grid, index, value, limit - found);
        if (found >= limit || _exhausted) break;
      }
    }

    _swapIn(bestSlot);
    return found;
  }

  int _tryValue(List<int> grid, int index, int value, int limit) {
    _place(index, value);
    grid[index] = value;
    final found = _search(grid, limit);
    grid[index] = 0;
    _unplace(index, value);
    return found;
  }

  /// Takes the cell at [slot] out of the open set, parking it just past the
  /// end so that [_swapIn] can put everything back exactly as it was.
  void _swapOut(int slot) {
    _emptyCount--;
    final last = _empties[_emptyCount];
    _empties[_emptyCount] = _empties[slot];
    _empties[slot] = last;
  }

  void _swapIn(int slot) {
    final last = _empties[_emptyCount];
    _empties[_emptyCount] = _empties[slot];
    _empties[slot] = last;
    _emptyCount++;
  }

  List<int> _valuesOf(int mask) => [
    for (var value = 1; value <= _length; value++)
      if (mask & (1 << (value - 1)) != 0) value,
  ];

  int _lowestValue(int mask) {
    for (var value = 1; value <= _length; value++) {
      if (mask & (1 << (value - 1)) != 0) return value;
    }
    return 0;
  }

  int _bitCount(int mask) {
    var count = 0;
    var rest = mask;
    while (rest != 0) {
      rest &= rest - 1;
      count++;
    }
    return count;
  }
}
