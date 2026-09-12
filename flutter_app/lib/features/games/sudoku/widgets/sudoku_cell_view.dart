import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/sudoku_models.dart';
import 'sudoku_palette.dart';

/// Below this, a pencil mark would be too small to read, and the cell shows a
/// dot to say that there are notes in it instead.
const double _kMinNoteFontSize = 5.0;

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
          fontSize: extent * 0.62,
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
    if (math.min(noteWidth, noteHeight) * 0.72 < _kMinNoteFontSize) {
      // No room to read them: say that they are there and leave it at that.
      return Icon(
        Icons.circle,
        size: math.max(2.0, math.min(extent * 0.18, 6.0)),
        color: palette.noteText,
      );
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
                  child: _note(
                    row * noteColumns + column + 1,
                    math.min(noteWidth, noteHeight),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _note(int value, double noteSize) {
    if (!cell.notes.contains(value)) return const SizedBox.shrink();

    return Center(
      child: Text(
        sudokuSymbol(value),
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontSize: noteSize * 0.72,
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
