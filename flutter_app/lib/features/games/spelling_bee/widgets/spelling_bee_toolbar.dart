import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings_provider.dart';
import '../../../../core/layout/responsive_scale.dart';
import '../../../../widgets/game_chip.dart';
import '../state/spelling_bee_controller.dart';

/// The two things a round can be ended with.
class SpellingBeeToolbar extends ConsumerWidget {
  const SpellingBeeToolbar({super.key, required this.canGiveUp});

  final bool canGiveUp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final controller = ref.read(spellingBeeGameProvider.notifier);

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: context.rs(8),
      runSpacing: context.rs(8),
      children: [
        GameChip(
          icon: Icons.refresh_rounded,
          label: strings.spellingBeeNewGame,
          onTap: controller.newGame,
        ),
        Tooltip(
          message: strings.spellingBeeGiveUpHint,
          child: GameChip(
            icon: Icons.visibility_rounded,
            label: strings.spellingBeeGiveUp,
            enabled: canGiveUp,
            onTap: canGiveUp ? controller.revealAll : null,
          ),
        ),
      ],
    );
  }
}
