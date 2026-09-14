import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/app_strings_provider.dart';
import '../../../core/layout/responsive_scale.dart';
import '../../../core/theme/app_theme_extension.dart';
import '../wordle_shared/widgets/wordle_game_view.dart';
import '../wordle_shared/widgets/wordle_result_banner.dart';
import 'domain/wordle_game_models.dart';
import 'state/wordle_controller.dart';
import 'state/wordle_game_state.dart';
import 'widgets/wordle_toolbar.dart';

class WordlePage extends ConsumerStatefulWidget {
  const WordlePage({super.key});

  @override
  ConsumerState<WordlePage> createState() => _WordlePageState();
}

class _WordlePageState extends ConsumerState<WordlePage> {
  /// Handed to the board so a hint can put the keyboard focus back on it
  /// after its dialog.
  final FocusNode _focusNode = FocusNode(debugLabel: 'wordle-board');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onHint() async {
    final controller = ref.read(wordleGameProvider.notifier);

    switch (controller.hint()) {
      case WordleHintOutcome.filled:
      case WordleHintOutcome.unavailable:
        break;
      case WordleHintOutcome.onlySolutionLeft:
        final solve = await _askToSolve();
        if (!mounted) return;
        if (solve ?? false) controller.fillSolution();
    }
    _focusNode.requestFocus();
  }

  /// Nothing is left to suggest short of the answer, so the player decides.
  Future<bool?> _askToSolve() {
    final strings = ref.read(appStringsProvider);
    final decor = context.decor;
    final theme = Theme.of(context);

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: decor.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: decor.cardRadius,
          side: BorderSide(color: decor.cardBorderColor),
        ),
        icon: Icon(
          Icons.lightbulb_rounded,
          color: decor.accentColor,
          size: context.rs(28),
        ),
        title: Text(
          strings.wordleHintOnlySolutionTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        content: Text(
          strings.wordleHintOnlySolutionBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: decor.subtleTextColor,
            height: 1.4,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              strings.wordleHintKeepPlaying,
              style: TextStyle(color: decor.subtleTextColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              strings.wordleHintSolve,
              style: TextStyle(color: decor.accentColor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(wordleGameProvider);
    final strings = ref.watch(appStringsProvider);
    final controller = ref.read(wordleGameProvider.notifier);

    return WordleGameView(
      focusNode: _focusNode,
      board: game.board,
      phase: switch (game.phase) {
        WordlePhase.loading => WordleViewPhase.loading,
        WordlePhase.failed => WordleViewPhase.failed,
        WordlePhase.playing => WordleViewPhase.playing,
        WordlePhase.won || WordlePhase.lost => WordleViewPhase.finished,
      },
      rowCount: (_) => game.maxAttempts,
      controls: controller,
      celebrateLastRow: game.phase == WordlePhase.won,
      shakeWhenRevealed: game.phase == WordlePhase.lost,
      toolbarBuilder: (context, revealing) => WordleToolbar(
        canGiveUp: game.canGiveUp && !revealing,
        canHint: game.isPlaying && !revealing,
        hintsUsed: game.hintsUsed,
        onHint: _onHint,
      ),
      statusBuilder: (context) =>
          game.phase.isFinished ? _buildResult(strings, game) : null,
    );
  }

  Widget _buildResult(AppStrings strings, WordleGameState game) {
    final won = game.phase == WordlePhase.won;
    final attempts = game.board.guessCount;

    return WordleResultBanner(
      key: ValueKey('result-${game.board.round}'),
      strings: strings,
      languageCode: game.board.languageCode,
      solution: game.board.solution,
      success: won,
      icon: won ? Icons.emoji_events_rounded : Icons.lightbulb_rounded,
      title: won ? strings.wordleWinTitle(attempts) : strings.wordleLoseTitle,
      detail: won ? strings.wordleWinDetail(attempts, game.maxAttempts) : null,
      onNewGame: ref.read(wordleGameProvider.notifier).newGame,
    );
  }
}
