import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings_provider.dart';
import '../../../../core/layout/responsive_scale.dart';
import '../../../../widgets/game_chip.dart';
import '../../../../widgets/game_chip_menu.dart';
import '../../wordle_shared/widgets/wordle_length_menu.dart';
import '../domain/dont_wordle_models.dart';
import '../state/dont_wordle_controller.dart';
import '../state/dont_wordle_settings.dart';

/// Word length, guesses, which words may be the solution, and the game
/// actions.
class DontWordleToolbar extends ConsumerWidget {
  const DontWordleToolbar({
    super.key,
    required this.canHint,
    required this.hintsUsed,
    required this.canGiveUp,
  });

  final bool canHint;
  final int hintsUsed;
  final bool canGiveUp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final settings = ref.watch(dontWordleSettingsProvider);
    final controller = ref.read(dontWordleGameProvider.notifier);

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: context.rs(8),
      runSpacing: context.rs(8),
      children: [
        WordleLengthMenu(
          solutionList: settings.solutionList,
          selected: settings.wordLength,
          onSelected: controller.changeWordLength,
        ),
        GameChipMenu<int>(
          tooltip: strings.dontWordleGuessesLabel,
          selected: settings.guesses,
          onSelected: controller.changeGuesses,
          footnote: strings.dontWordleGuessesHint,
          options: [
            for (
              var guesses = kDontWordleMinGuesses;
              guesses <= kDontWordleMaxGuesses;
              guesses++
            )
              GameMenuOption(
                value: guesses,
                label: strings.dontWordleGuessCount(guesses),
              ),
          ],
          child: GameChip(
            icon: Icons.table_rows_rounded,
            label: strings.dontWordleGuessCount(settings.guesses),
            trailingIcon: Icons.expand_more_rounded,
          ),
        ),
        GameChipMenu<bool>(
          tooltip: strings.wordleDifficultyLabel,
          selected: settings.difficultWords,
          onSelected: controller.setDifficultWords,
          footnote: strings.wordleDifficultyHint,
          options: [
            GameMenuOption(value: false, label: strings.wordleDifficultyNormal),
            GameMenuOption(value: true, label: strings.wordleDifficultyHard),
          ],
          child: GameChip(
            icon: Icons.local_library_rounded,
            label: settings.difficultWords
                ? strings.wordleDifficultyHard
                : strings.wordleDifficultyNormal,
            trailingIcon: Icons.expand_more_rounded,
          ),
        ),
        Tooltip(
          message: strings.dontWordleHintDescription,
          child: GameChip(
            icon: Icons.lightbulb_outline_rounded,
            label: strings.wordleHint,
            badge: '$hintsUsed',
            enabled: canHint,
            onTap: canHint ? controller.hint : null,
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
}
