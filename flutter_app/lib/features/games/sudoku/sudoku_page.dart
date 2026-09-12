import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/app_strings_provider.dart';
import '../../../core/layout/responsive_scale.dart';
import '../../../core/theme/app_theme_extension.dart';
import 'domain/sudoku_models.dart';
import 'state/sudoku_controller.dart';
import 'state/sudoku_game_state.dart';
import 'state/sudoku_settings.dart';
import 'widgets/sudoku_board_view.dart';
import 'widgets/sudoku_keypad.dart';
import 'widgets/sudoku_message.dart';
import 'widgets/sudoku_palette.dart';
import 'widgets/sudoku_toolbar.dart';

/// How long a check result stays up.
const Duration _kToastLingers = Duration(milliseconds: 2400);

/// How long the cells a check found right stay green. Long enough to read, short
/// enough that the board does not stay coloured in.
const Duration _kCorrectMarksLinger = Duration(milliseconds: 1700);

/// How long a typed digit waits to see whether another one follows it.
///
/// On a board with more than nine values a 1 may turn out to be the start of a
/// 12, so the first digit is written straight away and replaced if a second
/// arrives in time. Anything else the player does closes the pair early.
const Duration _kDigitPairWindow = Duration(milliseconds: 1200);

/// The zoom settings the board steps through.
///
/// It reaches six times because that is what it takes for a 25×25 board to show
/// twenty-five two-digit pencil marks inside one cell rather than the dot that
/// stands in for them when there is no room.
const List<double> _kZoomSteps = [1, 1.5, 2, 3, 4, 6];

/// From this width the keys sit beside the board rather than under it, which on
/// a desktop leaves the board the whole height of the window.
const double _kSideBySideWidth = 900;

/// The share of the height the keys may take when they are under the board.
const double _kPadHeightShare = 0.38;

/// Boards wider than this are the ones worth being able to zoom into.
const int _kZoomableFrom = 12;

/// Which way each arrow key walks the selection, as (rows, columns).
final Map<LogicalKeyboardKey, (int, int)> _kArrowMoves = {
  LogicalKeyboardKey.arrowUp: (-1, 0),
  LogicalKeyboardKey.arrowDown: (1, 0),
  LogicalKeyboardKey.arrowLeft: (0, -1),
  LogicalKeyboardKey.arrowRight: (0, 1),
};

/// Numpad keys carry their own logical keys, and their labels ("Numpad 7") are
/// not the single digit the board is after.
final Map<LogicalKeyboardKey, int> _kNumpadDigits = {
  LogicalKeyboardKey.numpad0: 0,
  LogicalKeyboardKey.numpad1: 1,
  LogicalKeyboardKey.numpad2: 2,
  LogicalKeyboardKey.numpad3: 3,
  LogicalKeyboardKey.numpad4: 4,
  LogicalKeyboardKey.numpad5: 5,
  LogicalKeyboardKey.numpad6: 6,
  LogicalKeyboardKey.numpad7: 7,
  LogicalKeyboardKey.numpad8: 8,
  LogicalKeyboardKey.numpad9: 9,
};

class SudokuPage extends ConsumerStatefulWidget {
  const SudokuPage({super.key});

  @override
  ConsumerState<SudokuPage> createState() => _SudokuPageState();
}

class _SudokuPageState extends ConsumerState<SudokuPage> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'sudoku-board');

  _Message? _message;
  int _messageToken = 0;
  Timer? _messageTimer;
  Timer? _markTimer;

  double _zoom = 1;

  /// The digit typed a moment ago, which a second one may still extend.
  int? _pendingDigit;
  Timer? _digitTimer;

  @override
  void dispose() {
    _messageTimer?.cancel();
    _markTimer?.cancel();
    _digitTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _onGameChanged(SudokuGameState? previous, SudokuGameState next) {
    if (previous != null && previous.round == next.round) return;
    // A new board: nothing from the last one should still be on screen, and a
    // board of another size has no business inheriting the old one's zoom.
    _messageTimer?.cancel();
    _markTimer?.cancel();
    _digitTimer?.cancel();
    setState(() {
      _message = null;
      _pendingDigit = null;
      _zoom = 1;
    });
  }

  // --- zoom ---------------------------------------------------------------

  bool _canZoom(SudokuGameState game, {required int by}) {
    final index = _kZoomSteps.indexOf(_zoom) + by;
    return index >= 0 && index < _kZoomSteps.length;
  }

  void _stepZoom(int by) {
    final index = _kZoomSteps.indexOf(_zoom) + by;
    if (index < 0 || index >= _kZoomSteps.length) return;
    setState(() => _zoom = _kZoomSteps[index]);
  }

  // --- checking -----------------------------------------------------------

  void _checkSelected() =>
      _report(ref.read(sudokuGameProvider.notifier).checkSelected(), one: true);

  void _checkAll() =>
      _report(ref.read(sudokuGameProvider.notifier).checkAll(), one: false);

  /// Says how a check went, and arranges for the green to fade.
  void _report(SudokuCheckResult result, {required bool one}) {
    final strings = ref.read(appStringsProvider);

    if (result.isEmpty) {
      _show(
        _Message(
          text: strings.sudokuNothingToCheck,
          icon: Icons.info_outline_rounded,
          tone: _Tone.neutral,
        ),
      );
      return;
    }

    if (result.wrong == 0) {
      _show(
        _Message(
          text: one
              ? strings.sudokuCellCorrect
              : strings.sudokuAllCorrect(result.checked),
          icon: Icons.check_circle_outline_rounded,
          tone: _Tone.good,
        ),
      );
    } else {
      _show(
        _Message(
          text: one
              ? strings.sudokuCellWrong
              : strings.sudokuWrongCount(result.wrong),
          icon: Icons.error_outline_rounded,
          tone: _Tone.bad,
        ),
      );
    }

    _markTimer?.cancel();
    _markTimer = Timer(_kCorrectMarksLinger, () {
      if (mounted) ref.read(sudokuGameProvider.notifier).clearCorrectMarks();
    });
  }

  void _show(_Message message) {
    _messageTimer?.cancel();
    setState(() {
      _messageToken++;
      _message = message;
    });
    _messageTimer = Timer(_kToastLingers, () {
      if (mounted) setState(() => _message = null);
    });
  }

  /// A value key with nothing picked out has nowhere to go, and saying so is
  /// more use than doing nothing.
  bool _hasSelection(SudokuGameState game) {
    if (game.selected != null) return true;
    _show(
      _Message(
        text: ref.read(appStringsProvider).sudokuSelectCellFirst,
        icon: Icons.touch_app_outlined,
        tone: _Tone.neutral,
      ),
    );
    return false;
  }

  // --- entering values ----------------------------------------------------

  void _closeDigitPair() {
    _digitTimer?.cancel();
    if (_pendingDigit != null) _pendingDigit = null;
  }

  /// Takes one typed digit.
  ///
  /// The digit is written on its own straight away, and if a second one follows
  /// while the pair is still open and the two together name a value this board
  /// has, that value replaces it — which is how 12 is typed on a 16×16 board.
  void _typeDigit(int digit, SudokuGameState game, {required bool asNote}) {
    final pending = _pendingDigit;
    final paired = pending == null ? 0 : pending * 10 + digit;
    final extends_ = paired >= 1 && paired <= game.length;

    final value = extends_
        ? paired
        : (digit >= 1 && digit <= game.length ? digit : 0);
    if (value == 0) {
      _closeDigitPair();
      return;
    }

    final controller = ref.read(sudokuGameProvider.notifier);
    if (asNote) {
      // A pencil mark is a toggle, so the digit written a moment ago has to be
      // taken back off before the pair it turned into goes on.
      if (extends_) controller.toggleNote(pending!);
      controller.toggleNote(value);
    } else {
      controller.place(value);
    }

    _digitTimer?.cancel();
    // Only a digit that could still start a value of this board is worth
    // holding on to.
    if (!extends_ && digit * 10 <= game.length) {
      _pendingDigit = digit;
      _digitTimer = Timer(_kDigitPairWindow, () => _pendingDigit = null);
    } else {
      _pendingDigit = null;
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;

    final game = ref.read(sudokuGameProvider);
    if (!game.isPlaying) return KeyEventResult.ignored;

    final controller = ref.read(sudokuGameProvider.notifier);
    final key = event.logicalKey;

    final move = _kArrowMoves[key];
    if (move != null) {
      _closeDigitPair();
      controller.moveSelection(rows: move.$1, columns: move.$2);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      _closeDigitPair();
      if (_hasSelection(game)) controller.erase();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _closeDigitPair();
      controller.clearSelection();
      return KeyEventResult.handled;
    }
    // Nothing on the board needs a space, and reaching for the notes is the
    // thing a player does most often.
    if (key == LogicalKeyboardKey.space) {
      _closeDigitPair();
      controller.toggleNotesMode();
      return KeyEventResult.handled;
    }

    final digit = _digitOf(key);
    if (digit == null) return KeyEventResult.ignored;
    if (!_hasSelection(game)) return KeyEventResult.handled;

    // Shift writes a single pencil mark without having to switch modes.
    _typeDigit(
      digit,
      game,
      asNote:
          HardwareKeyboard.instance.isShiftPressed ||
          ref.read(sudokuSettingsProvider).notesMode,
    );
    return KeyEventResult.handled;
  }

  /// The digit a key stands for. The key's own label is used rather than the
  /// character it produced, so that holding shift still reads as a 1 and not as
  /// whatever the layout puts above it.
  int? _digitOf(LogicalKeyboardKey key) {
    final numpad = _kNumpadDigits[key];
    if (numpad != null) return numpad;
    return sudokuDigitOf(key.keyLabel);
  }

  // --- building -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    ref.listen(sudokuGameProvider, _onGameChanged);

    final game = ref.watch(sudokuGameProvider);
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
          child: switch (game.phase) {
            SudokuPhase.loading => Center(
              child: CircularProgressIndicator(
                color: context.decor.accentColor,
              ),
            ),
            SudokuPhase.failed => _buildError(strings),
            SudokuPhase.playing ||
            SudokuPhase.solved ||
            SudokuPhase.revealed => _buildGame(strings, game),
          },
        ),
      ),
    );
  }

  Widget _buildGame(AppStrings strings, SudokuGameState game) {
    return Column(
      children: [
        SudokuToolbar(
          game: game,
          onCheckCell: _checkSelected,
          onCheckAll: _checkAll,
        ),
        SizedBox(height: context.rs(8)),
        SizedBox(
          height: context.rs(54),
          child: Center(child: _buildStrip(strings, game)),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final board = _buildBoard(game);
              final padWidth = _padWidth(context, game, constraints.maxWidth);

              // Wide enough and the keys move to the side, which is what keeps
              // a 25×25 board as tall as the window rather than as tall as
              // whatever the keys left over.
              if (constraints.maxWidth >= context.rs(_kSideBySideWidth)) {
                final gap = context.rs(14);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // The board is given its own square rather than everything
                    // that is left, so that it and the keys sit together in the
                    // middle instead of at opposite edges of a wide window.
                    SizedBox(
                      width: _boardSide(
                        context,
                        game,
                        width: constraints.maxWidth - padWidth - gap,
                        height: constraints.maxHeight,
                      ),
                      child: board,
                    ),
                    SizedBox(width: gap),
                    SizedBox(
                      width: padWidth,
                      child: _buildPad(
                        strings,
                        game,
                        maxHeight: constraints.maxHeight * 0.62,
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Expanded(child: board),
                  SizedBox(height: context.rs(10)),
                  // Only the keys are held to the width of the pad; the
                  // switches above them may use the whole line, which is what
                  // keeps them on one row on a phone.
                  _buildPad(
                    strings,
                    game,
                    maxHeight: constraints.maxHeight * _kPadHeightShare,
                    keypadWidth: math.min(padWidth, constraints.maxWidth),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// How much of the room on offer the board will actually fill, so that the
  /// space it does not want can be shared out rather than left beside it.
  double _boardSide(
    BuildContext context,
    SudokuGameState game, {
    required double width,
    required double height,
  }) {
    final fitted = math.min(
      math.min(width, height) / game.length,
      context.rs(kSudokuMaxCellSize),
    );
    return math.min(math.min(width, height), (fitted * _zoom) * game.length);
  }

  /// Room enough for a pad of this board's keys, and no more.
  double _padWidth(
    BuildContext context,
    SudokuGameState game,
    double available,
  ) {
    final columns = game.size.boxWidth;
    return math.min(
      available,
      context.rs(64) * columns + context.rs(6) * (columns - 1),
    );
  }

  Widget _buildPad(
    AppStrings strings,
    SudokuGameState game, {
    required double maxHeight,
    double? keypadWidth,
  }) {
    final notesMode = ref.watch(
      sudokuSettingsProvider.select((settings) => settings.notesMode),
    );
    final controller = ref.read(sudokuGameProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SudokuPadActions(
          strings: strings,
          enabled: game.isPlaying,
          notesMode: notesMode,
          onNotes: () {
            _closeDigitPair();
            controller.toggleNotesMode();
          },
          onErase: () {
            _closeDigitPair();
            if (_hasSelection(game)) controller.erase();
          },
          zoom: _zoom,
          showZoom: game.length >= _kZoomableFrom,
          canZoomIn: _canZoom(game, by: 1),
          canZoomOut: _canZoom(game, by: -1),
          onZoomIn: () => _stepZoom(1),
          onZoomOut: () => _stepZoom(-1),
        ),
        SizedBox(height: context.rs(10)),
        Flexible(
          child: SizedBox(
            width: keypadWidth,
            child: SudokuKeypad(
              size: game.size,
              enabled: game.isPlaying,
              notesMode: notesMode,
              remaining: [
                for (var value = 1; value <= game.length; value++)
                  game.remainingOf(value),
              ],
              maxHeight: maxHeight,
              onValue: (value) {
                _closeDigitPair();
                if (_hasSelection(game)) controller.enter(value);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBoard(SudokuGameState game) {
    final controller = ref.read(sudokuGameProvider.notifier);
    Widget board = SudokuBoardView(
      game: game,
      zoom: _zoom,
      onCellTap: (index) {
        _closeDigitPair();
        controller.select(index);
      },
    );

    // The board takes a bow once it is full, however it got there.
    if (game.isFinished) {
      final palette = SudokuPalette.of(context);
      board = board
          .animate(key: ValueKey('over-${game.round}'))
          .shimmer(
            duration: 1400.ms,
            color: (game.isSolved ? palette.correct : palette.revealedText)
                .withValues(alpha: 0.4),
            padding: 0,
          );
    }
    return board;
  }

  Widget _buildStrip(AppStrings strings, SudokuGameState game) {
    final palette = SudokuPalette.of(context);
    final message = _message;

    final Widget child;
    if (game.isFinished) {
      child = SudokuResultBanner(
        key: ValueKey('result-${game.round}'),
        strings: strings,
        solved: game.isSolved,
        size: game.size,
        difficulty: game.puzzle.difficulty,
        solvedForYou: game.hintsUsed,
        onNewGame: ref.read(sudokuGameProvider.notifier).newGame,
      );
    } else if (message != null) {
      child = SudokuToast(
        key: ValueKey('message-$_messageToken'),
        message: message.text,
        icon: message.icon,
        accent: switch (message.tone) {
          _Tone.good => palette.correct,
          _Tone.bad => palette.wrong,
          _Tone.neutral => context.decor.accentColor,
        },
      );
    } else {
      child = SudokuStatusLine(
        strings: strings,
        remaining: game.emptyCount,
        wrong: game.wrongCount,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: FittedBox(fit: BoxFit.scaleDown, child: child),
    );
  }

  Widget _buildError(AppStrings strings) {
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
            strings.sudokuLoadFailed,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: decor.subtleTextColor),
          ),
          SizedBox(height: context.rs(12)),
          TextButton(
            onPressed: ref.read(sudokuGameProvider.notifier).newGame,
            child: Text(strings.sudokuRetry),
          ),
        ],
      ),
    );
  }
}

/// Which colour a message wears.
enum _Tone { good, bad, neutral }

/// One line about what just happened, or about what is needed first.
class _Message {
  const _Message({required this.text, required this.icon, required this.tone});

  final String text;
  final IconData icon;
  final _Tone tone;
}
