import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/l10n/app_strings_provider.dart';
import '../../../../core/layout/responsive_scale.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../domain/wordle_board.dart';
import '../domain/wordle_models.dart';
import '../domain/wordle_rules.dart';
import '../state/wordle_board_controller.dart';
import 'wordle_grid.dart';
import 'wordle_keyboard.dart';
import 'wordle_message_pill.dart';

/// Where the game shown in a [WordleGameView] stands.
enum WordleViewPhase { loading, failed, playing, finished }

/// The play screen of every Wordle-style game: toolbar, board, a strip for
/// messages and results, and the keyboard.
///
/// It owns everything about *showing* a round — rows turning over one after
/// the other, the keyboard and results waiting for them, rejected guesses
/// shaking and explaining themselves — so a game only supplies its state, its
/// controls and the few parts that are its own.
class WordleGameView extends ConsumerStatefulWidget {
  const WordleGameView({
    super.key,
    required this.board,
    required this.phase,
    required this.rowCount,
    required this.controls,
    required this.toolbarBuilder,
    this.headerBuilder,
    this.statusBuilder,
    this.accentRowsFrom,
    this.celebrateLastRow = false,
    this.shakeWhenRevealed = false,
    this.focusNode,
  });

  final WordleBoard board;
  final WordleViewPhase phase;

  /// Rows the board is laid out for, given how many rows have turned over so
  /// far — so rows a game adds mid-round wait for the flip that earns them.
  final int Function(int revealedRows) rowCount;

  final WordleBoardControls controls;

  /// The chips above the board. `revealing` is `true` while a row turns over,
  /// which is no time to start anything that changes the board.
  final Widget Function(BuildContext context, bool revealing) toolbarBuilder;

  /// An optional line between toolbar and board. It is handed the number of
  /// rows revealed so far, so what it shows never gets ahead of the flip.
  final Widget Function(BuildContext context, int revealedRows)? headerBuilder;

  /// What the strip under the board shows once every row has turned over and
  /// no message is up — typically the result banner — or `null` for nothing.
  final Widget? Function(BuildContext context)? statusBuilder;

  /// See [WordleGrid.accentRowsFrom].
  final int? accentRowsFrom;

  /// Whether the last row takes a bow once revealed, for a win.
  final bool celebrateLastRow;

  /// Whether the board gives a short shake once every row is revealed, for a
  /// loss.
  final bool shakeWhenRevealed;

  /// Lets the game put the keyboard focus back on the board, e.g. after a
  /// dialog. The view makes its own when `null`.
  final FocusNode? focusNode;

  @override
  ConsumerState<WordleGameView> createState() => _WordleGameViewState();
}

class _WordleGameViewState extends ConsumerState<WordleGameView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: kTileFlipDuration,
  );
  FocusNode? _ownFocusNode;

  /// Rows whose flip animation has finished. Everything downstream — the
  /// keyboard colours, the result banner — waits for this rather than for the
  /// game state, so the reveal is never spoiled early.
  int _revealedRows = 0;
  int _shakeToken = 0;
  String? _message;
  Timer? _messageTimer;

  FocusNode get _focusNode =>
      widget.focusNode ??
      (_ownFocusNode ??= FocusNode(debugLabel: 'wordle-board'));

  bool get _isRevealing => _reveal.isAnimating;

  @override
  void initState() {
    super.initState();
    _reveal.addStatusListener(_onRevealStatus);
    // The game outlives this view, so a round in progress comes back fully
    // revealed rather than as rows of colourless letters.
    _revealedRows = widget.board.rows.length;
  }

  @override
  void didUpdateWidget(WordleGameView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.board;
    final next = widget.board;

    if (previous.round != next.round) {
      _reveal.stop();
      _reveal.value = 0;
      _messageTimer?.cancel();
      _revealedRows = next.rows.length;
      _shakeToken = 0;
      _message = null;
      return;
    }

    if (next.rows.length > previous.rows.length) {
      _messageTimer?.cancel();
      _message = null;
      _reveal
        ..duration = revealDurationFor(next.wordLength)
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _reveal.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _onRevealStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() => _revealedRows = widget.board.rows.length);
  }

  void _submit() {
    final rejection = widget.controls.submit();
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
      case WordleRejectionKind.alreadyGuessed:
        return strings.wordleAlreadyGuessed;
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
    if (widget.phase != WordleViewPhase.playing) return KeyEventResult.ignored;
    // Swallow keystrokes while a row is turning over so nothing is lost
    // halfway through the animation.
    if (_isRevealing) return KeyEventResult.handled;

    final controls = widget.controls;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _submit();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      controls.backspace();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      controls.moveCursor(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      controls.moveCursor(1);
      return KeyEventResult.handled;
    }

    final character = event.character;
    if (character != null &&
        character.length == 1 &&
        controls.typeLetter(character)) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final board = widget.board;
    final headerBuilder = widget.headerBuilder;

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
              widget.toolbarBuilder(context, _isRevealing),
              SizedBox(height: context.rs(12)),
              if (headerBuilder != null) ...[
                headerBuilder(context, _revealedRows),
                SizedBox(height: context.rs(10)),
              ],
              Expanded(child: _buildBoard()),
              SizedBox(height: context.rs(8)),
              SizedBox(
                height: context.rs(62),
                child: Center(child: _buildStrip()),
              ),
              SizedBox(height: context.rs(6)),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: context.rs(560)),
                  child: WordleKeyboard(
                    languageCode: board.languageCode,
                    statuses: keyboardStatuses(board.rows, _revealedRows),
                    enabled:
                        widget.phase == WordleViewPhase.playing &&
                        !_isRevealing,
                    onLetter: widget.controls.typeLetter,
                    onBackspace: widget.controls.backspace,
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

  Widget _buildBoard() {
    switch (widget.phase) {
      case WordleViewPhase.loading:
        return Center(
          child: CircularProgressIndicator(color: context.decor.accentColor),
        );
      case WordleViewPhase.failed:
        return _LoadError(onRetry: widget.controls.newGame);
      case WordleViewPhase.playing:
      case WordleViewPhase.finished:
        final board = Center(
          child: WordleGrid(
            board: widget.board,
            rowCount: widget.rowCount(_revealedRows),
            acceptsInput: widget.phase == WordleViewPhase.playing,
            revealedRows: _revealedRows,
            revealProgress: _isRevealing ? _reveal : null,
            shakeToken: _shakeToken,
            onSlotTap: widget.controls.selectSlot,
            celebrateLastRow: widget.celebrateLastRow,
            accentRowsFrom: widget.accentRowsFrom,
          ),
        );

        // A short nudge of the whole board is all a loss needs; the solution
        // itself is what the player is waiting for.
        if (widget.shakeWhenRevealed &&
            _revealedRows == widget.board.rows.length) {
          return board
              .animate(key: ValueKey('lost-${widget.board.round}'))
              .shakeX(duration: 460.ms, hz: 3.5, amount: 4);
        }
        return board;
    }
  }

  Widget _buildStrip() {
    final settled =
        !_isRevealing && _revealedRows == widget.board.rows.length;
    final message = _message;

    final Widget child;
    if (message != null) {
      child = WordleMessagePill(key: ValueKey(message), message: message);
    } else if (settled) {
      child = widget.statusBuilder?.call(context) ?? const SizedBox.shrink();
    } else {
      child = const SizedBox.shrink();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: FittedBox(fit: BoxFit.scaleDown, child: child),
    );
  }
}

class _LoadError extends ConsumerWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          TextButton(onPressed: onRetry, child: Text(strings.wordleRetry)),
        ],
      ),
    );
  }
}
