import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/layout/responsive_scale.dart';
import '../domain/wordle_models.dart';
import '../state/wordle_game_state.dart';
import 'wordle_palette.dart';
import 'wordle_tile.dart';

/// Time a single tile takes to turn over, and the offset between neighbours.
const Duration kTileFlipDuration = Duration(milliseconds: 420);
const Duration kTileFlipStagger = Duration(milliseconds: 190);

Duration revealDurationFor(int columns) =>
    kTileFlipDuration + kTileFlipStagger * (columns - 1);

class WordleGrid extends StatelessWidget {
  const WordleGrid({
    super.key,
    required this.game,
    required this.revealedRows,
    required this.revealProgress,
    required this.shakeToken,
    required this.onSlotTap,
  });

  final WordleGameState game;

  /// How many rows are already fully scored; a row beyond that is the one
  /// currently flipping.
  final int revealedRows;

  /// Progress of the flip for row [revealedRows], `null` when nothing flips.
  final Animation<double>? revealProgress;

  /// Changes whenever a guess is rejected, to replay the nudge.
  final int shakeToken;

  final ValueChanged<int> onSlotTap;

  @override
  Widget build(BuildContext context) {
    final palette = WordlePalette.of(context);
    final columns = game.wordLength;
    final rows = math.max(kWordleMaxAttempts, game.rows.length);

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = math.max(4.0, constraints.maxWidth * 0.012);
        final byWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
        // A hair of slack keeps sub-pixel rounding from ever pushing the
        // column's total height past what the parent actually granted.
        final byHeight =
            (constraints.maxHeight - gap * (rows - 1) - 0.5) / rows;
        final fit = math.min(byWidth, byHeight);
        final maxSize = context.rs(72);
        // Below the usual minimum there is no slack left to spare, so tiles
        // shrink instead of being forced to a size that would overflow.
        final size = fit >= 16.0 ? math.min(fit, maxSize) : math.max(0.0, fit);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var row = 0; row < rows; row++) ...[
              if (row > 0) SizedBox(height: gap),
              _buildRow(context, palette, row, size, gap),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRow(
    BuildContext context,
    WordlePalette palette,
    int row,
    double size,
    double gap,
  ) {
    final columns = game.wordLength;
    final isRevealed = row < revealedRows;
    final isRevealing = row == revealedRows && revealProgress != null;
    final isInput = !isRevealed && !isRevealing && row == game.rows.length;
    final data = row < game.rows.length ? game.rows[row] : null;

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
            selected: isInput && game.isPlaying && column == game.cursor,
            onTap: isInput ? () => onSlotTap(column) : null,
          ),
        ],
      ],
    );

    // The winning row takes a bow once it has finished flipping.
    if (isRevealed &&
        game.phase == WordlePhase.won &&
        row == game.rows.length - 1) {
      rowWidget = rowWidget
          .animate(key: ValueKey('win-${game.round}'))
          .slideY(
            begin: 0,
            end: -0.14,
            duration: 260.ms,
            curve: Curves.easeOutBack,
          )
          .then()
          .slideY(begin: -0.14, end: 0, duration: 320.ms, curve: Curves.easeOut)
          .shimmer(
            delay: 60.ms,
            duration: 900.ms,
            color: Colors.white.withValues(alpha: 0.45),
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
    if (isInput && column < game.input.length) return game.input[column];
    return '';
  }

  /// The row-wide progress is sliced up so the tiles turn one after another.
  double _flipStart(int column) =>
      (kTileFlipStagger.inMilliseconds * column) /
      revealDurationFor(game.wordLength).inMilliseconds;

  double _flipEnd(int column) => math.min(
    _flipStart(column) +
        kTileFlipDuration.inMilliseconds /
            revealDurationFor(game.wordLength).inMilliseconds,
    1,
  );
}
