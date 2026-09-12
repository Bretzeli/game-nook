import 'dart:async';

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

/// The widest the keypad is allowed to spread, so its keys stay a handful
/// rather than a row across a desktop.
const double _kMaxKeypadWidth = 520;

/// Numpad keys carry their own logical keys, and their labels ("Numpad 7") are
/// not the single glyph the board is after.
final Map<LogicalKeyboardKey, int> _kNumpadValues = {
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

  @override
  void dispose() {
    _messageTimer?.cancel();
    _markTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _onGameChanged(SudokuGameState? previous, SudokuGameState next) {
    if (previous != null && previous.round == next.round) return;
    // A new board: nothing from the last one should still be on screen.
    _messageTimer?.cancel();
    _markTimer?.cancel();
    setState(() => _message = null);
  }

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

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;

    final game = ref.read(sudokuGameProvider);
    if (!game.isPlaying) return KeyEventResult.ignored;

    final controller = ref.read(sudokuGameProvider.notifier);
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowUp) {
      controller.moveSelection(rows: -1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      controller.moveSelection(rows: 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      controller.moveSelection(columns: -1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      controller.moveSelection(columns: 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      if (_hasSelection(game)) controller.erase();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      controller.clearSelection();
      return KeyEventResult.handled;
    }
    // Nothing on the board needs a space, and reaching for the notes is the
    // thing a player does most often.
    if (key == LogicalKeyboardKey.space) {
      controller.toggleNotesMode();
      return KeyEventResult.handled;
    }

    final value = _valueOf(key, game.length);
    if (value == null) return KeyEventResult.ignored;
    if (!_hasSelection(game)) return KeyEventResult.handled;

    // Shift writes a single pencil mark without having to switch modes.
    if (HardwareKeyboard.instance.isShiftPressed) {
      controller.toggleNote(value);
    } else {
      controller.enter(value);
    }
    return KeyEventResult.handled;
  }

  /// The value a key stands for. The key's own label is used rather than the
  /// character it produced, so that holding shift still reads as a 1 and not
  /// as whatever the layout puts above it.
  int? _valueOf(LogicalKeyboardKey key, int length) {
    final numpad = _kNumpadValues[key];
    if (numpad != null) return numpad <= length ? numpad : null;

    final label = key.keyLabel;
    return label.length == 1 ? sudokuValueOf(label, length) : null;
  }

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
    final notesMode = ref.watch(
      sudokuSettingsProvider.select((settings) => settings.notesMode),
    );
    final controller = ref.read(sudokuGameProvider.notifier);

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
        Expanded(child: _buildBoard(game, controller)),
        SizedBox(height: context.rs(12)),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.rs(_kMaxKeypadWidth)),
            child: SudokuKeypad(
              strings: strings,
              length: game.length,
              enabled: game.isPlaying,
              notesMode: notesMode,
              remaining: [
                for (var value = 1; value <= game.length; value++)
                  game.remainingOf(value),
              ],
              onValue: (value) {
                if (_hasSelection(game)) controller.enter(value);
              },
              onErase: () {
                if (_hasSelection(game)) controller.erase();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBoard(SudokuGameState game, SudokuController controller) {
    Widget board = SudokuBoardView(game: game, onCellTap: controller.select);

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
  const _Message({
    required this.text,
    required this.icon,
    required this.tone,
  });

  final String text;
  final IconData icon;
  final _Tone tone;
}
