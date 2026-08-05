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
      keyText: theme.textTheme.titleMedium?.color ?? Colors.white,
    );
  }

  Color colorFor(LetterStatus status) => switch (status) {
    LetterStatus.correct => correct,
    LetterStatus.present => present,
    LetterStatus.absent => absent,
  };
}
