import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/dictionary/word_definition.dart';
import '../../../../core/dictionary/word_definition_dialog.dart';
import '../../../../core/dictionary/word_definition_provider.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/layout/responsive_scale.dart';
import '../../../../core/theme/app_theme_extension.dart';
import 'wordle_palette.dart';

/// Slides in once the last row has finished flipping: a compliment on a win,
/// the solution on a loss.
class WordleResultBanner extends ConsumerWidget {
  const WordleResultBanner({
    super.key,
    required this.strings,
    required this.languageCode,
    required this.won,
    required this.solution,
    required this.attempts,
    required this.maxAttempts,
    required this.onNewGame,
  });

  final AppStrings strings;

  /// Which language's dictionary the solution should be looked up in.
  final String languageCode;

  final bool won;
  final String solution;
  final int attempts;
  final int maxAttempts;
  final VoidCallback onNewGame;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decor = context.decor;
    final theme = Theme.of(context);
    final palette = WordlePalette.of(context);
    final accent = won ? palette.correct : decor.accentSecondary;

    // Null until the dictionary has been read, and stays null when it has
    // nothing on this word — so the question mark simply never appears.
    final definition = ref
        .watch(
          wordDefinitionProvider((
            languageCode: languageCode,
            word: solution,
          )),
        )
        .value;

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
                won ? Icons.emoji_events_rounded : Icons.lightbulb_rounded,
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
                      won
                          ? strings.wordleWinTitle(attempts)
                          : strings.wordleLoseTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: accent,
                      ),
                    ),
                    SizedBox(height: context.rs(1)),
                    won
                        ? Text(
                            strings.wordleWinDetail(attempts, maxAttempts),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: decor.subtleTextColor,
                            ),
                          )
                        : _Solution(solution: solution, strings: strings),
                  ],
                ),
              ),
              if (definition != null) ...[
                SizedBox(width: context.rs(10)),
                _ExplainButton(
                  strings: strings,
                  definition: definition,
                  color: accent,
                ),
              ],
              SizedBox(width: context.rs(14)),
              _NewGameButton(label: strings.wordleNewGame, onTap: onNewGame),
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

/// The solution, revealed letter by letter.
class _Solution extends StatelessWidget {
  const _Solution({required this.solution, required this.strings});

  final String solution;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${strings.wordleSolutionLabel}: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: decor.subtleTextColor,
          ),
        ),
        Flexible(
          child: Text(
                solution,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  letterSpacing: 1.5,
                  color: decor.accentColor,
                ),
              )
              .animate()
              .fadeIn(delay: 260.ms, duration: 420.ms)
              .slideX(begin: 0.12, end: 0, curve: Curves.easeOut),
        ),
      ],
    );
  }
}

/// The question mark offering the dictionary entry for the solution. It only
/// ever reaches the tree once there is an entry to show, so it never opens on
/// nothing.
class _ExplainButton extends StatefulWidget {
  const _ExplainButton({
    required this.strings,
    required this.definition,
    required this.color,
  });

  final AppStrings strings;
  final WordDefinition definition;
  final Color color;

  @override
  State<_ExplainButton> createState() => _ExplainButtonState();
}

class _ExplainButtonState extends State<_ExplainButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final size = context.rs(30);

    return Tooltip(
      message: widget.strings.dictionaryExplainTooltip(
        widget.definition.word,
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showWordDefinitionDialog(
            context,
            strings: widget.strings,
            definition: widget.definition,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: _hovered ? 0.24 : 0.12),
              border: Border.all(
                color: widget.color.withValues(alpha: _hovered ? 1 : 0.6),
              ),
            ),
            child: Icon(
              Icons.question_mark_rounded,
              size: context.rs(16),
              color: widget.color,
            ),
          ),
        ),
      ),
        )
        // The lookup lands a moment after the banner does, so the button
        // arrives on its own rather than popping in unannounced.
        .animate()
        .fadeIn(duration: 240.ms)
        .scaleXY(begin: 0.7, end: 1, curve: Curves.easeOutBack);
  }
}

class _NewGameButton extends StatefulWidget {
  const _NewGameButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_NewGameButton> createState() => _NewGameButtonState();
}

class _NewGameButtonState extends State<_NewGameButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final theme = Theme.of(context);
    final filled = decor.buttonStyle != AppButtonStyle.outlined;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: context.rs(14),
            vertical: context.rs(9),
          ),
          decoration: BoxDecoration(
            color: filled
                ? decor.accentColor.withValues(alpha: _hovered ? 1 : 0.85)
                : decor.accentColor.withValues(alpha: _hovered ? 0.2 : 0.1),
            borderRadius: decor.buttonRadius,
            border: Border.all(color: decor.accentColor, width: 1),
          ),
          child: Text(
            widget.label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: filled ? Colors.white : decor.accentColor,
            ),
          ),
        ),
      ),
    );
  }
}
