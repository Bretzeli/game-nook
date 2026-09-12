import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme_extension.dart';

/// Board colours for the active theme.
///
/// Right and wrong are green and red in every theme — like Wordle's green and
/// yellow they carry a rule, so they only follow the brightness of the theme and
/// not its accent. Everything else is derived from the theme's own decor, so the
/// grid sits inside the app rather than on top of it.
///
/// Three kinds of value have to be told apart at a glance: a clue the puzzle
/// came with is the plain text colour, what the player wrote is the theme's
/// accent, and what the game filled in for them is muted. Nothing else on the
/// board borrows a colour close to the red a wrong cell wears.
class SudokuPalette {
  const SudokuPalette({
    required this.cellBackground,
    required this.givenBackground,
    required this.selectedBackground,
    required this.peerBackground,
    required this.matchBackground,
    required this.gridLine,
    required this.boxLine,
    required this.selectedBorder,
    required this.givenText,
    required this.entryText,
    required this.revealedText,
    required this.noteText,
    required this.correct,
    required this.wrong,
    required this.keyBackground,
    required this.keyText,
    required this.keyDoneText,
  });

  /// A cell the player can write in.
  final Color cellBackground;

  /// One that came with the puzzle, tinted so the two are telling apart at a
  /// glance even where the text colour is hard to judge.
  final Color givenBackground;

  final Color selectedBackground;

  /// The row, column and box of the selection.
  final Color peerBackground;

  /// Cells holding the same value as the selected one. A stronger dose of the
  /// same highlight rather than a colour of its own, so that it can never be
  /// mistaken for a cell a check marked wrong.
  final Color matchBackground;

  final Color gridLine;
  final Color boxLine;
  final Color selectedBorder;

  final Color givenText;

  /// What the player filled in themselves.
  final Color entryText;

  /// What "solve cell" or "give up" filled in for them. Muted rather than
  /// accented: it is on the board but it is not the player's own work.
  final Color revealedText;

  final Color noteText;

  final Color correct;
  final Color wrong;

  final Color keyBackground;
  final Color keyText;

  /// A value with nowhere left to go, so its key has nothing left to do.
  final Color keyDoneText;

  factory SudokuPalette.of(BuildContext context) {
    final theme = Theme.of(context);
    final decor = context.decor;
    final isDark = theme.brightness == Brightness.dark;

    final text = theme.textTheme.titleLarge?.color ?? Colors.white;
    final cellBackground = isDark
        ? Color.alphaBlend(
            Colors.black.withValues(alpha: 0.22),
            decor.cardColor,
          )
        : Color.alphaBlend(
            Colors.white.withValues(alpha: 0.55),
            decor.cardColor,
          );

    return SudokuPalette(
      cellBackground: cellBackground,
      givenBackground: isDark
          ? Color.alphaBlend(
              decor.cardBorderColor.withValues(alpha: 0.34),
              cellBackground,
            )
          : Color.alphaBlend(
              decor.subtleTextColor.withValues(alpha: 0.13),
              cellBackground,
            ),
      selectedBackground: decor.accentColor.withValues(
        alpha: isDark ? 0.32 : 0.24,
      ),
      peerBackground: decor.accentColor.withValues(alpha: isDark ? 0.12 : 0.1),
      matchBackground: decor.accentColor.withValues(alpha: isDark ? 0.24 : 0.2),
      // The box borders are what gives a sudoku its shape, so they are pulled
      // well clear of the lines between cells inside a box rather than being
      // only a little thicker.
      gridLine: decor.cardBorderColor.withValues(alpha: isDark ? 0.6 : 0.75),
      boxLine: decor.subtleTextColor.withValues(alpha: isDark ? 0.95 : 0.85),
      selectedBorder: decor.accentColor,
      givenText: text,
      entryText: decor.accentColor,
      revealedText: decor.subtleTextColor,
      // Pencil marks are small enough on a phone that they need every bit of
      // contrast the muted colour has; what tells them apart from a value is
      // their size and where they sit, not how faint they are.
      noteText: decor.subtleTextColor,
      correct: isDark ? const Color(0xFF4C9A57) : const Color(0xFF3F8A4C),
      wrong: isDark ? const Color(0xFFD4635C) : const Color(0xFFC0433C),
      keyBackground: isDark
          ? Color.alphaBlend(
              decor.cardBorderColor.withValues(alpha: 0.45),
              decor.cardColor,
            )
          : Color.alphaBlend(
              decor.subtleTextColor.withValues(alpha: 0.18),
              decor.cardColor,
            ),
      keyText: theme.textTheme.titleMedium?.color ?? Colors.white,
      keyDoneText: decor.subtleTextColor.withValues(alpha: 0.4),
    );
  }
}
