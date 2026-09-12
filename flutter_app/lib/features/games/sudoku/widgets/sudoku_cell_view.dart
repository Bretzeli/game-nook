import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../domain/sudoku_models.dart';
import 'sudoku_palette.dart';

/// Below this a pencil mark is a smudge rather than a number, and the cell
/// marks where its notes are instead of saying what they are.
const double _kMinNoteFontSize = 4.5;

/// And below this there is no room even for that, leaving a single dot to say
/// that the cell is not as empty as it looks.
const double _kMinNoteSlotSize = 2.2;

/// How wide a digit is as a share of its font size, near enough for laying out
/// a number of them.
const double _kDigitAspect = 0.62;

/// The largest type that fits [characters] characters into a box, which on the
/// wider boards is what keeps a two-digit value inside its cell.
double _fitFontSize(double width, double height, int characters) {
  return math.min(height * 0.62, width * 0.86 / (characters * _kDigitAspect));
}

/// The same, for a pencil mark.
///
/// A value sits alone in the middle of a cell and can afford the room it leaves
/// around itself; a mark shares its cell with up to twenty-four others and
/// cannot. Digits have no descenders, so a mark can take nearly the whole height
/// of its slot and still keep a gap to the row below.
double _fitNoteFontSize(double width, double height, int characters) {
  return math.min(height * 0.9, width * 0.95 / (characters * _kDigitAspect));
}

/// One cell of the board.
///
/// Deliberately plain: on a 25×25 board there are 625 of these, so there is no
/// implicit animation and no controller here — what changes, changes at once.
class SudokuCellView extends StatelessWidget {
  const SudokuCellView({
    super.key,
    required this.cell,
    required this.size,
    required this.noteColumns,
    required this.noteRows,
    required this.symbolWidth,
    required this.palette,
    required this.selected,
    required this.inSelectedUnit,
    required this.sameValue,
    this.onTap,
  });

  final SudokuCell cell;

  /// Side of the cell in logical pixels.
  final double size;

  /// How the pencil marks are laid out — the shape of a box, which is what puts
  /// every value in the same place in every cell.
  final int noteColumns;
  final int noteRows;

  /// Characters the widest value of this board takes. Every cell sizes its type
  /// to that rather than to its own value, so a 5 and a 25 sit at the same size.
  final int symbolWidth;

  final SudokuPalette palette;

  final bool selected;

  /// Shares a row, column or box with the selected cell.
  final bool inSelectedUnit;

  /// Holds the same value as the selected cell.
  final bool sameValue;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // The border is always there and only changes colour, so that what is drawn
    // inside the cell has the same room whether it is selected or not — and it
    // thins out on a board whose cells are small enough for two pixels a side to
    // be worth having back.
    final border = size >= 26 ? 2.0 : 1.0;
    final inner = math.max(0.0, size - border * 2);

    final content = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _background(),
        border: Border.all(
          color: selected ? palette.selectedBorder : Colors.transparent,
          width: border,
        ),
      ),
      child: _child(inner),
    );

    if (onTap == null) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }

  /// The tints stack rather than replace, so a given that happens to be in the
  /// selected row still reads as both.
  Color _background() {
    var background = cell.isGiven
        ? palette.givenBackground
        : palette.cellBackground;

    Color tint(Color colour) => Color.alphaBlend(colour, background);

    return switch (cell.mark) {
      SudokuMark.wrong => tint(palette.wrong.withValues(alpha: 0.26)),
      SudokuMark.correct => tint(palette.correct.withValues(alpha: 0.24)),
      SudokuMark.none when selected => tint(palette.selectedBackground),
      SudokuMark.none when sameValue => tint(palette.matchBackground),
      SudokuMark.none when inSelectedUnit => tint(palette.peerBackground),
      SudokuMark.none => background,
    };
  }

  /// [extent] is the room inside the border, which is what everything here has
  /// to fit into.
  Widget _child(double extent) {
    if (!cell.isEmpty) {
      return Text(
        sudokuSymbol(cell.value),
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontSize: _fitFontSize(extent, extent, symbolWidth),
          // A given is the frame of the puzzle and a filled-in answer is the
          // player's own work, so the two differ in weight as well as colour.
          fontWeight: cell.isGiven ? FontWeight.w700 : FontWeight.w500,
          height: 1,
          color: _valueColor(),
        ),
      );
    }
    if (cell.notes.isEmpty) return const SizedBox.shrink();

    final noteWidth = extent / noteColumns;
    final noteHeight = extent / noteRows;
    final noteFontSize = _fitNoteFontSize(noteWidth, noteHeight, symbolWidth);

    if (noteFontSize < _kMinNoteFontSize) {
      return _dots(extent, noteWidth, noteHeight);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < noteRows; row++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var column = 0; column < noteColumns; column++)
                SizedBox(
                  width: noteWidth,
                  height: noteHeight,
                  child: _note(row * noteColumns + column + 1, noteFontSize),
                ),
            ],
          ),
      ],
    );
  }

  /// Notes on a board too tight to write them out.
  ///
  /// Each mark keeps the place it would have had, so the cell still says which
  /// values are pencilled in even where it cannot say it in figures — and the
  /// same mark is in the same corner of every cell, which is what makes them
  /// comparable at a glance. Zooming in turns them back into numbers.
  Widget _dots(double extent, double noteWidth, double noteHeight) {
    final slot = math.min(noteWidth, noteHeight);
    if (slot < _kMinNoteSlotSize) {
      // Not even room for that: one dot, to say the cell has notes at all.
      return Icon(
        Icons.circle,
        size: math.max(2.0, math.min(extent * 0.18, 6.0)),
        color: palette.noteText,
      );
    }

    return SizedBox(
      width: extent,
      height: extent,
      child: CustomPaint(
        painter: _SudokuNoteDotsPainter(
          notes: cell.notes,
          columns: noteColumns,
          rows: noteRows,
          radius: slot * 0.3,
          color: palette.noteText,
        ),
      ),
    );
  }

  Widget _note(int value, double fontSize) {
    if (!cell.notes.contains(value)) return const SizedBox.shrink();

    return Center(
      child: Text(
        sudokuSymbol(value),
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontSize: fontSize,
          height: 1,
          fontWeight: FontWeight.w500,
          color: palette.noteText,
        ),
      ),
    );
  }

  Color _valueColor() => switch (cell.mark) {
    SudokuMark.wrong => palette.wrong,
    SudokuMark.correct => palette.correct,
    SudokuMark.none when cell.isGiven => palette.givenText,
    SudokuMark.none when cell.isRevealed => palette.revealedText,
    SudokuMark.none => palette.entryText,
  };
}

/// A dot for each pencil mark, in the place that mark's number would have held.
///
/// Painted rather than laid out: a 25×25 board that has been pencilled over is
/// a few hundred of these, and none of them is worth a widget.
class _SudokuNoteDotsPainter extends CustomPainter {
  const _SudokuNoteDotsPainter({
    required this.notes,
    required this.columns,
    required this.rows,
    required this.radius,
    required this.color,
  });

  final Set<int> notes;
  final int columns;
  final int rows;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final slotWidth = size.width / columns;
    final slotHeight = size.height / rows;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;

    for (final value in notes) {
      final slot = value - 1;
      canvas.drawCircle(
        Offset(
          (slot % columns + 0.5) * slotWidth,
          (slot ~/ columns + 0.5) * slotHeight,
        ),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SudokuNoteDotsPainter old) =>
      old.columns != columns ||
      old.rows != rows ||
      old.radius != radius ||
      old.color != color ||
      !setEquals(old.notes, notes);
}
