import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/layout/responsive_scale.dart';
import 'spelling_bee_palette.dart';

/// The word being typed, with a blinking caret behind it.
///
/// Letters the hive does not offer are shown greyed out rather than refused
/// as they are typed: a player who mistypes sees what went wrong instead of
/// watching keys do nothing.
class SpellingBeeInput extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final palette = SpellingBeePalette.of(context);
    final fontSize = context.rs(30);

    Widget line = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < input.length; i++)
          _letter(context, palette, input[i], i, fontSize),
        if (showCaret) _caret(palette, fontSize),
      ],
    );

    if (shakeToken > 0) {
      line = line
          .animate(key: ValueKey('reject-$shakeToken'))
          .shakeX(duration: 420.ms, hz: 5.5, amount: 5)
          .tint(
            color: palette.error,
            begin: 0.9,
            end: 0,
            duration: 560.ms,
            curve: Curves.easeOut,
          );
    }

    return SizedBox(
      height: fontSize * 1.5,
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: leavingWasRejected ? 240 : 300),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        // An accepted word leaves upwards, towards the bars it just filled;
        // one that spells nothing shrinks away where it stands.
        transitionBuilder: (child, animation) {
          final faded = FadeTransition(opacity: animation, child: child);
          if (leavingWasRejected) {
            return ScaleTransition(
              scale: Tween<double>(begin: 0.82, end: 1).animate(animation),
              child: faded,
            );
          }
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.7),
              end: Offset.zero,
            ).animate(animation),
            child: faded,
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
    BuildContext context,
    SpellingBeePalette palette,
    String letter,
    int index,
    double fontSize,
  ) {
    final Color color;
    if (letter == centerLetter) {
      color = palette.normal;
    } else if (letters.contains(letter)) {
      color = palette.inputText;
    } else {
      color = palette.inputMuted;
    }

    return Text(
          letter,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: 1.5,
            color: color,
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
