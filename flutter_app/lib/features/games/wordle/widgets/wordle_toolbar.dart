import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/l10n/app_strings_provider.dart';
import '../../../../core/layout/responsive_scale.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../domain/wordle_models.dart';
import '../state/wordle_controller.dart';
import '../state/wordle_settings.dart';
import 'wordle_chip.dart';

/// Word length, difficulty, hard mode and the two game actions.
class WordleToolbar extends ConsumerWidget {
  const WordleToolbar({
    super.key,
    required this.canGiveUp,
    required this.canHint,
    required this.hintsUsed,
    required this.onHint,
  });

  final bool canGiveUp;
  final bool canHint;
  final int hintsUsed;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final settings = ref.watch(wordleSettingsProvider);
    final availableLengths = ref.watch(wordleAvailableLengthsProvider).value;
    final controller = ref.read(wordleGameProvider.notifier);
    final decor = context.decor;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: context.rs(8),
      runSpacing: context.rs(8),
      children: [
        _menu<int>(
          context: context,
          decor: decor,
          tooltip: strings.wordleLengthLabel,
          onSelected: controller.changeWordLength,
          items: [
            for (
              var length = kWordleMinLength;
              length <= kWordleMaxLength;
              length++
            )
              _item(
                context: context,
                decor: decor,
                value: length,
                label: strings.wordleLetterCount(length),
                // Lengths the active list cannot fill stay visible but
                // unselectable, so the rule is obvious rather than hidden.
                enabled: availableLengths?.contains(length) ?? false,
                selected: length == settings.wordLength,
                disabledHint: strings.wordleLengthUnavailable,
              ),
          ],
          child: WordleChip(
            icon: Icons.straighten_rounded,
            label: strings.wordleLetterCount(settings.wordLength),
            trailingIcon: Icons.expand_more_rounded,
          ),
        ),
        _menu<WordleDifficulty>(
          context: context,
          decor: decor,
          tooltip: strings.wordleDifficultyLabel,
          onSelected: controller.changeDifficulty,
          items: [
            for (final difficulty in WordleDifficulty.values)
              _item(
                context: context,
                decor: decor,
                value: difficulty,
                label: _difficultyLabel(strings, difficulty),
                enabled: true,
                selected: difficulty == settings.difficulty,
                disabledHint: null,
              ),
            PopupMenuItem<WordleDifficulty>(
              enabled: false,
              height: context.rs(32),
              child: Text(
                strings.wordleDifficultyHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: decor.subtleTextColor,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          child: WordleChip(
            icon: Icons.local_library_rounded,
            label: _difficultyLabel(strings, settings.difficulty),
            trailingIcon: Icons.expand_more_rounded,
          ),
        ),
        Tooltip(
          message: strings.wordleHardModeHint,
          child: WordleChip(
            icon: settings.hardMode
                ? Icons.lock_rounded
                : Icons.lock_open_rounded,
            label: strings.wordleHardMode,
            active: settings.hardMode,
            onTap: () => controller.setHardMode(!settings.hardMode),
          ),
        ),
        Tooltip(
          message: strings.wordleHintDescription,
          child: WordleChip(
            icon: Icons.lightbulb_outline_rounded,
            label: strings.wordleHint,
            badge: '$hintsUsed',
            enabled: canHint,
            onTap: canHint ? onHint : null,
          ),
        ),
        WordleChip(
          icon: Icons.refresh_rounded,
          label: strings.wordleNewGame,
          onTap: controller.newGame,
        ),
        WordleChip(
          icon: Icons.flag_rounded,
          label: strings.wordleGiveUp,
          enabled: canGiveUp,
          onTap: canGiveUp ? controller.giveUp : null,
        ),
      ],
    );
  }

  String _difficultyLabel(AppStrings strings, WordleDifficulty difficulty) {
    return switch (difficulty) {
      WordleDifficulty.normal => strings.wordleDifficultyNormal,
      WordleDifficulty.difficult => strings.wordleDifficultyHard,
      WordleDifficulty.allWords => strings.wordleDifficultyAll,
    };
  }

  Widget _menu<T>({
    required BuildContext context,
    required AppDecor decor,
    required String tooltip,
    required ValueChanged<T> onSelected,
    required List<PopupMenuEntry<T>> items,
    required Widget child,
  }) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      offset: Offset(0, context.rs(40)),
      color: decor.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: decor.cardRadius,
        side: BorderSide(color: decor.cardBorderColor),
      ),
      onSelected: onSelected,
      itemBuilder: (context) => items,
      child: child,
    );
  }

  PopupMenuItem<T> _item<T>({
    required BuildContext context,
    required AppDecor decor,
    required T value,
    required String label,
    required bool enabled,
    required bool selected,
    required String? disabledHint,
  }) {
    final theme = Theme.of(context);

    return PopupMenuItem<T>(
      value: value,
      enabled: enabled,
      height: context.rs(40),
      child: Row(
        children: [
          SizedBox(
            width: context.rs(22),
            child: selected
                ? Icon(
                    Icons.check_rounded,
                    size: context.rs(18),
                    color: decor.accentColor,
                  )
                : null,
          ),
          Expanded(
            child: Text(
              label,
              style: enabled
                  ? null
                  : theme.textTheme.bodyMedium?.copyWith(
                      color: decor.subtleTextColor.withValues(alpha: 0.5),
                    ),
            ),
          ),
          if (!enabled && disabledHint != null) ...[
            SizedBox(width: context.rs(8)),
            Text(
              disabledHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: decor.subtleTextColor.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
