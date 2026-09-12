import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme_extension.dart';
import '../domain/spelling_bee_models.dart';

/// Board colours for the active theme.
///
/// Honey yellow and silver carry the rules — they are what tells the two bars
/// (and the words that filled them) apart — so, like Wordle's green and
/// yellow, they only adapt to the brightness of the theme rather than to its
/// accent. Everything else is derived from the theme's own decor so the hive
/// sits inside the app rather than on top of it.
class SpellingBeePalette {
  const SpellingBeePalette({
    required this.normal,
    required this.difficult,
    required this.bonus,
    required this.track,
    required this.centerHex,
    required this.outerHex,
    required this.hexBorder,
    required this.hexText,
    required this.onCenter,
    required this.inputText,
    required this.inputMuted,
    required this.error,
  });

  /// The yellow bar, the centre of the hive, and everyday words.
  final Color normal;

  /// The silver bar and the rarer words that fill it.
  final Color difficult;

  /// Words neither list knows.
  final Color bonus;

  /// The empty part of a bar.
  final Color track;

  final Color centerHex;
  final Color outerHex;
  final Color hexBorder;
  final Color hexText;
  final Color onCenter;

  final Color inputText;

  /// A typed letter the hive does not offer.
  final Color inputMuted;

  final Color error;

  factory SpellingBeePalette.of(BuildContext context) {
    final theme = Theme.of(context);
    final decor = context.decor;
    final isDark = theme.brightness == Brightness.dark;

    final normal = isDark ? const Color(0xFFE8B33C) : const Color(0xFFD99A22);
    // Silver rather than grey: bright and slightly cool, so the second bar
    // reads as a metal of its own next to the honey of the first.
    final difficult = isDark
        ? const Color(0xFFD2DCEA)
        : const Color(0xFF8795AC);

    return SpellingBeePalette(
      normal: normal,
      difficult: difficult,
      bonus: isDark ? const Color(0xFFB98BE8) : const Color(0xFF8B5CF6),
      track: isDark
          ? Color.alphaBlend(
              Colors.black.withValues(alpha: 0.28),
              decor.cardColor,
            )
          : Color.alphaBlend(
              decor.subtleTextColor.withValues(alpha: 0.18),
              decor.cardColor,
            ),
      centerHex: normal,
      outerHex: isDark
          ? Color.alphaBlend(
              decor.cardBorderColor.withValues(alpha: 0.45),
              decor.cardColor,
            )
          : Color.alphaBlend(
              decor.subtleTextColor.withValues(alpha: 0.16),
              decor.cardColor,
            ),
      hexBorder: decor.cardBorderColor.withValues(alpha: isDark ? 0.7 : 1),
      hexText: theme.textTheme.titleLarge?.color ?? Colors.white,
      // The centre tile is a solid block of honey in every theme, so its
      // letter needs a colour that reads on yellow rather than the theme's.
      onCenter: const Color(0xFF1B1607),
      inputText: theme.textTheme.titleLarge?.color ?? Colors.white,
      inputMuted: decor.subtleTextColor.withValues(alpha: 0.45),
      error: decor.accentSecondary,
    );
  }

  Color colorFor(BeeTier tier) => switch (tier) {
    BeeTier.normal => normal,
    BeeTier.difficult => difficult,
    BeeTier.bonus => bonus,
  };
}
