import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings_provider.dart';
import '../../../../core/layout/responsive_scale.dart';
import '../../../../widgets/game_chip.dart';
import '../../../../widgets/game_chip_menu.dart';
import '../domain/sudoku_models.dart';
import '../state/sudoku_controller.dart';
import '../state/sudoku_game_state.dart';
import '../state/sudoku_settings.dart';

/// Board size, difficulty, the notes switch, and everything a round can be
/// helped along or ended with.
class SudokuToolbar extends ConsumerWidget {
  const SudokuToolbar({
    super.key,
    required this.game,
    required this.onCheckCell,
    required this.onCheckAll,
  });

  final SudokuGameState game;

  /// Checking reports back to the board, which is what says how it went.
  final VoidCallback onCheckCell;
  final VoidCallback onCheckAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final settings = ref.watch(sudokuSettingsProvider);
    final controller = ref.read(sudokuGameProvider.notifier);

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: context.rs(8),
      runSpacing: context.rs(8),
      children: [
        GameChipMenu<SudokuSize>(
          tooltip: strings.sudokuSizeLabel,
          selected: settings.size,
          onSelected: controller.changeSize,
          footnote: strings.sudokuSizeHint,
          options: [
            for (final size in SudokuSize.values)
              GameMenuOption(value: size, label: strings.sudokuSizeName(size)),
          ],
          child: GameChip(
            icon: Icons.grid_4x4_rounded,
            label: strings.sudokuSizeName(settings.size),
            trailingIcon: Icons.expand_more_rounded,
          ),
        ),
        GameChipMenu<SudokuDifficulty>(
          tooltip: strings.sudokuDifficultyLabel,
          selected: settings.difficulty,
          onSelected: controller.changeDifficulty,
          footnote: strings.sudokuDifficultyHint,
          options: [
            for (final difficulty in SudokuDifficulty.values)
              GameMenuOption(
                value: difficulty,
                label: strings.sudokuDifficultyName(difficulty),
              ),
          ],
          child: GameChip(
            icon: Icons.signal_cellular_alt_rounded,
            label: strings.sudokuDifficultyName(settings.difficulty),
            trailingIcon: Icons.expand_more_rounded,
          ),
        ),
        Tooltip(
          message: strings.sudokuNotesHint,
          child: GameChip(
            icon: settings.notesMode
                ? Icons.edit_note_rounded
                : Icons.edit_outlined,
            label: strings.sudokuNotes,
            active: settings.notesMode,
            onTap: controller.toggleNotesMode,
          ),
        ),
        Tooltip(
          message: strings.sudokuCheckCellHint,
          child: GameChip(
            icon: Icons.spellcheck_rounded,
            label: strings.sudokuCheckCell,
            enabled: game.canCheckSelected,
            onTap: game.canCheckSelected ? onCheckCell : null,
          ),
        ),
        Tooltip(
          message: strings.sudokuCheckAllHint,
          child: GameChip(
            icon: Icons.fact_check_outlined,
            label: strings.sudokuCheckAll,
            enabled: game.canCheckAll,
            onTap: game.canCheckAll ? onCheckAll : null,
          ),
        ),
        Tooltip(
          message: strings.sudokuSolveCellHint,
          child: GameChip(
            icon: Icons.lightbulb_outline_rounded,
            label: strings.sudokuSolveCell,
            badge: '${game.hintsUsed}',
            enabled: game.canRevealSelected,
            onTap: game.canRevealSelected ? controller.revealSelected : null,
          ),
        ),
        GameChip(
          icon: Icons.refresh_rounded,
          label: strings.sudokuNewGame,
          onTap: controller.newGame,
        ),
        Tooltip(
          message: strings.sudokuGiveUpHint,
          child: GameChip(
            icon: Icons.flag_rounded,
            label: strings.sudokuGiveUp,
            enabled: game.canGiveUp,
            onTap: game.canGiveUp ? controller.giveUp : null,
          ),
        ),
      ],
    );
  }
}
