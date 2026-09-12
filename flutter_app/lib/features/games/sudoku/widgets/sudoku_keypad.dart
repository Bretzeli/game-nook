import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/layout/responsive_scale.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../domain/sudoku_models.dart';
import 'sudoku_palette.dart';

/// One key per value, plus the eraser.
///
/// A 25×25 board needs twenty-six keys, so they are sized to the room there is
/// and wrapped over as many rows as that takes, with the rows kept even.
class SudokuKeypad extends StatelessWidget {
  const SudokuKeypad({
    super.key,
    required this.strings,
    required this.length,
    required this.enabled,
    required this.notesMode,
    required this.remaining,
    required this.onValue,
    required this.onErase,
  });

  final AppStrings strings;

  /// How many values the board has, which is also its side.
  final int length;

  final bool enabled;

  /// Keys write pencil marks rather than answers, and say so.
  final bool notesMode;

  /// Cells each value still has to go into, by value.
  final List<int> remaining;

  final ValueChanged<int> onValue;
  final VoidCallback onErase;

  @override
  Widget build(BuildContext context) {
    final palette = SudokuPalette.of(context);
    final gap = context.rs(6);

    return LayoutBuilder(
      builder: (context, constraints) {
        final keys = length + 1;
        final minKey = context.rs(28);
        final maxKey = context.rs(50);

        final perRow = math.max(
          1,
          ((constraints.maxWidth + gap) / (minKey + gap)).floor(),
        );
        // Spread the keys over the rows they need rather than filling the first
        // row and leaving a stub: 26 keys read better as two rows of thirteen.
        final rows = (keys / math.min(keys, perRow)).ceil();
        final columns = (keys / rows).ceil();
        final keySize = math.min(
          maxKey,
          (constraints.maxWidth - gap * (columns - 1)) / columns,
        );

        return Wrap(
          alignment: WrapAlignment.center,
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var value = 1; value <= length; value++)
              _Key(
                key: ValueKey('sudoku-key-$value'),
                label: sudokuSymbol(value),
                size: keySize,
                palette: palette,
                remaining: remaining[value - 1],
                notesMode: notesMode,
                enabled: enabled,
                onTap: () => onValue(value),
              ),
            _Key(
              key: const ValueKey('sudoku-erase'),
              icon: Icons.backspace_outlined,
              tooltip: strings.sudokuErase,
              size: keySize,
              palette: palette,
              notesMode: false,
              enabled: enabled,
              onTap: onErase,
            ),
          ],
        );
      },
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    super.key,
    this.label,
    this.icon,
    this.tooltip,
    required this.size,
    required this.palette,
    required this.notesMode,
    required this.enabled,
    required this.onTap,
    this.remaining,
  });

  final String? label;
  final IconData? icon;
  final String? tooltip;
  final double size;
  final SudokuPalette palette;
  final bool notesMode;
  final bool enabled;
  final VoidCallback onTap;

  /// `null` on the eraser, which never runs out.
  final int? remaining;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    // A value that is already everywhere it goes has nothing left to do, but it
    // stays tappable: it may well be somewhere it does not belong.
    final done = remaining != null && remaining! <= 0;
    final foreground = !enabled || done
        ? palette.keyDoneText
        : notesMode
        ? palette.noteText
        : palette.keyText;

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
      child: icon != null
          ? Icon(icon, size: size * 0.42, color: foreground)
          : Stack(
              children: [
                Center(
                  child: Text(
                    label!,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      // Pencil marks are written smaller than answers, and so is
                      // the key that writes them.
                      fontSize: size * (notesMode ? 0.36 : 0.46),
                      height: 1,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                ),
                if (remaining != null && remaining! > 0 && size >= 34)
                  Positioned(
                    right: size * 0.08,
                    bottom: size * 0.04,
                    child: Text(
                      '${remaining!}',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontSize: size * 0.2,
                        height: 1,
                        color: palette.keyDoneText,
                      ),
                    ),
                  ),
              ],
            ),
    );

    final tappable = enabled
        ? MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: key,
            ),
          )
        : Opacity(opacity: 0.6, child: key);

    final message = tooltip;
    return message == null
        ? tappable
        : Tooltip(message: message, child: tappable);
  }
}
