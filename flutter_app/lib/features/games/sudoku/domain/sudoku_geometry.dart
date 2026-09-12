import 'sudoku_models.dart';

/// Row, column and box arithmetic for one board size.
///
/// None of it depends on a particular puzzle, so instances are shared: the
/// solver, the generator and the board all ask [SudokuGeometry.of] for the same
/// one rather than each working the indices out again.
class SudokuGeometry {
  SudokuGeometry._(this.size, this._boxOf, this.units);

  factory SudokuGeometry.of(SudokuSize size) =>
      _cache.putIfAbsent(size, () => _build(size));

  static final Map<SudokuSize, SudokuGeometry> _cache = {};

  final SudokuSize size;

  final List<int> _boxOf;

  /// Every row, then every column, then every box, as lists of cell indices.
  /// These are the groups a value may appear in only once.
  final List<List<int>> units;

  /// Peers of a cell — the cells it shares a row, column or box with — filled
  /// in on first use, since only the board and the note pruning need them.
  final List<List<int>?> _peers = [];

  int get length => size.length;

  int get cellCount => size.cellCount;

  /// Every value as bits 0..length-1, i.e. the candidates of an empty cell on
  /// an empty board. Twenty-five bits at most, which keeps the masks inside
  /// what a bitwise operation gives us on the web as well.
  int get fullMask => (1 << length) - 1;

  int rowOf(int index) => index ~/ length;

  int columnOf(int index) => index % length;

  int boxOf(int index) => _boxOf[index];

  int indexOf(int row, int column) => row * length + column;

  /// `true` when [index] sits on the far side of a box border from the cell
  /// above it — where the board draws a thick line.
  bool startsBand(int index) => rowOf(index) % size.boxHeight == 0;

  /// The same for the cell to its left.
  bool startsStack(int index) => columnOf(index) % size.boxWidth == 0;

  List<int> peersOf(int index) {
    if (_peers.isEmpty) _peers.addAll(List<List<int>?>.filled(cellCount, null));
    return _peers[index] ??= _buildPeers(index);
  }

  List<int> _buildPeers(int index) {
    final row = rowOf(index);
    final column = columnOf(index);
    final box = boxOf(index);
    final peers = <int>[];

    for (var other = 0; other < cellCount; other++) {
      if (other == index) continue;
      if (rowOf(other) == row ||
          columnOf(other) == column ||
          boxOf(other) == box) {
        peers.add(other);
      }
    }
    return peers;
  }

  static SudokuGeometry _build(SudokuSize size) {
    final length = size.length;
    final boxOf = List<int>.filled(size.cellCount, 0);

    for (var index = 0; index < size.cellCount; index++) {
      final row = index ~/ length;
      final column = index % length;
      boxOf[index] =
          (row ~/ size.boxHeight) * size.stackCount + column ~/ size.boxWidth;
    }

    final rows = [
      for (var row = 0; row < length; row++)
        [for (var column = 0; column < length; column++) row * length + column],
    ];
    final columns = [
      for (var column = 0; column < length; column++)
        [for (var row = 0; row < length; row++) row * length + column],
    ];
    final boxes = [
      for (var box = 0; box < length; box++) <int>[],
    ];
    for (var index = 0; index < size.cellCount; index++) {
      boxes[boxOf[index]].add(index);
    }

    return SudokuGeometry._(size, boxOf, [...rows, ...columns, ...boxes]);
  }
}
