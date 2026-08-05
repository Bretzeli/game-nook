import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme_extension.dart';
import '../domain/wordle_models.dart';

/// Board colours for the active theme.
///
/// Green/yellow stay recognisably "Wordle" in every theme — they carry the
/// rules, so they only adapt to the brightness. Everything neutral is derived
/// from the theme's own decor so the board sits inside the app rather than on
/// top of it.
class WordlePalette {
  const WordlePalette({
    required this.correct,
    required this.present,
    required this.absent,
    required this.emptyBorder,
    required this.filledBorder,
    required this.activeBorder,
    required this.tileText,
    required this.onFilled,
    required this.keyIdle,
    required this.keyText,
    required this.keyAbsentBackground,
    required this.keyAbsentText,
  });

  final Color correct;
  final Color present;
  final Color absent;
  final Color emptyBorder;
  final Color filledBorder;
  final Color activeBorder;
  final Color tileText;
  final Color onFilled;
  final Color keyIdle;
  final Color keyText;

  /// A ruled-out key needs to stand apart from a row of otherwise colourful
  /// keys at a glance, so it gets its own hue-neutral "dead" treatment rather
  /// than reusing [absent] (which is tuned for a single freshly-scored tile).
  final Color keyAbsentBackground;
  final Color keyAbsentText;

  factory WordlePalette.of(BuildContext context) {
    final theme = Theme.of(context);
    final decor = context.decor;
    final isDark = theme.brightness == Brightness.dark;

    final absent = isDark
        ? decor.cardBorderColor
        : Color.alphaBlend(
            decor.subtleTextColor.withValues(alpha: 0.85),
            decor.cardBorderColor,
          );

    // A neutral slate grey, blended in at the same strength in every dark
    // theme, so a ruled-out key reads as "dead" instead of just a duller
    // shade of that theme's own (often colourful) border tone.
    const neutralGrey = Color(0xFF6C7686);
    final keyAbsentBackground = isDark
        ? Color.alphaBlend(neutralGrey.withValues(alpha: 0.62), decor.cardColor)
        : absent;
    final keyAbsentText = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : Colors.white;

    return WordlePalette(
      correct: isDark ? const Color(0xFF4C9A57) : const Color(0xFF5FA45B),
      present: isDark ? const Color(0xFFB79A3C) : const Color(0xFFC9A94E),
      absent: absent,
      emptyBorder: decor.cardBorderColor.withValues(alpha: isDark ? 0.9 : 1),
      filledBorder: decor.subtleTextColor.withValues(alpha: 0.55),
      activeBorder: decor.accentColor,
      tileText: theme.textTheme.titleLarge?.color ?? Colors.white,
      onFilled: Colors.white,
      keyIdle: isDark
          ? Color.alphaBlend(
              decor.cardBorderColor.withValues(alpha: 0.45),
              decor.cardColor,
            )
          : Color.alphaBlend(
              decor.subtleTextColor.withValues(alpha: 0.18),
              decor.cardColor,
            ),
      keyAbsentBackground: keyAbsentBackground,
      keyAbsentText: keyAbsentText,
      keyText: theme.textTheme.titleMedium?.color ?? Colors.white,
    );
  }

  Color colorFor(LetterStatus status) => switch (status) {
    LetterStatus.correct => correct,
    LetterStatus.present => present,
    LetterStatus.absent => absent,
  };
}
