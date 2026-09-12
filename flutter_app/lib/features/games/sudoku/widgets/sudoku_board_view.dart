import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/layout/responsive_scale.dart';
import '../domain/sudoku_geometry.dart';
import '../domain/sudoku_models.dart';
import '../state/sudoku_game_state.dart';
import 'sudoku_cell_view.dart';
import 'sudoku_palette.dart';

/// The largest a single cell is allowed to get, so that a 4×4 board on a desktop
/// stays a sudoku rather than four enormous tiles.
const double kSudokuMaxCellSize = 74;

/// The board: a square grid of cells with the box borders drawn over them.
class SudokuBoardView extends StatelessWidget {
  const SudokuBoardView({
    super.key,
    required this.game,
    required this.onCellTap,
    this.zoom = 1,
  });

  final SudokuGameState game;
  final ValueChanged<int> onCellTap;

  /// How much bigger than "fits the screen" to draw the board.
  ///
  /// This grows the cells themselves rather than scaling a picture of them, so
  /// zooming into a 25×25 board brings its pencil marks back rather than
  /// magnifying the dot that stands in for them. Whatever no longer fits is
  /// reached by dragging the board about.
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final palette = SudokuPalette.of(context);
    final geometry = game.geometry;
    final length = geometry.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = math.min(constraints.maxWidth, constraints.maxHeight);
        // Whole pixels per cell: it keeps the grid lines crisp, and it means the
        // cells can never add up to more than the room they were given.
        final fitted = math
            .min(available / length, context.rs(kSudokuMaxCellSize))
            .floorToDouble();
        final cellSize = math.max(1.0, (fitted * zoom).floorToDouble());
        final side = cellSize * length;

        final selected = game.selected;
        final selectedValue = game.selectedCell?.value ?? 0;

        final board = SizedBox(
          width: side,
          height: side,
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var row = 0; row < length; row++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var column = 0; column < length; column++)
                          _buildCell(
                            geometry: geometry,
                            palette: palette,
                            index: geometry.indexOf(row, column),
                            selected: selected,
                            selectedValue: selectedValue,
                            cellSize: cellSize,
                          ),
                      ],
                    ),
                ],
              ),
              // Painted over the cells in one go, so a shared border is one
              // line rather than two cells' worth of edges.
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _SudokuGridPainter(
                      geometry: geometry,
                      cellSize: cellSize,
                      line: palette.gridLine,
                      boxLine: palette.boxLine,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        // Only once it has been zoomed past what the screen holds does the
        // board need to be draggable; before that the scroll views would have
        // nowhere to go anyway.
        if (side <= constraints.maxWidth && side <= constraints.maxHeight) {
          return Center(child: board);
        }
        // A zoomed board is dragged about to reach the rest of it, and a mouse
        // has to be able to do that as well as a finger — Flutter leaves mice
        // out of dragging by default, on the grounds that a desktop has scroll
        // bars, which this has not.
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: PointerDeviceKind.values.toSet(),
            scrollbars: false,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: board,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCell({
    required SudokuGeometry geometry,
    required SudokuPalette palette,
    required int index,
    required int? selected,
    required int selectedValue,
    required double cellSize,
  }) {
    final cell = game.cells[index];
    final isSelected = index == selected;

    return SudokuCellView(
      cell: cell,
      size: cellSize,
      noteColumns: geometry.size.boxWidth,
      noteRows: geometry.size.boxHeight,
      symbolWidth: sudokuSymbolWidth(geometry.length),
      palette: palette,
      selected: isSelected,
      inSelectedUnit:
          selected != null &&
          !isSelected &&
          (geometry.rowOf(index) == geometry.rowOf(selected) ||
              geometry.columnOf(index) == geometry.columnOf(selected) ||
              geometry.boxOf(index) == geometry.boxOf(selected)),
      sameValue:
          !isSelected && selectedValue != 0 && cell.value == selectedValue,
      onTap: () => onCellTap(index),
    );
  }
}

/// Thin lines between cells, thicker ones between boxes, and a frame around the
/// lot.
class _SudokuGridPainter extends CustomPainter {
  const _SudokuGridPainter({
    required this.geometry,
    required this.cellSize,
    required this.line,
    required this.boxLine,
  });

  final SudokuGeometry geometry;
  final double cellSize;
  final Color line;
  final Color boxLine;

  @override
  void paint(Canvas canvas, Size size) {
    final length = geometry.length;
    // On a board with tiny cells a thick border would eat the cell itself, so
    // the lines thin out along with them.
    final thin = cellSize >= 26 ? 1.0 : 0.5;
    final thick = cellSize >= 26 ? 2.0 : 1.5;

    final thinPaint = Paint()
      ..color = line
      ..strokeWidth = thin;
    final thickPaint = Paint()
      ..color = boxLine
      ..strokeWidth = thick;

    for (var index = 0; index <= length; index++) {
      final isBoxRow = index % geometry.size.boxHeight == 0;
      final isBoxColumn = index % geometry.size.boxWidth == 0;
      final isEdge = index == 0 || index == length;

      // A stroke straddles the line it is drawn on, so the two outermost ones
      // are pulled inwards by half their width to keep the frame off the edge
      // of the canvas, where half of it would be clipped away.
      canvas.drawLine(
        Offset(0, _at(index, size.height, thick)),
        Offset(size.width, _at(index, size.height, thick)),
        isBoxRow || isEdge ? thickPaint : thinPaint,
      );
      canvas.drawLine(
        Offset(_at(index, size.width, thick), 0),
        Offset(_at(index, size.width, thick), size.height),
        isBoxColumn || isEdge ? thickPaint : thinPaint,
      );
    }
  }

  double _at(int index, double extent, double thick) {
    if (index == 0) return thick / 2;
    if (index == geometry.length) return extent - thick / 2;
    return index * cellSize;
  }

  @override
  bool shouldRepaint(_SudokuGridPainter old) =>
      old.geometry != geometry ||
      old.cellSize != cellSize ||
      old.line != line ||
      old.boxLine != boxLine;
}
