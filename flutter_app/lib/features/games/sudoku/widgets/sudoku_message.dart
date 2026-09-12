import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/layout/responsive_scale.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../widgets/game_action_button.dart';
import '../domain/sudoku_models.dart';
import 'sudoku_palette.dart';

/// What a check found, or what an action needs first.
class SudokuToast extends StatelessWidget {
  const SudokuToast({
    super.key,
    required this.message,
    required this.accent,
    required this.icon,
  });

  final String message;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final theme = Theme.of(context);

    return Container(
          constraints: BoxConstraints(maxWidth: context.rs(360)),
          padding: EdgeInsets.symmetric(
            horizontal: context.rs(14),
            vertical: context.rs(9),
          ),
          decoration: BoxDecoration(
            color: decor.cardColor,
            borderRadius: decor.buttonRadius,
            border: Border.all(color: accent.withValues(alpha: 0.55)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.2),
                blurRadius: context.rs(18),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: context.rs(16), color: accent),
              SizedBox(width: context.rs(8)),
              Flexible(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(color: accent),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 180.ms)
        .slideY(begin: 0.4, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}

/// How much of the board is still open, shown whenever there is nothing more
/// pressing to say.
class SudokuStatusLine extends StatelessWidget {
  const SudokuStatusLine({
    super.key,
    required this.strings,
    required this.remaining,
    required this.wrong,
  });

  final AppStrings strings;

  /// Cells still waiting for a value.
  final int remaining;

  /// Cells the last check marked wrong and that have not been changed since.
  final int wrong;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final theme = Theme.of(context);
    final palette = SudokuPalette.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${strings.sudokuRemainingLabel.toUpperCase()}  $remaining',
          style: theme.textTheme.labelLarge?.copyWith(
            color: decor.subtleTextColor,
            letterSpacing: 1.1,
          ),
        ),
        if (wrong > 0) ...[
          SizedBox(width: context.rs(12)),
          Icon(
            Icons.error_outline_rounded,
            size: context.rs(15),
            color: palette.wrong,
          ),
          SizedBox(width: context.rs(5)),
          Text(
            strings.sudokuWrongCount(wrong),
            style: theme.textTheme.labelLarge?.copyWith(color: palette.wrong),
          ),
        ],
      ],
    );
  }
}

/// Closes the round: how it went, and a way straight into the next board.
class SudokuResultBanner extends StatelessWidget {
  const SudokuResultBanner({
    super.key,
    required this.strings,
    required this.solved,
    required this.size,
    required this.difficulty,
    required this.solvedForYou,
    required this.onNewGame,
  });

  final AppStrings strings;

  /// `true` when the player filled the board in, `false` when they gave up.
  final bool solved;

  final SudokuSize size;
  final SudokuDifficulty difficulty;

  /// Cells that "solve cell" handed over.
  final int solvedForYou;

  final VoidCallback onNewGame;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final theme = Theme.of(context);
    final palette = SudokuPalette.of(context);
    final accent = solved ? palette.correct : decor.accentColor;

    return Container(
          padding: EdgeInsets.fromLTRB(
            context.rs(16),
            context.rs(10),
            context.rs(10),
            context.rs(10),
          ),
          decoration: BoxDecoration(
            color: decor.cardColor,
            borderRadius: decor.buttonRadius,
            border: Border.all(color: accent.withValues(alpha: 0.55)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.22),
                blurRadius: context.rs(22),
                offset: Offset(0, context.rs(6)),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                solved ? Icons.emoji_events_rounded : Icons.flag_rounded,
                color: accent,
                size: context.rs(20),
              ),
              SizedBox(width: context.rs(10)),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      solved
                          ? strings.sudokuSolvedTitle
                          : strings.sudokuRevealedTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: accent,
                      ),
                    ),
                    SizedBox(height: context.rs(1)),
                    Text(
                      strings.sudokuResultDetail(
                        size,
                        difficulty,
                        solvedForYou,
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: decor.subtleTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: context.rs(14)),
              GameActionButton(
                label: strings.sudokuNewGame,
                onTap: onNewGame,
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 320.ms, curve: Curves.easeOut)
        .slideY(begin: 0.5, end: 0, duration: 420.ms, curve: Curves.easeOutBack)
        .shimmer(
          delay: 200.ms,
          duration: 1100.ms,
          color: accent.withValues(alpha: 0.35),
        );
  }
}
