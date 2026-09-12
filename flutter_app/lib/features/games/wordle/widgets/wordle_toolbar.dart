import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/l10n/app_strings_provider.dart';
import '../../../../core/layout/responsive_scale.dart';
import '../domain/wordle_models.dart';
import '../state/wordle_controller.dart';
import '../state/wordle_settings.dart';
import '../../../../widgets/game_chip.dart';
import '../../../../widgets/game_chip_menu.dart';

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

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: context.rs(8),
      runSpacing: context.rs(8),
      children: [
        GameChipMenu<int>(
          tooltip: strings.wordleLengthLabel,
          selected: settings.wordLength,
          onSelected: controller.changeWordLength,
          options: [
            for (
              var length = kWordleMinLength;
              length <= kWordleMaxLength;
              length++
            )
              GameMenuOption(
                value: length,
                label: strings.wordleLetterCount(length),
                // Lengths the active list cannot fill stay visible but
                // unselectable, so the rule is obvious rather than hidden.
                enabled: availableLengths?.contains(length) ?? false,
                disabledHint: strings.wordleLengthUnavailable,
              ),
          ],
          child: GameChip(
            icon: Icons.straighten_rounded,
            label: strings.wordleLetterCount(settings.wordLength),
            trailingIcon: Icons.expand_more_rounded,
          ),
        ),
        GameChipMenu<WordleDifficulty>(
          tooltip: strings.wordleDifficultyLabel,
          selected: settings.difficulty,
          onSelected: controller.changeDifficulty,
          footnote: strings.wordleDifficultyHint,
          options: [
            for (final difficulty in WordleDifficulty.values)
              GameMenuOption(
                value: difficulty,
                label: _difficultyLabel(strings, difficulty),
              ),
          ],
          child: GameChip(
            icon: Icons.local_library_rounded,
            label: _difficultyLabel(strings, settings.difficulty),
            trailingIcon: Icons.expand_more_rounded,
          ),
        ),
        Tooltip(
          message: strings.wordleHardModeHint,
          child: GameChip(
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
          child: GameChip(
            icon: Icons.lightbulb_outline_rounded,
            label: strings.wordleHint,
            badge: '$hintsUsed',
            enabled: canHint,
            onTap: canHint ? onHint : null,
          ),
        ),
        GameChip(
          icon: Icons.refresh_rounded,
          label: strings.wordleNewGame,
          onTap: controller.newGame,
        ),
        GameChip(
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
}
