import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/layout/responsive_scale.dart';
import 'spelling_bee_palette.dart';

/// The word being typed, with a blinking caret behind it.
///
/// Letters the hive does not offer are shown greyed out rather than refused
/// as they are typed: a player who mistypes sees what went wrong instead of
/// watching keys do nothing.
class SpellingBeeInput extends StatefulWidget {
  const SpellingBeeInput({
    super.key,
    required this.input,
    required this.letters,
    required this.centerLetter,
    required this.shakeToken,
    required this.lineToken,
    required this.leavingWasRejected,
    required this.showCaret,
  });

  final String input;

  /// The seven letters of the hive.
  final Set<String> letters;
  final String centerLetter;

  /// Changes whenever a word was turned down, to replay the nudge.
  final int shakeToken;

  /// Changes whenever a word leaves the line, however it left.
  final int lineToken;

  /// `true` when the word leaving was turned down rather than scored.
  final bool leavingWasRejected;

  final bool showCaret;

  @override
  State<SpellingBeeInput> createState() => _SpellingBeeInputState();
}

class _SpellingBeeInputState extends State<SpellingBeeInput>
    with TickerProviderStateMixin {
  /// Drives a single shake that settles on its own.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );

  /// How far the letters have turned to the error colour. It stays there
  /// while the word waits to be taken off, so the word leaves as it was
  /// judged instead of flashing back to normal on its way out.
  late final AnimationController _tint = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    reverseDuration: const Duration(milliseconds: 220),
  );

  /// The line the last rejection belongs to. Only that line shakes and turns
  /// red — the empty line replacing it must not inherit either.
  int? _rejectedLine;

  @override
  void didUpdateWidget(SpellingBeeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shakeToken != oldWidget.shakeToken && widget.shakeToken > 0) {
      _rejectedLine = widget.lineToken;
      _shake.forward(from: 0);
      _tint.forward();
    } else if (widget.lineToken == oldWidget.lineToken &&
        widget.lineToken == _rejectedLine &&
        widget.input != oldWidget.input) {
      // The player went back to the word before it was taken off: it is
      // theirs again, and no longer wrong.
      _rejectedLine = null;
      _tint.reverse();
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    _tint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = SpellingBeePalette.of(context);
    final fontSize = context.rs(30);
    final input = widget.input;
    final showCaret = widget.showCaret;
    final lineToken = widget.lineToken;

    final line = AnimatedBuilder(
      animation: Listenable.merge([_shake, _tint]),
      builder: (context, _) {
        final rejected = lineToken == _rejectedLine;
        final tint = rejected ? Curves.easeOut.transform(_tint.value) : 0.0;

        // A few swings that shrink to nothing, so the word comes to rest
        // instead of stopping mid-swing.
        var dx = 0.0;
        if (rejected && _shake.isAnimating) {
          final t = _shake.value;
          final decay = math.pow(1 - t, 2).toDouble();
          dx = math.sin(t * math.pi * 2 * 3) * fontSize * 0.22 * decay;
        }

        return Transform.translate(
          offset: Offset(dx, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < input.length; i++)
                _letter(palette, input[i], i, fontSize, tint),
              if (showCaret) _caret(palette, fontSize),
            ],
          ),
        );
      },
    );

    final rejected = widget.leavingWasRejected;

    return SizedBox(
      height: fontSize * 1.5,
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: rejected ? 260 : 300),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        // An accepted word leaves upwards, towards the bars it just filled;
        // one that spells nothing shrinks away where it stands.
        //
        // The wrappers are the same either way, only their values differ:
        // changing the wrappers would rebuild the word on its way out and
        // replay its shake and every letter's pop.
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(
                begin: rejected ? 0.85 : 1,
                end: 1,
              ).animate(animation),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: rejected ? Offset.zero : const Offset(0, -0.7),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(lineToken),
          child: Center(
            child: FittedBox(fit: BoxFit.scaleDown, child: line),
          ),
        ),
      ),
    );
  }

  Widget _letter(
    SpellingBeePalette palette,
    String letter,
    int index,
    double fontSize,
    double tint,
  ) {
    final Color base;
    if (letter == widget.centerLetter) {
      base = palette.normal;
    } else if (widget.letters.contains(letter)) {
      base = palette.inputText;
    } else {
      base = palette.inputMuted;
    }

    return Text(
          letter,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: 1.5,
            color: Color.lerp(base, palette.error, tint),
          ),
        )
        // A short pop confirms the keystroke, replayed whenever the letter in
        // this slot changes.
        .animate(key: ValueKey('typed-$index-$letter'))
        .scaleXY(begin: 0.6, end: 1, duration: 150.ms, curve: Curves.easeOut)
        .fadeIn(duration: 110.ms);
  }

  Widget _caret(SpellingBeePalette palette, double fontSize) {
    return Padding(
      padding: EdgeInsets.only(left: fontSize * 0.06),
      child:
          Container(
                width: fontSize * 0.09,
                height: fontSize,
                decoration: BoxDecoration(
                  color: palette.normal,
                  borderRadius: BorderRadius.circular(fontSize * 0.05),
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .fade(
                begin: 1,
                end: 0.1,
                duration: 620.ms,
                curve: Curves.easeInOut,
              ),
    );
  }
}
