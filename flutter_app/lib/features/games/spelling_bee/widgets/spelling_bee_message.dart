import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/layout/responsive_scale.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../widgets/game_action_button.dart';
import 'spelling_bee_palette.dart';

/// What a word was worth, or what was wrong with it.
class SpellingBeeToast extends StatelessWidget {
  const SpellingBeeToast({
    super.key,
    required this.message,
    required this.accent,
    this.icon,
    this.points,
  });

  final String message;
  final Color accent;
  final IconData? icon;

  /// Only set when the word counted.
  final int? points;

  bool get _isReward => points != null;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final theme = Theme.of(context);

    final pill = Container(
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
          if (icon != null) ...[
            Icon(icon, size: context.rs(16), color: accent),
            SizedBox(width: context.rs(8)),
          ],
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: _isReward ? accent : theme.textTheme.bodyLarge?.color,
              ),
            ),
          ),
          if (points != null) ...[
            SizedBox(width: context.rs(8)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.rs(7),
                vertical: context.rs(2),
              ),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(context.rs(20)),
              ),
              child: Text(
                '+${points!}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    final animated = pill
        .animate()
        .fadeIn(duration: 180.ms)
        .slideY(begin: 0.4, end: 0, duration: 300.ms, curve: Curves.easeOut);

    // A word that scored gets a sweep of its own colour; a rejected one does
    // not need decorating.
    return _isReward
        ? animated.shimmer(
            delay: 120.ms,
            duration: 900.ms,
            color: accent.withValues(alpha: 0.45),
          )
        : animated;
  }
}

/// Closes the round: what the player scored, and a way straight into the next
/// puzzle.
class SpellingBeeResultBanner extends StatelessWidget {
  const SpellingBeeResultBanner({
    super.key,
    required this.strings,
    required this.complete,
    required this.score,
    required this.foundWords,
    required this.totalWords,
    required this.onNewGame,
  });

  final AppStrings strings;

  /// `true` when every listed word was found rather than revealed.
  final bool complete;

  final int score;
  final int foundWords;
  final int totalWords;
  final VoidCallback onNewGame;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final theme = Theme.of(context);
    final palette = SpellingBeePalette.of(context);
    final accent = complete ? palette.normal : decor.accentColor;

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
                complete
                    ? Icons.emoji_events_rounded
                    : Icons.menu_book_rounded,
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
                      complete
                          ? strings.spellingBeeCompleteTitle
                          : strings.spellingBeeRevealedTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: accent,
                      ),
                    ),
                    SizedBox(height: context.rs(1)),
                    Text(
                      strings.spellingBeeScoreDetail(
                        score,
                        foundWords,
                        totalWords,
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
                label: strings.spellingBeeNewGame,
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
