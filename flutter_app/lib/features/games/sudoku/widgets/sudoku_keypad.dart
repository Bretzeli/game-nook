import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/layout/responsive_scale.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../widgets/game_chip.dart';
import '../domain/sudoku_models.dart';
import 'sudoku_palette.dart';

/// How wide a digit is as a share of its font size, near enough for laying out
/// a number of them.
const double _kDigitAspect = 0.62;

/// The biggest and smallest a key may get. The upper bound keeps a 4×4 board
/// from handing out four enormous buttons; the lower one is about as small as a
/// key can be and still be hit with a thumb.
const double _kMaxKeySize = 64;
const double _kMinKeySize = 30;

/// The values, laid out as a pad rather than as a line.
///
/// The keys are arranged in the shape of the board's own box — three by three
/// for a classic sudoku, five by five for a 25×25 — which puts them within reach
/// of a thumb instead of strung out across the bottom of the screen, and puts
/// each value where the eye already expects it from the board.
class SudokuKeypad extends StatelessWidget {
  const SudokuKeypad({
    super.key,
    required this.size,
    required this.enabled,
    required this.notesMode,
    required this.remaining,
    required this.maxHeight,
    required this.onValue,
  });

  final SudokuSize size;

  final bool enabled;

  /// Keys write pencil marks rather than answers, and say so.
  final bool notesMode;

  /// Cells each value still has to go into, by value.
  final List<int> remaining;

  /// The most room the pad may take, so that it never crowds the board off the
  /// screen on the larger sizes.
  final double maxHeight;

  final ValueChanged<int> onValue;

  @override
  Widget build(BuildContext context) {
    final palette = SudokuPalette.of(context);
    final gap = context.rs(6);
    final columns = size.boxWidth;
    final rows = size.boxHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final byWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final byHeight = (maxHeight - gap * (rows - 1)) / rows;
        final keySize = math.max(
          _kMinKeySize,
          math.min(context.rs(_kMaxKeySize), math.min(byWidth, byHeight)),
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var row = 0; row < rows; row++) ...[
              if (row > 0) SizedBox(height: gap),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var column = 0; column < columns; column++) ...[
                    if (column > 0) SizedBox(width: gap),
                    _Key(
                      key: ValueKey('sudoku-key-${row * columns + column + 1}'),
                      value: row * columns + column + 1,
                      size: keySize,
                      symbolWidth: sudokuSymbolWidth(size.length),
                      palette: palette,
                      remaining: remaining[row * columns + column],
                      notesMode: notesMode,
                      enabled: enabled,
                      onTap: onValue,
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The switches that belong with the keys rather than with the board: whether a
/// key writes an answer or a pencil mark, the eraser, and how far the board is
/// zoomed in.
///
/// They sit between the board and the pad, which is the easiest place on a phone
/// to reach without letting go of it.
class SudokuPadActions extends StatelessWidget {
  const SudokuPadActions({
    super.key,
    required this.strings,
    required this.enabled,
    required this.notesMode,
    required this.onNotes,
    required this.onErase,
    required this.zoom,
    required this.canZoomIn,
    required this.canZoomOut,
    required this.onZoomIn,
    required this.onZoomOut,
    this.showZoom = false,
  });

  final AppStrings strings;
  final bool enabled;
  final bool notesMode;
  final VoidCallback onNotes;
  final VoidCallback onErase;

  final double zoom;
  final bool showZoom;
  final bool canZoomIn;
  final bool canZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: context.rs(8),
      runSpacing: context.rs(8),
      children: [
        Tooltip(
          message: strings.sudokuNotesHint,
          child: GameChip(
            key: const ValueKey('sudoku-notes'),
            icon: notesMode ? Icons.edit_note_rounded : Icons.edit_outlined,
            label: strings.sudokuNotes,
            active: notesMode,
            enabled: enabled,
            onTap: enabled ? onNotes : null,
          ),
        ),
        GameChip(
          key: const ValueKey('sudoku-erase'),
          icon: Icons.backspace_outlined,
          label: strings.sudokuErase,
          enabled: enabled,
          onTap: enabled ? onErase : null,
        ),
        if (showZoom)
          _ZoomControl(
            strings: strings,
            zoom: zoom,
            canZoomIn: canZoomIn,
            canZoomOut: canZoomOut,
            onZoomIn: onZoomIn,
            onZoomOut: onZoomOut,
          ),
      ],
    );
  }
}

/// A pill with the zoom either side of what it currently is.
class _ZoomControl extends StatelessWidget {
  const _ZoomControl({
    required this.strings,
    required this.zoom,
    required this.canZoomIn,
    required this.canZoomOut,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final AppStrings strings;
  final double zoom;
  final bool canZoomIn;
  final bool canZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rs(4),
        vertical: context.rs(2),
      ),
      decoration: BoxDecoration(
        color: decor.cardColor.withValues(alpha: 0.5),
        borderRadius: decor.buttonRadius,
        border: Border.all(color: decor.subtleNavBorder, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomButton(
            buttonKey: const ValueKey('sudoku-zoom-out'),
            icon: Icons.remove_rounded,
            tooltip: strings.sudokuZoomOut,
            enabled: canZoomOut,
            onTap: onZoomOut,
          ),
          SizedBox(
            width: context.rs(46),
            child: Text(
              strings.sudokuZoomLevel(zoom),
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: zoom > 1 ? decor.accentColor : decor.subtleTextColor,
              ),
            ),
          ),
          _ZoomButton(
            buttonKey: const ValueKey('sudoku-zoom-in'),
            icon: Icons.add_rounded,
            tooltip: strings.sudokuZoomIn,
            enabled: canZoomIn,
            onTap: onZoomIn,
          ),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final button = Padding(
      key: buttonKey,
      padding: EdgeInsets.all(context.rs(6)),
      child: Icon(
        icon,
        size: context.rs(17),
        color: enabled
            ? decor.subtleTextColor
            : decor.subtleTextColor.withValues(alpha: 0.35),
      ),
    );

    if (!enabled) return button;
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: button,
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    super.key,
    required this.value,
    required this.size,
    required this.symbolWidth,
    required this.palette,
    required this.remaining,
    required this.notesMode,
    required this.enabled,
    required this.onTap,
  });

  final int value;
  final double size;

  /// Characters the widest value of this board takes, so that every key wears
  /// its number at the same size.
  final int symbolWidth;

  final SudokuPalette palette;
  final int remaining;
  final bool notesMode;
  final bool enabled;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    // A value that is already everywhere it goes has nothing left to do, but it
    // stays tappable: it may well be somewhere it does not belong.
    final done = remaining <= 0;
    final foreground = !enabled || done
        ? palette.keyDoneText
        : notesMode
        ? palette.noteText
        : palette.keyText;

    // Pencil marks are written smaller than answers, and so is the key that
    // writes them.
    final fontSize = math.min(
      size * (notesMode ? 0.38 : 0.46),
      size * 0.8 / (symbolWidth * _kDigitAspect),
    );

    final key = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.keyBackground.withValues(alpha: enabled ? 1 : 0.5),
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(
          color: notesMode && enabled
              ? decor.accentColor.withValues(alpha: 0.5)
              : decor.cardBorderColor.withValues(alpha: 0.6),
          width: notesMode && enabled ? 1 : 0.5,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              sudokuSymbol(value),
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: fontSize,
                height: 1,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
          if (remaining > 0 && size >= 38)
            Positioned(
              right: size * 0.08,
              bottom: size * 0.04,
              child: Text(
                '$remaining',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: size * 0.18,
                  height: 1,
                  color: palette.keyDoneText,
                ),
              ),
            ),
        ],
      ),
    );

    if (!enabled) return Opacity(opacity: 0.6, child: key);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(value),
        child: key,
      ),
    );
  }
}
