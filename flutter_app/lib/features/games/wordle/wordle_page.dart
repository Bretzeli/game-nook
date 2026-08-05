import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/app_strings_provider.dart';
import '../../../core/layout/responsive_scale.dart';
import '../../../core/theme/app_theme_extension.dart';
import 'domain/wordle_models.dart';
import 'domain/wordle_rules.dart';
import 'state/wordle_controller.dart';
import 'state/wordle_game_state.dart';
import 'widgets/wordle_grid.dart';
import 'widgets/wordle_keyboard.dart';
import 'widgets/wordle_result_banner.dart';
import 'widgets/wordle_toolbar.dart';

class WordlePage extends ConsumerStatefulWidget {
  const WordlePage({super.key});

  @override
  ConsumerState<WordlePage> createState() => _WordlePageState();
}

class _WordlePageState extends ConsumerState<WordlePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: kTileFlipDuration,
  );
  final FocusNode _focusNode = FocusNode(debugLabel: 'wordle-board');

  /// Rows whose flip animation has finished. Everything downstream — the
  /// keyboard colours, the result banner — waits for this rather than for the
  /// game state, so the reveal is never spoiled early.
  int _revealedRows = 0;
  int _shakeToken = 0;
  String? _message;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _reveal.addStatusListener(_onRevealStatus);
    // The game outlives this page, so a round in progress comes back fully
    // revealed rather than as rows of colourless letters.
    _revealedRows = ref.read(wordleGameProvider).rows.length;
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _reveal.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onRevealStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() => _revealedRows = ref.read(wordleGameProvider).rows.length);
  }

  bool get _isRevealing => _reveal.isAnimating;

  void _onGameChanged(WordleGameState? previous, WordleGameState next) {
    if (previous == null || previous.round != next.round) {
      _reveal.stop();
      _reveal.value = 0;
      _messageTimer?.cancel();
      setState(() {
        _revealedRows = next.rows.length;
        _shakeToken = 0;
        _message = null;
      });
      return;
    }

    if (next.rows.length > previous.rows.length) {
      _messageTimer?.cancel();
      setState(() => _message = null);
      _reveal
        ..duration = revealDurationFor(next.wordLength)
        ..forward(from: 0);
    }
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

  void _submit() {
    final rejection = ref.read(wordleGameProvider.notifier).submit();
    if (rejection == null) return;

    _messageTimer?.cancel();
    setState(() {
      _shakeToken++;
      _message = _messageFor(ref.read(appStringsProvider), rejection);
    });
    _messageTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _message = null);
    });
  }

  String _messageFor(AppStrings strings, WordleRejection rejection) {
    switch (rejection.kind) {
      case WordleRejectionKind.tooShort:
        return strings.wordleNotEnoughLetters;
      case WordleRejectionKind.notInWordList:
        return strings.wordleNotInWordList;
      case WordleRejectionKind.hardMode:
        final violation = rejection.violation!;
        return switch (violation.kind) {
          HardModeViolationKind.fixedPosition => strings
              .wordleHardModeFixedLetter(violation.position, violation.letter),
          HardModeViolationKind.mustMove => strings.wordleHardModeMustMove(
            violation.position,
            violation.letter,
          ),
          HardModeViolationKind.missingLetter =>
            strings.wordleHardModeMustContain(violation.letter),
          HardModeViolationKind.forbiddenLetter =>
            strings.wordleHardModeMustNotContain(violation.letter),
        };
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;

    final game = ref.read(wordleGameProvider);
    if (!game.isPlaying) return KeyEventResult.ignored;
    // Swallow keystrokes while a row is turning over so nothing is lost
    // halfway through the animation.
    if (_isRevealing) return KeyEventResult.handled;

    final controller = ref.read(wordleGameProvider.notifier);
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _submit();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      controller.backspace();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      controller.moveCursor(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      controller.moveCursor(1);
      return KeyEventResult.handled;
    }

    final character = event.character;
    if (character != null && character.length == 1) {
      final before = game.typedWord;
      controller.typeLetter(character);
      if (ref.read(wordleGameProvider).typedWord != before) {
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(wordleGameProvider, _onGameChanged);

    final game = ref.watch(wordleGameProvider);
    final strings = ref.watch(appStringsProvider);

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _focusNode.requestFocus,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.rs(16),
            context.rs(4),
            context.rs(16),
            context.rs(12),
          ),
          child: Column(
            children: [
              WordleToolbar(
                canGiveUp: game.canGiveUp && !_isRevealing,
                canHint: game.isPlaying && !_isRevealing,
                hintsUsed: game.hintsUsed,
                onHint: _onHint,
              ),
              SizedBox(height: context.rs(12)),
              Expanded(child: _buildBoard(game)),
              SizedBox(height: context.rs(8)),
              SizedBox(
                height: context.rs(62),
                child: Center(child: _buildStrip(strings, game)),
              ),
              SizedBox(height: context.rs(6)),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: context.rs(560)),
                  child: WordleKeyboard(
                    languageCode: game.languageCode,
                    statuses: keyboardStatuses(game.rows, _revealedRows),
                    enabled: game.isPlaying && !_isRevealing,
                    onLetter: ref.read(wordleGameProvider.notifier).typeLetter,
                    onBackspace: ref.read(wordleGameProvider.notifier).backspace,
                    onEnter: _submit,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBoard(WordleGameState game) {
    switch (game.phase) {
      case WordlePhase.loading:
        return Center(
          child: CircularProgressIndicator(color: context.decor.accentColor),
        );
      case WordlePhase.failed:
        return _buildError();
      case WordlePhase.playing:
      case WordlePhase.won:
      case WordlePhase.lost:
        final board = Center(
          child: WordleGrid(
            game: game,
            revealedRows: _revealedRows,
            revealProgress: _isRevealing ? _reveal : null,
            shakeToken: _shakeToken,
            onSlotTap: ref.read(wordleGameProvider.notifier).selectSlot,
          ),
        );

        // A short nudge of the whole board is all the loss needs; the solution
        // itself is what the player is waiting for.
        if (game.phase == WordlePhase.lost && _revealedRows == game.rows.length) {
          return board
              .animate(key: ValueKey('lost-${game.round}'))
              .shakeX(duration: 460.ms, hz: 3.5, amount: 4);
        }
        return board;
    }
  }

  Widget _buildError() {
    final strings = ref.watch(appStringsProvider);
    final decor = context.decor;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: decor.accentSecondary,
            size: context.rs(36),
          ),
          SizedBox(height: context.rs(12)),
          Text(
            strings.wordleLoadFailed,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: decor.subtleTextColor),
          ),
          SizedBox(height: context.rs(12)),
          TextButton(
            onPressed: ref.read(wordleGameProvider.notifier).newGame,
            child: Text(strings.wordleRetry),
          ),
        ],
      ),
    );
  }

  Widget _buildStrip(AppStrings strings, WordleGameState game) {
    final showResult =
        game.phase.isFinished &&
        _revealedRows == game.rows.length &&
        !_isRevealing;

    final Widget child;
    if (showResult) {
      child = WordleResultBanner(
        key: ValueKey('result-${game.round}'),
        strings: strings,
        won: game.phase == WordlePhase.won,
        solution: game.solution,
        attempts: game.attemptsUsed,
        maxAttempts: game.maxAttempts,
        onNewGame: ref.read(wordleGameProvider.notifier).newGame,
      );
    } else if (_message != null) {
      child = _MessagePill(key: ValueKey(_message), message: _message!);
    } else {
      child = const SizedBox.shrink();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: FittedBox(fit: BoxFit.scaleDown, child: child),
    );
  }
}

class _MessagePill extends StatelessWidget {
  const _MessagePill({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final theme = Theme.of(context);

    return Container(
          constraints: BoxConstraints(maxWidth: context.rs(340)),
          padding: EdgeInsets.symmetric(
            horizontal: context.rs(16),
            vertical: context.rs(10),
          ),
          decoration: BoxDecoration(
            color: decor.cardColor,
            borderRadius: decor.buttonRadius,
            border: Border.all(
              color: decor.accentSecondary.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: decor.accentSecondary.withValues(alpha: 0.18),
                blurRadius: context.rs(18),
              ),
            ],
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 180.ms)
        .slideY(begin: 0.35, end: 0, curve: Curves.easeOut);
  }
}
