import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/app_strings_provider.dart';
import '../wordle_shared/widgets/wordle_game_view.dart';
import '../wordle_shared/widgets/wordle_message_pill.dart';
import '../wordle_shared/widgets/wordle_palette.dart';
import '../wordle_shared/widgets/wordle_result_banner.dart';
import 'domain/dont_wordle_models.dart';
import 'state/dont_wordle_controller.dart';
import 'state/dont_wordle_game_state.dart';
import 'widgets/dont_wordle_status_bar.dart';
import 'widgets/dont_wordle_toolbar.dart';

class DontWordlePage extends ConsumerWidget {
  const DontWordlePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(dontWordleGameProvider);
    final strings = ref.watch(appStringsProvider);
    final outcome = game.progress.outcome;

    return WordleGameView(
      board: game.board,
      phase: switch (game.status) {
        DontWordleStatus.loading => WordleViewPhase.loading,
        DontWordleStatus.failed => WordleViewPhase.failed,
        DontWordleStatus.ready =>
          game.progress.isFinished
              ? WordleViewPhase.finished
              : WordleViewPhase.playing,
      },
      // The rows for finding the word only join the board once the last guess
      // to survive has turned over, and stand apart from the ones above.
      rowCount: game.rowCountAfter,
      accentRowsFrom: game.avoidAttempts,
      controls: ref.read(dontWordleGameProvider.notifier),
      celebrateLastRow: outcome == DontWordleOutcome.solved,
      shakeWhenRevealed: switch (outcome) {
        DontWordleOutcome.hitSolution ||
        DontWordleOutcome.cornered ||
        DontWordleOutcome.gaveUp => true,
        DontWordleOutcome.solved || DontWordleOutcome.survived || null => false,
      },
      toolbarBuilder: (context, revealing) => DontWordleToolbar(
        canHint: game.canHint && !revealing,
        hintsUsed: game.hintsUsed,
        canGiveUp: game.canGiveUp && !revealing,
      ),
      headerBuilder: game.isReady
          ? (context, revealedRows) => DontWordleStatusBar(
              strings: strings,
              progress: game.progressAfter(revealedRows),
            )
          : null,
      statusBuilder: (context) => _buildStatus(context, ref, strings, game),
    );
  }

  Widget? _buildStatus(
    BuildContext context,
    WidgetRef ref,
    AppStrings strings,
    DontWordleGameState game,
  ) {
    final progress = game.progress;
    final round = game.board.round;

    return switch (progress.outcome) {
      final outcome? => _buildResult(ref, strings, game, outcome),
      // The moment the last row to survive has turned over.
      null
          when progress.phase == DontWordlePhase.finding &&
              progress.attempt == 1 =>
        WordleMessagePill(
          key: ValueKey('survived-$round'),
          message: strings.dontWordleSurvived,
          icon: Icons.shield_rounded,
          accent: WordlePalette.of(context).correct,
        ),
      null => null,
    };
  }

  Widget _buildResult(
    WidgetRef ref,
    AppStrings strings,
    DontWordleGameState game,
    DontWordleOutcome outcome,
  ) {
    final progress = game.progress;
    final (icon, title) = switch (outcome) {
      DontWordleOutcome.solved => (
        Icons.emoji_events_rounded,
        strings.dontWordleSolvedTitle,
      ),
      DontWordleOutcome.survived => (
        Icons.shield_rounded,
        strings.dontWordleSurvivedTitle,
      ),
      DontWordleOutcome.hitSolution => (
        Icons.gps_fixed_rounded,
        strings.dontWordleHitTitle,
      ),
      DontWordleOutcome.cornered => (
        Icons.block_rounded,
        strings.dontWordleCorneredTitle,
      ),
      DontWordleOutcome.gaveUp => (
        Icons.lightbulb_rounded,
        strings.wordleLoseTitle,
      ),
    };

    return WordleResultBanner(
      key: ValueKey('result-${game.board.round}'),
      strings: strings,
      languageCode: game.board.languageCode,
      solution: game.board.solution,
      // Surviving is the game; finding the word afterwards is the bonus.
      success:
          outcome == DontWordleOutcome.solved ||
          outcome == DontWordleOutcome.survived,
      icon: icon,
      title: title,
      // A found word is on the board in green already; every other ending
      // reveals it here.
      detail: outcome == DontWordleOutcome.solved
          ? strings.dontWordleSolvedDetail(progress.attempt, progress.attempts)
          : null,
      onNewGame: ref.read(dontWordleGameProvider.notifier).newGame,
    );
  }
}
