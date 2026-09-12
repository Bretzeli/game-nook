import '../domain/sudoku_geometry.dart';
import '../domain/sudoku_models.dart';

/// What a check had to say about the cells it looked at.
class SudokuCheckResult {
  const SudokuCheckResult({required this.checked, required this.wrong});

  const SudokuCheckResult.none() : checked = 0, wrong = 0;

  /// Filled cells the check covered — givens and solved cells are not among
  /// them, since there is nothing to be right or wrong about there.
  final int checked;

  final int wrong;

  bool get isEmpty => checked == 0;

  bool get allCorrect => checked > 0 && wrong == 0;
}

class SudokuGameState {
  const SudokuGameState({
    required this.phase,
    required this.puzzle,
    required this.cells,
    required this.selected,
    required this.hintsUsed,
    required this.round,
  });

  SudokuGameState.loading()
    : phase = SudokuPhase.loading,
      puzzle = SudokuPuzzle.empty(),
      cells = const [],
      selected = null,
      hintsUsed = 0,
      round = 0;

  final SudokuPhase phase;
  final SudokuPuzzle puzzle;

  /// The board as the player left it, row-major and the same length as the
  /// puzzle it came from.
  final List<SudokuCell> cells;

  /// The cell the keypad and every single-cell action work on, or `null` when
  /// nothing is picked out.
  final int? selected;

  /// How many cells were handed to the player by "solve cell".
  final int hintsUsed;

  /// Bumped for every puzzle dealt, so the board can reset its animations.
  final int round;

  SudokuSize get size => puzzle.size;

  SudokuGeometry get geometry => SudokuGeometry.of(puzzle.size);

  int get length => puzzle.size.length;

  bool get isPlaying => phase == SudokuPhase.playing;

  bool get isSolved => phase == SudokuPhase.solved;

  bool get isRevealed => phase == SudokuPhase.revealed;

  bool get isFinished => isSolved || isRevealed;

  SudokuCell? get selectedCell {
    final index = selected;
    return index == null ? null : cells[index];
  }

  /// Cells still waiting for a value.
  int get emptyCount => cells.where((cell) => cell.isEmpty).length;

  int get wrongCount =>
      cells.where((cell) => cell.mark == SudokuMark.wrong).length;

  bool get hasMarks => cells.any((cell) => cell.mark != SudokuMark.none);

  /// How many cells [value] still has to go into. A value that has run out is
  /// worth greying out on the keypad.
  int remainingOf(int value) {
    var placed = 0;
    for (final cell in cells) {
      if (cell.value == value) placed++;
    }
    return length - placed;
  }

  /// Every cell holds the value the solution has there.
  bool get isComplete {
    if (puzzle.isEmpty) return false;
    for (var index = 0; index < cells.length; index++) {
      if (cells[index].value != puzzle.solution[index]) return false;
    }
    return true;
  }

  /// There is something the player filled in for a check to have an opinion
  /// about.
  bool get canCheckAll =>
      isPlaying && cells.any((cell) => cell.isEditable && !cell.isEmpty);

  bool get canCheckSelected {
    final cell = selectedCell;
    return isPlaying && cell != null && cell.isEditable && !cell.isEmpty;
  }

  /// A cell can be solved for the player as long as it is not already right.
  bool get canRevealSelected {
    final index = selected;
    if (!isPlaying || index == null) return false;
    final cell = cells[index];
    return cell.isEditable && cell.value != puzzle.solution[index];
  }

  bool get canGiveUp => isPlaying && !puzzle.isEmpty;

  SudokuGameState copyWith({
    SudokuPhase? phase,
    List<SudokuCell>? cells,
    int? selected,
    bool clearSelection = false,
    int? hintsUsed,
  }) {
    return SudokuGameState(
      phase: phase ?? this.phase,
      puzzle: puzzle,
      cells: cells ?? this.cells,
      selected: clearSelection ? null : (selected ?? this.selected),
      hintsUsed: hintsUsed ?? this.hintsUsed,
      round: round,
    );
  }
}
