import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/layout/responsive_scale.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../domain/spelling_bee_models.dart';
import 'spelling_bee_palette.dart';

/// One tier's standing, as the bar needs it.
class BeeTierProgress {
  const BeeTierProgress({
    required this.tier,
    required this.label,
    required this.hint,
    required this.score,
    required this.maxScore,
    required this.foundWords,
    required this.totalWords,
  });

  final BeeTier tier;
  final String label;
  final String hint;
  final int score;
  final int maxScore;
  final int foundWords;
  final int totalWords;

  double get fraction =>
      maxScore <= 0 ? 0 : (score / maxScore).clamp(0.0, 1.0);

  bool get isComplete => maxScore > 0 && score >= maxScore;
}

/// The score, the two tier bars, and what the bonus words have paid so far.
///
/// Both bars are on screen at once on purpose: the yellow one is the round a
/// player is meant to finish, the silver one is how much further the same
/// seven letters go, and neither has to be chosen up front.
class SpellingBeeProgress extends StatelessWidget {
  const SpellingBeeProgress({
    super.key,
    required this.strings,
    required this.totalScore,
    required this.tiers,
    required this.bonusScore,
    required this.bonusCount,
  });

  final AppStrings strings;
  final int totalScore;
  final List<BeeTierProgress> tiers;
  final int bonusScore;
  final int bonusCount;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final palette = SpellingBeePalette.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rs(14),
        vertical: context.rs(10),
      ),
      decoration: BoxDecoration(
        color: decor.cardColor.withValues(alpha: 0.55),
        borderRadius: decor.cardRadius,
        border: Border.all(color: decor.subtleNavBorder, width: 0.5),
      ),
      child: Row(
        children: [
          _ScoreBadge(
            score: totalScore,
            label: strings.spellingBeeScoreLabel,
            palette: palette,
          ),
          SizedBox(width: context.rs(14)),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < tiers.length; i++) ...[
                  if (i > 0) SizedBox(height: context.rs(8)),
                  _TierBar(
                    data: tiers[i],
                    color: palette.colorFor(tiers[i].tier),
                    track: palette.track,
                    strings: strings,
                  ),
                ],
                SizedBox(height: context.rs(8)),
                _BonusRow(
                  strings: strings,
                  palette: palette,
                  score: bonusScore,
                  count: bonusCount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({
    required this.score,
    required this.label,
    required this.palette,
  });

  final int score;
  final String label;
  final SpellingBeePalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The number counts up to its new value rather than jumping, which is
        // what makes a word feel like it paid out.
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: score.toDouble()),
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => Text(
            value.round().toString(),
            textScaler: TextScaler.noScaling,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: context.rs(26), // paired with TextScaler.noScaling
              fontWeight: FontWeight.w800,
              height: 1,
              color: palette.normal,
            ),
          ),
        ).animate(key: ValueKey('score-$score')).scaleXY(
          begin: score == 0 ? 1 : 1.18,
          end: 1,
          duration: 420.ms,
          curve: Curves.elasticOut,
        ),
        SizedBox(height: context.rs(2)),
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 9,
            letterSpacing: 1.1,
            color: context.decor.subtleTextColor,
          ),
        ),
      ],
    );
  }
}

class _TierBar extends StatefulWidget {
  const _TierBar({
    required this.data,
    required this.color,
    required this.track,
    required this.strings,
  });

  final BeeTierProgress data;
  final Color color;
  final Color track;
  final AppStrings strings;

  @override
  State<_TierBar> createState() => _TierBarState();
}

class _TierBarState extends State<_TierBar> {
  /// Bumped the moment a bar reaches its end, so the celebration plays once
  /// rather than on every rebuild that follows.
  int _completeToken = 0;

  @override
  void didUpdateWidget(_TierBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data.isComplete && !oldWidget.data.isComplete) {
      setState(() => _completeToken++);
    }
    // A new puzzle resets the bars; the next fill should celebrate again.
    if (!widget.data.isComplete && oldWidget.data.isComplete) {
      setState(() => _completeToken = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decor = context.decor;
    final data = widget.data;

    Widget row = Row(
      children: [
        SizedBox(
          width: context.rs(66),
          child: Tooltip(
            message: data.hint,
            child: Text(
              data.label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontSize: 11,
                color: data.isComplete ? widget.color : decor.subtleTextColor,
                fontWeight: data.isComplete ? FontWeight.w700 : null,
              ),
            ),
          ),
        ),
        SizedBox(width: context.rs(8)),
        Expanded(child: _bar(context)),
        SizedBox(width: context.rs(8)),
        SizedBox(
          width: context.rs(78),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (data.isComplete) ...[
                Icon(
                  Icons.check_circle_rounded,
                  size: context.rs(12),
                  color: widget.color,
                ).animate().scaleXY(
                  begin: 0,
                  end: 1,
                  duration: 420.ms,
                  curve: Curves.elasticOut,
                ),
                SizedBox(width: context.rs(3)),
              ],
              Flexible(
                child: Text(
                  widget.strings.spellingBeeFoundOf(
                    data.foundWords,
                    data.totalWords,
                  ),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: data.isComplete
                        ? widget.color
                        : decor.subtleTextColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (_completeToken > 0) {
      row = row
          .animate(key: ValueKey('complete-$_completeToken'))
          .scaleXY(
            begin: 1.05,
            end: 1,
            duration: 620.ms,
            curve: Curves.elasticOut,
          )
          .shimmer(
            duration: 1100.ms,
            color: widget.color.withValues(alpha: 0.7),
            padding: 0,
          );
    }
    return row;
  }

  Widget _bar(BuildContext context) {
    final height = context.rs(9);
    final radius = BorderRadius.circular(height);
    final data = widget.data;

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        height: height,
        decoration: BoxDecoration(color: widget.track, borderRadius: radius),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: data.fraction),
          duration: const Duration(milliseconds: 620),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    colors: [
                      widget.color.withValues(alpha: 0.65),
                      widget.color,
                    ],
                  ),
                  boxShadow: value > 0
                      ? [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.45),
                            blurRadius: height * 0.9,
                          ),
                        ]
                      : null,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
      // Every gain sends one sweep of light along what has been filled.
    ).animate(key: ValueKey('gain-${data.score}')).shimmer(
      delay: 120.ms,
      duration: 700.ms,
      color: Colors.white.withValues(alpha: 0.45),
      padding: 0,
    );
  }
}

class _BonusRow extends StatelessWidget {
  const _BonusRow({
    required this.strings,
    required this.palette,
    required this.score,
    required this.count,
  });

  final AppStrings strings;
  final SpellingBeePalette palette;
  final int score;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decor = context.decor;
    final earned = score > 0;

    return Row(
      children: [
        SizedBox(
          width: context.rs(66),
          child: Tooltip(
            message: strings.spellingBeeBonusHint,
            child: Text(
              strings.spellingBeeTierBonus,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontSize: 11,
                color: earned ? palette.bonus : decor.subtleTextColor,
                fontWeight: earned ? FontWeight.w700 : null,
              ),
            ),
          ),
        ),
        SizedBox(width: context.rs(8)),
        Expanded(
          child: earned
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: _pill(context),
                )
              // The full sentence is in the tooltip on the label; here it
              // gets as much of the short version as the width allows, over
              // two lines if that is what it takes on a phone.
              : Text(
                  strings.spellingBeeBonusHintShort,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    height: 1.25,
                    color: decor.subtleTextColor.withValues(alpha: 0.7),
                  ),
                ),
        ),
        SizedBox(width: context.rs(8)),
        SizedBox(
          width: context.rs(78),
          child: Text(
            earned ? strings.spellingBeeRareFinds(count) : '',
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: decor.subtleTextColor,
            ),
          ),
        ),
      ],
    );
  }

  /// Bonus points have no end to fill up to — there are hundreds of rare
  /// words in a puzzle — so they are counted rather than measured.
  Widget _pill(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.rs(8),
            vertical: context.rs(3),
          ),
          decoration: BoxDecoration(
            color: palette.bonus.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(context.rs(20)),
            border: Border.all(
              color: palette.bonus.withValues(alpha: 0.55),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: context.rs(11),
                color: palette.bonus,
              ),
              SizedBox(width: context.rs(4)),
              Text(
                '+$score',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: palette.bonus,
                ),
              ),
            ],
          ),
        )
        .animate(key: ValueKey('bonus-$score'))
        .scaleXY(begin: 1.3, end: 1, duration: 480.ms, curve: Curves.elasticOut)
        .shimmer(
          duration: 900.ms,
          color: palette.bonus.withValues(alpha: 0.6),
          padding: 0,
        );
  }
}
