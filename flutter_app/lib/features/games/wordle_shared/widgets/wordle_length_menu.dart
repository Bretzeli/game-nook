import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings_provider.dart';
import '../../../../widgets/game_chip.dart';
import '../../../../widgets/game_chip_menu.dart';
import '../data/wordle_word_repository.dart';
import '../domain/wordle_models.dart';

/// The word length chip of a Wordle-style toolbar.
class WordleLengthMenu extends ConsumerWidget {
  const WordleLengthMenu({
    super.key,
    required this.solutionList,
    required this.selected,
    required this.onSelected,
  });

  /// The list solutions are drawn from, which decides the lengths on offer.
  final WordleDifficulty solutionList;

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final available = ref
        .watch(wordleAvailableLengthsProvider(solutionList))
        .value;

    return GameChipMenu<int>(
      tooltip: strings.wordleLengthLabel,
      selected: selected,
      onSelected: onSelected,
      options: [
        for (var length = kWordleMinLength; length <= kWordleMaxLength; length++)
          GameMenuOption(
            value: length,
            label: strings.wordleLetterCount(length),
            // Lengths the active list cannot fill stay visible but
            // unselectable, so the rule is obvious rather than hidden.
            enabled: available?.contains(length) ?? false,
            disabledHint: strings.wordleLengthUnavailable,
          ),
      ],
      child: GameChip(
        icon: Icons.straighten_rounded,
        label: strings.wordleLetterCount(selected),
        trailingIcon: Icons.expand_more_rounded,
      ),
    );
  }
}
