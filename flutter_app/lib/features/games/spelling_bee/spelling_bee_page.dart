import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/app_strings_provider.dart';
import '../../../core/layout/responsive_scale.dart';
import '../../../core/theme/app_theme_extension.dart';
import '../../../core/words/word_alphabet.dart';
import 'domain/spelling_bee_models.dart';
import 'state/spelling_bee_controller.dart';
import 'state/spelling_bee_game_state.dart';
import 'widgets/spelling_bee_actions.dart';
import 'widgets/spelling_bee_found_words.dart';
import 'widgets/spelling_bee_hive.dart';
import 'widgets/spelling_bee_input.dart';
import 'widgets/spelling_bee_message.dart';
import 'widgets/spelling_bee_palette.dart';
import 'widgets/spelling_bee_progress.dart';
import 'widgets/spelling_bee_toolbar.dart';

/// Width from which the found words get a panel of their own beside the hive
/// instead of a single scrolling line above it.
const double _kPanelBreakpoint = 780;

/// How long a word that was turned down stays on the line: long enough to
/// finish its shake and to be read, short enough not to be in the way.
const Duration _kRejectedWordLingers = Duration(milliseconds: 520);

class SpellingBeePage extends ConsumerStatefulWidget {
  const SpellingBeePage({super.key});

  @override
  ConsumerState<SpellingBeePage> createState() => _SpellingBeePageState();
}

class _SpellingBeePageState extends ConsumerState<SpellingBeePage> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'spelling-bee-board');

  /// Changes whenever a word is turned down, so the line can shake again.
  int _shakeToken = 0;

  /// Changes whenever a word leaves the line, so it can animate away.
  int _lineToken = 0;

  /// How the last word left: a word that was turned down fades out where it
  /// stands, an accepted one lifts off towards the bars it just filled.
  bool _lineWasRejected = false;
  Timer? _clearTimer;

  /// The last letter entered, and a token that changes with every letter, so
  /// that its tile lights up whether it was tapped or typed.
  String? _pressedLetter;
  int _pressToken = 0;

  int _shuffleToken = 0;

  _Feedback? _feedback;
  int _feedbackToken = 0;
  Timer? _feedbackTimer;

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _clearTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _onGameChanged(
    SpellingBeeGameState? previous,
    SpellingBeeGameState next,
  ) {
    if (previous != null && previous.round == next.round) return;
    // A new puzzle: nothing that happened in the last one should animate.
    _feedbackTimer?.cancel();
    _clearTimer?.cancel();
    setState(() {
      _shakeToken = 0;
      _lineToken = 0;
      _lineWasRejected = false;
      _pressToken = 0;
      _pressedLetter = null;
      _shuffleToken = 0;
      _feedback = null;
    });
  }

  void _enterLetter(String character) {
    final game = ref.read(spellingBeeGameProvider);
    if (!game.isPlaying) return;

    final letter = WordAlphabet.normalizeChar(character, game.languageCode);
    if (letter == null) return;

    ref.read(spellingBeeGameProvider.notifier).typeLetter(letter);
    if (ref.read(spellingBeeGameProvider).input == game.input) return;

    setState(() {
      _pressedLetter = letter;
      _pressToken++;
    });
  }

  void _shuffle() {
    ref.read(spellingBeeGameProvider.notifier).shuffle();
    setState(() {
      _shuffleToken++;
      // The letters have moved out from under the tiles: the tile that was
      // lit is no longer the one the last letter came from, and none should
      // light up again until a letter is entered.
      _pressedLetter = null;
    });
  }

  void _submit() {
    final controller = ref.read(spellingBeeGameProvider.notifier);
    final strings = ref.read(appStringsProvider);
    final before = ref.read(spellingBeeGameProvider);

    final rejection = controller.submit();
    if (rejection != null) {
      _showFeedback(
        _rejectionFeedback(strings, rejection),
        const Duration(milliseconds: 2400),
      );
      setState(() => _shakeToken++);
      // Whatever was wrong with it, a word that was turned down is taken off
      // the line once it has finished shaking, so the next one can be typed
      // straight away instead of backspaced for.
      _clearAfterShake(before.input);
      return;
    }

    final after = ref.read(spellingBeeGameProvider);
    _replaceLine(rejected: false);
    _showFeedback(
      _rewardFeedback(strings, before, after),
      const Duration(milliseconds: 2000),
    );
  }

  /// Clears [word] off the line, unless the player has started typing again
  /// in the meantime — their new letters are theirs to keep.
  void _clearAfterShake(String word) {
    _clearTimer?.cancel();
    _clearTimer = Timer(_kRejectedWordLingers, () {
      if (!mounted || ref.read(spellingBeeGameProvider).input != word) return;
      ref.read(spellingBeeGameProvider.notifier).clearInput();
      _replaceLine(rejected: true);
    });
  }

  /// Starts the line over. The word on its way out keeps the shake it was
  /// given — the line taking its place must not inherit it, or the bare caret
  /// shakes after the word does, and so does every word accepted afterwards.
  void _replaceLine({required bool rejected}) {
    setState(() {
      _lineToken++;
      _lineWasRejected = rejected;
      _shakeToken = 0;
    });
  }

  void _showFeedback(_Feedback feedback, Duration duration) {
    _feedbackTimer?.cancel();
    setState(() {
      _feedbackToken++;
      _feedback = feedback;
    });
    _feedbackTimer = Timer(duration, () {
      if (mounted) setState(() => _feedback = null);
    });
  }

  _Feedback _rejectionFeedback(AppStrings strings, BeeRejection rejection) {
    final message = switch (rejection.kind) {
      BeeRejectionKind.tooShort => strings.spellingBeeTooShort(
        kBeeMinWordLength,
      ),
      BeeRejectionKind.missingCenter => strings.spellingBeeMissingCenter(
        rejection.letter,
      ),
      BeeRejectionKind.badLetters => strings.spellingBeeBadLetter(
        rejection.letter,
      ),
      BeeRejectionKind.notAWord => strings.spellingBeeNotAWord,
      BeeRejectionKind.alreadyFound => strings.spellingBeeAlreadyFound,
    };
    final icon = switch (rejection.kind) {
      BeeRejectionKind.alreadyFound => Icons.history_rounded,
      BeeRejectionKind.missingCenter => Icons.adjust_rounded,
      _ => Icons.error_outline_rounded,
    };
    return _Feedback(message: message, icon: icon);
  }

  /// What to say about a word that counted: filling a bar beats a pangram
  /// beats a rare find beats plain praise, so the rarest thing that just
  /// happened is the thing the player is told about.
  _Feedback _rewardFeedback(
    AppStrings strings,
    SpellingBeeGameState before,
    SpellingBeeGameState after,
  ) {
    final word = after.found.first;
    final completed = kBeeListedTiers.firstWhere(
      (tier) =>
          after.scoreOf(tier) >= after.maxScoreOf(tier) &&
          before.scoreOf(tier) < before.maxScoreOf(tier),
      orElse: () => BeeTier.bonus,
    );

    if (completed != BeeTier.bonus) {
      return _Feedback(
        message: strings.spellingBeeTierComplete(_tierLabel(strings, completed)),
        icon: Icons.emoji_events_rounded,
        tier: completed,
        points: word.points,
      );
    }
    if (word.isPangram) {
      return _Feedback(
        message: strings.spellingBeePangram,
        icon: Icons.star_rounded,
        tier: word.tier,
        points: word.points,
      );
    }
    if (word.tier == BeeTier.bonus) {
      return _Feedback(
        message: strings.spellingBeeRareFind,
        icon: Icons.auto_awesome_rounded,
        tier: BeeTier.bonus,
        points: word.points,
      );
    }
    return _Feedback(
      message: strings.spellingBeePraise(word.points),
      icon: Icons.check_circle_rounded,
      tier: word.tier,
      points: word.points,
    );
  }

  String _tierLabel(AppStrings strings, BeeTier tier) => switch (tier) {
    BeeTier.normal => strings.spellingBeeTierNormal,
    BeeTier.difficult => strings.spellingBeeTierDifficult,
    BeeTier.bonus => strings.spellingBeeTierBonus,
  };

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;

    final game = ref.read(spellingBeeGameProvider);
    if (!game.isPlaying) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _submit();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      ref.read(spellingBeeGameProvider.notifier).backspace();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      ref.read(spellingBeeGameProvider.notifier).clearInput();
      return KeyEventResult.handled;
    }
    // Space is the one key a word never needs, and reaching for the shuffle
    // is the thing a stuck player does most.
    if (key == LogicalKeyboardKey.space) {
      _shuffle();
      return KeyEventResult.handled;
    }

    final character = event.character;
    if (character != null && character.length == 1) {
      final before = game.input;
      _enterLetter(character);
      if (ref.read(spellingBeeGameProvider).input != before) {
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(spellingBeeGameProvider, _onGameChanged);

    final game = ref.watch(spellingBeeGameProvider);
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
            BeePhase.loading => Center(
              child: CircularProgressIndicator(color: context.decor.accentColor),
            ),
            BeePhase.failed => _buildError(strings),
            BeePhase.playing || BeePhase.finished => _buildGame(strings, game),
          },
        ),
      ),
    );
  }

  Widget _buildGame(AppStrings strings, SpellingBeeGameState game) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _kPanelBreakpoint;
        final board = _buildBoard(strings, game);

        return Column(
          children: [
            SpellingBeeToolbar(canGiveUp: game.canGiveUp),
            SizedBox(height: context.rs(10)),
            _buildProgress(strings, game),
            SizedBox(height: context.rs(8)),
            if (!wide) ...[
              SpellingBeeFoundWords(
                strings: strings,
                found: game.found,
                puzzle: game.puzzle,
                revealed: game.revealed,
                compact: true,
              ),
              SizedBox(height: context.rs(4)),
            ],
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: board),
                        SizedBox(width: context.rs(14)),
                        SizedBox(
                          width: context.rs(232),
                          child: SpellingBeeFoundWords(
                            strings: strings,
                            found: game.found,
                            puzzle: game.puzzle,
                            revealed: game.revealed,
                            compact: false,
                          ),
                        ),
                      ],
                    )
                  : board,
            ),
          ],
        );
      },
    );
  }

  Widget _buildProgress(AppStrings strings, SpellingBeeGameState game) {
    return SpellingBeeProgress(
      strings: strings,
      totalScore: game.totalScore,
      bonusScore: game.scoreOf(BeeTier.bonus),
      bonusCount: game.foundCountOf(BeeTier.bonus),
      tiers: [
        for (final tier in kBeeListedTiers)
          BeeTierProgress(
            tier: tier,
            label: _tierLabel(strings, tier),
            hint: tier == BeeTier.normal
                ? strings.spellingBeeNormalHint
                : strings.spellingBeeDifficultHint,
            score: game.scoreOf(tier),
            maxScore: game.maxScoreOf(tier),
            foundWords: game.foundCountOf(tier),
            totalWords: game.puzzle.wordCountOf(tier),
          ),
      ],
    );
  }

  Widget _buildBoard(AppStrings strings, SpellingBeeGameState game) {
    final palette = SpellingBeePalette.of(context);

    Widget hive = SpellingBeeHive(
      centerLetter: game.puzzle.centerLetter,
      outerLetters: game.outerLetters,
      enabled: game.isPlaying,
      onLetter: _enterLetter,
      pressedLetter: _pressedLetter,
      pressToken: _pressToken,
      shuffleToken: _shuffleToken,
      round: game.round,
    );

    // The hive takes a bow when the round is over, whether it was finished or
    // given up on.
    if (game.isFinished) {
      hive = hive
          .animate(key: ValueKey('over-${game.round}'))
          .scaleXY(
            begin: 1.05,
            end: 1,
            duration: 700.ms,
            curve: Curves.elasticOut,
          )
          .shimmer(
            duration: 1400.ms,
            color: palette.normal.withValues(alpha: 0.45),
            padding: 0,
          );
    }

    return Column(
      children: [
        SizedBox(
          height: context.rs(54),
          child: Center(child: _buildStrip(strings, game)),
        ),
        // The line being typed and the hive travel together: whatever room
        // is left over sits above and below the pair, never between them.
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpellingBeeInput(
                input: game.input,
                letters: game.puzzle.letters,
                centerLetter: game.puzzle.centerLetter,
                shakeToken: _shakeToken,
                lineToken: _lineToken,
                leavingWasRejected: _lineWasRejected,
                showCaret: game.isPlaying,
              ),
              SizedBox(height: context.rs(10)),
              Flexible(child: hive),
            ],
          ),
        ),
        SizedBox(height: context.rs(14)),
        SpellingBeeActions(
          strings: strings,
          canDelete: game.isPlaying && game.input.isNotEmpty,
          canSubmit: game.isPlaying && game.input.isNotEmpty,
          canShuffle: game.isPlaying,
          shuffleToken: _shuffleToken,
          onDelete: ref.read(spellingBeeGameProvider.notifier).backspace,
          onShuffle: _shuffle,
          onSubmit: _submit,
        ),
      ],
    );
  }

  Widget _buildStrip(AppStrings strings, SpellingBeeGameState game) {
    final palette = SpellingBeePalette.of(context);
    final feedback = _feedback;

    final Widget child;
    if (game.isFinished) {
      child = SpellingBeeResultBanner(
        key: ValueKey('result-${game.round}'),
        strings: strings,
        complete: !game.revealed,
        score: game.totalScore,
        foundWords: game.found
            .where((word) => word.tier != BeeTier.bonus)
            .length,
        totalWords: game.puzzle.listedWords.length,
        onNewGame: ref.read(spellingBeeGameProvider.notifier).newGame,
      );
    } else if (feedback != null) {
      child = SpellingBeeToast(
        key: ValueKey('feedback-$_feedbackToken'),
        message: feedback.message,
        icon: feedback.icon,
        points: feedback.points,
        accent: feedback.tier == null
            ? palette.error
            : palette.colorFor(feedback.tier!),
      );
    } else {
      child = const SizedBox.shrink();
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
            strings.spellingBeeLoadFailed,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: decor.subtleTextColor),
          ),
          SizedBox(height: context.rs(12)),
          TextButton(
            onPressed: ref.read(spellingBeeGameProvider.notifier).newGame,
            child: Text(strings.spellingBeeRetry),
          ),
        ],
      ),
    );
  }
}

/// One line of feedback about the word that was just submitted.
class _Feedback {
  const _Feedback({
    required this.message,
    required this.icon,
    this.tier,
    this.points,
  });

  final String message;
  final IconData icon;

  /// The colour to wear — `null` when the word was turned down.
  final BeeTier? tier;

  final int? points;
}
