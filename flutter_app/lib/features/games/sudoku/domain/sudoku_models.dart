/// Board sizes the picker offers, each with the shape of its boxes.
///
/// A box is [boxHeight] rows by [boxWidth] columns, and their product is the
/// side [length] — that is what makes every value fit exactly once into each
/// row, column and box. Only the square sizes can have square boxes; 6×6 is
/// boxed 2×3 and 12×12 is boxed 3×4, as those puzzles conventionally are.
enum SudokuSize {
  four(4, 2, 2),
  six(6, 2, 3),
  nine(9, 3, 3),
  twelve(12, 3, 4),
  sixteen(16, 4, 4),
  twentyFive(25, 5, 5);

  const SudokuSize(this.length, this.boxHeight, this.boxWidth);

  /// Cells along one side of the board.
  final int length;

  final int boxHeight;
  final int boxWidth;

  int get cellCount => length * length;

  /// Boxes stacked vertically, i.e. the number of horizontal bands.
  int get bandCount => length ~/ boxHeight;

  /// Boxes side by side, i.e. the number of vertical stacks.
  int get stackCount => length ~/ boxWidth;

  /// The size a new player gets, and the one every classic sudoku is.
  static const SudokuSize initial = SudokuSize.nine;

  static SudokuSize fromLength(int length) => SudokuSize.values.firstWhere(
    (size) => size.length == length,
    orElse: () => SudokuSize.initial,
  );
}

/// What a cell shows for [value], which is 1-based as values are everywhere
/// here: the number itself, all the way up to 25.
///
/// Boards past nine values carry two-digit numbers rather than switching to
/// letters. Everything that draws a value — the cells, the pencil marks, the
/// keys — asks [sudokuSymbolWidth] how wide the widest one gets and sizes
/// itself to that, so the extra digit costs room rather than legibility.
String sudokuSymbol(int value) => '$value';

/// Characters the widest value of a board of [length] takes.
int sudokuSymbolWidth(int length) => length >= 10 ? 2 : 1;

/// The value [text] stands for, or `null` when it stands for nothing on a board
/// of [length] values.
int? sudokuValueOf(String text, int length) {
  final value = int.tryParse(text);
  if (value == null) return null;
  return value >= 1 && value <= length ? value : null;
}

/// The digit [character] is, or `null` when it is not a single digit.
///
/// Typing a value is done a digit at a time, so this is what a key press turns
/// into before the board works out which value the digits add up to.
int? sudokuDigitOf(String character) {
  if (character.length != 1) return null;
  final digit = character.codeUnitAt(0) - 0x30;
  return digit >= 0 && digit <= 9 ? digit : null;
}

/// How thoroughly a puzzle is dug out, and by what reasoning it can be solved.
///
/// [easy] boards never need more than a single cell looked at in isolation;
/// the other two are only ever guaranteed to have exactly one solution, and
/// leave more of the board empty as they get harder.
enum SudokuDifficulty { easy, medium, hard }

enum SudokuPhase {
  loading,
  playing,

  /// Every cell is filled in correctly.
  solved,

  /// The player gave up and the solution was written in.
  revealed,

  failed,
}

/// What the last check said about a cell. Cleared as soon as the cell changes,
/// so a mark never outlives the entry it was about.
enum SudokuMark { none, correct, wrong }

/// One cell of the board as the player left it.
class SudokuCell {
  const SudokuCell({
    this.value = 0,
    this.notes = const {},
    this.isGiven = false,
    this.isRevealed = false,
    this.mark = SudokuMark.none,
  });

  /// The value in the cell, or 0 when it is empty.
  final int value;

  /// Pencil marks, only ever shown while the cell itself is empty.
  final Set<int> notes;

  /// Part of the puzzle as it was dealt, so it cannot be changed.
  final bool isGiven;

  /// Filled in by "solve cell" rather than by the player. Locked like a given,
  /// but coloured apart so the player can see what they were handed.
  final bool isRevealed;

  final SudokuMark mark;

  /// Neither a given nor solved for the player, so it is theirs to change.
  bool get isEditable => !isGiven && !isRevealed;

  bool get isEmpty => value == 0;

  SudokuCell copyWith({
    int? value,
    Set<int>? notes,
    bool? isRevealed,
    SudokuMark? mark,
  }) {
    return SudokuCell(
      value: value ?? this.value,
      notes: notes ?? this.notes,
      isGiven: isGiven,
      isRevealed: isRevealed ?? this.isRevealed,
      mark: mark ?? this.mark,
    );
  }
}

/// A dealt puzzle: the cells the player starts with, and the grid they are a
/// part of.
class SudokuPuzzle {
  const SudokuPuzzle({
    required this.size,
    required this.difficulty,
    required this.givens,
    required this.solution,
  });

  SudokuPuzzle.empty()
    : size = SudokuSize.initial,
      difficulty = SudokuDifficulty.easy,
      givens = const [],
      solution = const [];

  final SudokuSize size;
  final SudokuDifficulty difficulty;

  /// Row-major, 0 where the player has to fill a value in.
  final List<int> givens;

  /// Row-major and complete: the one grid [givens] can be completed to.
  final List<int> solution;

  bool get isEmpty => givens.isEmpty;

  int get clueCount => givens.where((value) => value != 0).length;

  /// The cells the player has to fill in.
  int get holeCount => givens.length - clueCount;
}
