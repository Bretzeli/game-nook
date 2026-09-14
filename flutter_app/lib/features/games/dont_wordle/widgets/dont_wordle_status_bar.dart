import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/layout/responsive_scale.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../wordle_shared/widgets/wordle_palette.dart';
import '../domain/dont_wordle_models.dart';

/// From this many words left on, the counter starts to look worried.
const int _kFewWordsLeft = 10;

/// The line above the board: how many words of every list still fit the
/// hints, and how many of them could be the solution.
class DontWordleStatusBar extends StatelessWidget {
  const DontWordleStatusBar({
    super.key,
    required this.strings,
    required this.progress,
  });

  final AppStrings strings;

  /// The round as far as the player may know it — see
  /// [DontWordleGameState.progressAfter].
  final DontWordleProgress progress;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final outcome = progress.outcome;
    final wordsLeft = progress.wordsLeft;
    // While the word is being avoided, the words left are what can end the
    // round; once it is being looked for, the possible solutions matter.
    final finding = progress.hasSurvived;
    final inDanger =
        wordsLeft.words <= _kFewWordsLeft ||
        outcome == DontWordleOutcome.hitSolution ||
        outcome == DontWordleOutcome.cornered;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: context.rs(8),
      runSpacing: context.rs(6),
      children: [
        Tooltip(
          message: strings.dontWordleWordsLeftHint,
          triggerMode: TooltipTriggerMode.tap,
          child: _Counter(
            icon: Icons.manage_search_rounded,
            count: wordsLeft.words,
            label: strings.dontWordleWordsLeft,
            color: finding
                ? decor.subtleTextColor
                : inDanger
                ? decor.accentSecondary
                : decor.accentColor,
            emphasised: !finding,
          ),
        ),
        Tooltip(
          message: strings.dontWordleSolutionsLeftHint,
          triggerMode: TooltipTriggerMode.tap,
          child: _Counter(
            icon: Icons.my_location_rounded,
            count: wordsLeft.solutions,
            label: strings.dontWordleSolutionsLeft,
            color: finding
                ? WordlePalette.of(context).correct
                : decor.subtleTextColor,
            emphasised: finding,
          ),
        ),
      ],
    );
  }
}

/// A count in a pill, ticking to its new value whenever a row has turned
/// over.
class _Counter extends StatelessWidget {
  const _Counter({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
    required this.emphasised,
  });

  final IconData icon;
  final int count;
  final String Function(int count) label;
  final Color color;

  /// Filled with a wash of [color] rather than only outlined.
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      padding: EdgeInsets.symmetric(
        horizontal: context.rs(12),
        vertical: context.rs(6),
      ),
      decoration: BoxDecoration(
        color: emphasised
            ? color.withValues(alpha: 0.12)
            : decor.cardColor.withValues(alpha: 0.5),
        borderRadius: decor.buttonRadius,
        border: Border.all(
          color: emphasised
              ? color.withValues(alpha: 0.6)
              : decor.subtleNavBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: context.rs(16), color: color),
          SizedBox(width: context.rs(6)),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: count.toDouble()),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text(
              label(value.round()),
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                // Equal-width digits keep the pill from wobbling as it counts.
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
