import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../domain/wordle_models.dart';
import 'wordle_palette.dart';

/// A single board cell.
///
/// While [flip] runs the tile turns around its horizontal axis and swaps to
/// the scored face at the halfway point, which is the moment the colour is
/// given away.
class WordleTile extends StatelessWidget {
  const WordleTile({
    super.key,
    required this.letter,
    required this.size,
    required this.palette,
    this.status,
    this.flip,
    this.flipStart = 0,
    this.flipEnd = 1,
    this.selected = false,
    this.isSolution = false,
    this.onTap,
  });

  final String letter;
  final double size;
  final WordlePalette palette;

  /// `null` while the tile is still unscored (empty or being typed).
  final LetterStatus? status;

  /// Progress of the whole row's reveal; `null` means the tile is already in
  /// its final state.
  final Animation<double>? flip;

  /// The slice of [flip] during which this tile turns over.
  final double flipStart;
  final double flipEnd;

  final bool selected;
  final bool isSolution;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final animation = flip;
    final tile = animation == null
        ? _face(context, revealed: status != null)
        : AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final span = math.max(flipEnd - flipStart, 0.0001);
              final t = Curves.easeInOut.transform(
                ((animation.value - flipStart) / span).clamp(0.0, 1.0),
              );
              final revealed = t >= 0.5;
              // Past the halfway point the tile keeps turning towards the
              // viewer instead of away, so the scored face is never mirrored.
              final angle = (revealed ? t - 1 : t) * math.pi;

              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0016)
                  ..rotateX(angle),
                child: _face(context, revealed: revealed),
              );
            },
          );

    if (onTap == null) return tile;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: tile,
    );
  }

  Widget _face(BuildContext context, {required bool revealed}) {
    final scored = revealed ? status : null;
    final Color background;
    if (scored != null) {
      background = palette.colorFor(scored);
    } else if (selected) {
      // The caret reads as a tinted, glowing slot rather than a bare outline.
      background = palette.activeBorder.withValues(alpha: 0.1);
    } else {
      background = Colors.transparent;
    }
    final Color borderColor;
    if (scored != null) {
      borderColor = isSolution ? palette.activeBorder : background;
    } else if (selected) {
      borderColor = palette.activeBorder;
    } else if (letter.isNotEmpty) {
      borderColor = palette.filledBorder;
    } else {
      borderColor = palette.emptyBorder;
    }

    final content = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.16),
        border: Border.all(
          color: borderColor,
          width: selected && scored == null ? 2.5 : 2,
        ),
        boxShadow: selected && scored == null
            ? [
                BoxShadow(
                  color: palette.activeBorder.withValues(alpha: 0.22),
                  blurRadius: size * 0.18,
                  spreadRadius: size * 0.01,
                ),
              ]
            : null,
      ),
      child: Text(
        letter,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontSize: size * 0.5,
          fontWeight: FontWeight.w700,
          height: 1,
          letterSpacing: 0,
          color: scored == null ? palette.tileText : palette.onFilled,
        ),
      ),
    );

    // A short pop confirms the keystroke while a row is being typed.
    if (flip == null && scored == null && letter.isNotEmpty) {
      return content
          .animate(key: ValueKey('pop-$letter'))
          .scaleXY(begin: 0.88, end: 1, duration: 110.ms, curve: Curves.easeOut);
    }
    return content;
  }
}
