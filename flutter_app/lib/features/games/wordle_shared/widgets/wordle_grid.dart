import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/layout/responsive_scale.dart';
import '../domain/wordle_board.dart';
import '../domain/wordle_models.dart';
import 'wordle_palette.dart';
import 'wordle_tile.dart';

/// Time a single tile takes to turn over, and the offset between neighbours.
const Duration kTileFlipDuration = Duration(milliseconds: 420);
const Duration kTileFlipStagger = Duration(milliseconds: 190);

Duration revealDurationFor(int columns) =>
    kTileFlipDuration + kTileFlipStagger * (columns - 1);

/// How long the board takes to make room for rows added to a running round.
const Duration kRowsResizeDuration = Duration(milliseconds: 520);

/// The widest a gap between tiles may get, as a share of the tile size.
const double _kMaxGapShare = 0.15;

class WordleGrid extends StatelessWidget {
  const WordleGrid({
    super.key,
    required this.board,
    required this.rowCount,
    required this.acceptsInput,
    required this.revealedRows,
    required this.revealProgress,
    required this.shakeToken,
    required this.onSlotTap,
    this.celebrateLastRow = false,
    this.accentRowsFrom,
  });

  final WordleBoard board;

  /// Rows the board is laid out for. It still grows when more rows than that
  /// have been revealed.
  final int rowCount;

  /// Whether the typing row shows its caret.
  final bool acceptsInput;

  /// How many rows are already fully scored; a row beyond that is the one
  /// currently flipping.
  final int revealedRows;

  /// Progress of the flip for row [revealedRows], `null` when nothing flips.
  final Animation<double>? revealProgress;

  /// Changes whenever a guess is rejected, to replay the nudge.
  final int shakeToken;

  final ValueChanged<int> onSlotTap;

  /// Lets the last row take a bow once it has turned over — for a win.
  final bool celebrateLastRow;

  /// Rows from this index on form a section of their own: set apart from the
  /// rows above and outlined in the "correct" colour while still empty.
  final int? accentRowsFrom;

  @override
  Widget build(BuildContext context) {
    final rows = math.max(rowCount, board.rows.length);

    // Rows that join a round in progress make room for themselves instead of
    // popping in; a new round simply starts out at its own size.
    return TweenAnimationBuilder<double>(
      key: ValueKey(board.round),
      tween: Tween<double>(end: rows.toDouble()),
      duration: kRowsResizeDuration,
      curve: Curves.easeInOutCubic,
      builder: (context, rowUnits, _) => LayoutBuilder(
        builder: (context, constraints) =>
            _buildRows(context, constraints, rowUnits),
      ),
    );
  }

  /// Lays out [rowUnits] rows, where a fraction is a row still arriving.
  Widget _buildRows(
    BuildContext context,
    BoxConstraints constraints,
    double rowUnits,
  ) {
    final palette = WordlePalette.of(context);
    final columns = board.wordLength;
    final rowsShown = rowUnits.ceil();
    // How much of a row is there: all of it, or the part that has arrived.
    double shareOf(int row) => (rowUnits - row).clamp(0.0, 1.0);

    final sectionStart = accentRowsFrom;
    final hasSection =
        sectionStart != null && sectionStart > 0 && sectionStart < rowsShown;
    // Gaps from the top row to the bottom one; the break before the accent
    // section adds three more.
    final gapsDown =
        math.max(0.0, rowUnits - 1) +
        (hasSection ? 3 * shareOf(sectionStart) : 0.0);

    double fitFor(double gap) {
      final byWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
      // A couple of pixels of slack keep sub-pixel rounding — and the odd
      // bit of padding an effect like shimmer() adds to a single row —
      // from ever pushing the column's total height past what the parent
      // actually granted.
      final byHeight =
          (constraints.maxHeight - gap * gapsDown - 2.0) / rowUnits;
      return math.min(byWidth, byHeight);
    }

    var gap = math.max(4.0, constraints.maxWidth * 0.012);
    var fit = fitFor(gap);
    // Gaps follow the width, so on a wide but short screen they would eat the
    // height the tiles need. There the gap is tied to the tile instead,
    // solving size = (height - share * size * gaps) / rows.
    if (gap > fit * _kMaxGapShare) {
      final size =
          (constraints.maxHeight - 2.0) /
          (rowUnits + _kMaxGapShare * gapsDown);
      gap = math.max(4.0, size * _kMaxGapShare);
      fit = fitFor(gap);
    }
    final maxSize = context.rs(72);
    // Below the usual minimum there is no slack left to spare, so tiles
    // shrink instead of being forced to a size that would overflow.
    final size = fit >= 16.0 ? math.min(fit, maxSize) : math.max(0.0, fit);
    final rowWidth = size * columns + gap * (columns - 1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < rowsShown; row++) ...[
          if (hasSection && row == sectionStart)
            _arriving(
              shareOf(row),
              _SectionBreak(
                height: gap * 4,
                width: rowWidth,
                color: palette.correct,
              ),
            )
          else if (row > 0)
            SizedBox(height: gap * shareOf(row)),
          _arriving(
            shareOf(row),
            _buildRow(context, palette, row, size, gap),
          ),
        ],
      ],
    );
  }

  /// [child] at [share] of its height and opacity, growing in from the top.
  Widget _arriving(double share, Widget child) {
    if (share >= 1) return child;
    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: share,
        child: Opacity(opacity: share, child: child),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    WordlePalette palette,
    int row,
    double size,
    double gap,
  ) {
    final columns = board.wordLength;
    final isRevealed = row < revealedRows;
    final isRevealing = row == revealedRows && revealProgress != null;
    final isInput = !isRevealed && !isRevealing && row == board.rows.length;
    final data = row < board.rows.length ? board.rows[row] : null;
    final isAccent = accentRowsFrom != null && row >= accentRowsFrom!;

    Widget rowWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var column = 0; column < columns; column++) ...[
          if (column > 0) SizedBox(width: gap),
          WordleTile(
            letter: _letterAt(row, column, isInput: isInput, data: data),
            size: size,
            palette: palette,
            status: (isRevealed || isRevealing) ? data?.statuses[column] : null,
            isSolution: data?.isSolution ?? false,
            flip: isRevealing ? revealProgress : null,
            flipStart: _flipStart(column),
            flipEnd: _flipEnd(column),
            selected: isInput && acceptsInput && column == board.cursor,
            emptyBorderColor: isAccent
                ? palette.correct.withValues(alpha: 0.55)
                : null,
            onTap: isInput ? () => onSlotTap(column) : null,
          ),
        ],
      ],
    );

    // The winning row takes a bow once it has finished flipping.
    //
    // The two slides stack as nested transforms and each one holds its end
    // value once its own window is over, so they have to sum to zero for the
    // row to come to rest in place: the second lowers by exactly what the
    // first lifted (-0.14 + 0.14) instead of animating "back to zero", which
    // would leave the first effect's lift applied for good.
    if (isRevealed && celebrateLastRow && row == board.rows.length - 1) {
      rowWidget = rowWidget
          .animate(key: ValueKey('win-${board.round}'))
          .slideY(
            begin: 0,
            end: -0.14,
            duration: 260.ms,
            curve: Curves.easeOutBack,
          )
          .then()
          .slideY(begin: 0, end: 0.14, duration: 320.ms, curve: Curves.easeOut)
          .shimmer(
            delay: 60.ms,
            duration: 900.ms,
            color: Colors.white.withValues(alpha: 0.45),
            // shimmer() pads its target by 0.5px on every side by default (to
            // smooth its ShaderMask edges), which is just enough extra height
            // on this row to overflow the board's tightly fitted Column.
            padding: 0,
          );
    }

    if (isInput && shakeToken > 0) {
      rowWidget = rowWidget
          .animate(key: ValueKey('shake-$shakeToken'))
          .shakeX(duration: 380.ms, hz: 6, amount: 5);
    }

    return rowWidget;
  }

  String _letterAt(
    int row,
    int column, {
    required bool isInput,
    required WordleRow? data,
  }) {
    if (data != null) return data.word[column];
    if (isInput && column < board.input.length) return board.input[column];
    return '';
  }

  /// The row-wide progress is sliced up so the tiles turn one after another.
  double _flipStart(int column) =>
      (kTileFlipStagger.inMilliseconds * column) /
      revealDurationFor(board.wordLength).inMilliseconds;

  double _flipEnd(int column) => math.min(
    _flipStart(column) +
        kTileFlipDuration.inMilliseconds /
            revealDurationFor(board.wordLength).inMilliseconds,
    1,
  );
}

/// The gap in front of the accent section, marked with a short rule so it
/// reads as intended rather than as a stray bit of spacing.
class _SectionBreak extends StatelessWidget {
  const _SectionBreak({
    required this.height,
    required this.width,
    required this.color,
  });

  final double height;
  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Container(
          width: math.min(width * 0.3, 96),
          height: 2,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}
