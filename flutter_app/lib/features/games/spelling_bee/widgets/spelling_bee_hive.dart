import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/layout/responsive_scale.dart';
import '../../../../core/theme/app_theme_extension.dart';
import 'spelling_bee_palette.dart';

/// Height of a pointy-top hexagon relative to its width, `2 / sqrt(3)`.
const double _hexAspect = 1.1547005383792517;

/// How far the six outer tiles sit from their touching position, so the hive
/// reads as seven tiles rather than one honeycomb.
const double _spread = 1.07;

/// The seven letters, the centre one the odd tile out.
///
/// Tiles are clipped to their hexagon rather than drawn inside a box, which
/// means the clip decides what a tap hits too: the corners between two tiles
/// belong to neither, exactly as they look.
class SpellingBeeHive extends StatelessWidget {
  const SpellingBeeHive({
    super.key,
    required this.centerLetter,
    required this.outerLetters,
    required this.enabled,
    required this.onLetter,
    required this.pressedLetter,
    required this.pressToken,
    required this.shuffleToken,
    required this.round,
  });

  final String centerLetter;
  final List<String> outerLetters;
  final bool enabled;
  final ValueChanged<String> onLetter;

  /// The letter that was last entered, however it was entered. Typing on a
  /// physical keyboard lights up the tile the same way tapping it does.
  final String? pressedLetter;

  /// Changes with every letter entered, so repeating one replays the tile's
  /// press animation instead of leaving it still.
  final int pressToken;

  /// Changes whenever the outer letters are rearranged.
  final int shuffleToken;

  /// The current puzzle, so a new one deals the tiles in again.
  final int round;

  @override
  Widget build(BuildContext context) {
    if (centerLetter.isEmpty) return const SizedBox.shrink();
    final palette = SpellingBeePalette.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final byWidth = constraints.maxWidth / (2 * _spread + 1);
        final byHeight =
            constraints.maxHeight / (_hexAspect * (1.5 * _spread + 1));
        // The cap leaves room below the hive for the buttons, which are what
        // a player reaches for after the letters.
        final width = math.min(math.min(byWidth, byHeight), context.rs(102));
        final height = width * _hexAspect;
        final center = Offset(
          width * (2 * _spread + 1) / 2,
          height * (1.5 * _spread + 1) / 2,
        );

        // Clockwise from the top right, which is the order the letters are
        // handed over in and the order they animate in.
        final places = <Offset>[
          Offset(width * _spread / 2, -height * 0.75 * _spread),
          Offset(width * _spread, 0),
          Offset(width * _spread / 2, height * 0.75 * _spread),
          Offset(-width * _spread / 2, height * 0.75 * _spread),
          Offset(-width * _spread, 0),
          Offset(-width * _spread / 2, -height * 0.75 * _spread),
        ];

        return SizedBox(
          width: center.dx * 2,
          height: center.dy * 2,
          child: Stack(
            children: [
              for (var i = 0; i < outerLetters.length && i < places.length; i++)
                _place(
                  center: center,
                  offset: places[i],
                  width: width,
                  height: height,
                  child: _tile(
                    context: context,
                    palette: palette,
                    letter: outerLetters[i],
                    isCenter: false,
                    width: width,
                    height: height,
                    order: i + 1,
                  ),
                ),
              _place(
                center: center,
                offset: Offset.zero,
                width: width,
                height: height,
                child: _tile(
                  context: context,
                  palette: palette,
                  letter: centerLetter,
                  isCenter: true,
                  width: width,
                  height: height,
                  order: 0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _place({
    required Offset center,
    required Offset offset,
    required double width,
    required double height,
    required Widget child,
  }) {
    return Positioned(
      left: center.dx + offset.dx - width / 2,
      top: center.dy + offset.dy - height / 2,
      width: width,
      height: height,
      child: child,
    );
  }

  Widget _tile({
    required BuildContext context,
    required SpellingBeePalette palette,
    required String letter,
    required bool isCenter,
    required double width,
    required double height,
    required int order,
  }) {
    Widget tile = _HexTile(
      letter: letter,
      isCenter: isCenter,
      width: width,
      height: height,
      palette: palette,
      shuffleToken: shuffleToken,
      order: order,
      onTap: enabled ? () => onLetter(letter) : null,
    );

    // The tile the last letter came from takes the keystroke, whether it was
    // tapped or typed.
    if (pressedLetter == letter && pressToken > 0) {
      tile = tile
          .animate(key: ValueKey('press-$pressToken'))
          .scaleXY(
            begin: 0.84,
            end: 1,
            duration: 320.ms,
            curve: Curves.elasticOut,
          )
          .shimmer(
            duration: 420.ms,
            color: (isCenter ? Colors.white : palette.normal).withValues(
              alpha: 0.55,
            ),
            padding: 0,
          );
    }

    // A new puzzle deals the tiles in from the middle outwards.
    return tile
        .animate(key: ValueKey('deal-$round-$order'))
        .fadeIn(duration: 260.ms, delay: (60 * order).ms)
        .scaleXY(
          begin: 0.5,
          end: 1,
          duration: 420.ms,
          delay: (60 * order).ms,
          curve: Curves.easeOutBack,
        );
  }
}

class _HexTile extends StatefulWidget {
  const _HexTile({
    required this.letter,
    required this.isCenter,
    required this.width,
    required this.height,
    required this.palette,
    required this.shuffleToken,
    required this.order,
    required this.onTap,
  });

  final String letter;
  final bool isCenter;
  final double width;
  final double height;
  final SpellingBeePalette palette;
  final int shuffleToken;
  final int order;
  final VoidCallback? onTap;

  @override
  State<_HexTile> createState() => _HexTileState();
}

class _HexTileState extends State<_HexTile> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final decor = context.decor;
    final enabled = widget.onTap != null;
    final background = widget.isCenter ? palette.centerHex : palette.outerHex;
    final foreground = widget.isCenter ? palette.onCenter : palette.hexText;
    final clipper = _HexClipper(corner: widget.width * 0.12);

    Widget letter = Text(
      widget.letter,
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        fontSize: widget.width * 0.4,
        fontWeight: FontWeight.w800,
        height: 1,
        letterSpacing: 1,
        color: foreground,
      ),
    );

    // Shuffling swaps the letters underneath the tiles, so they fade back in
    // one after another while the hive itself stays put.
    if (widget.shuffleToken > 0 && !widget.isCenter) {
      letter = letter
          .animate(key: ValueKey('shuffle-${widget.shuffleToken}'))
          .fadeIn(duration: 200.ms, delay: (40 * widget.order).ms)
          .scaleXY(
            begin: 0.4,
            end: 1,
            duration: 340.ms,
            delay: (40 * widget.order).ms,
            curve: Curves.easeOutBack,
          )
          .rotate(begin: -0.06, end: 0, duration: 340.ms);
    }

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : (_hovered && enabled ? 1.04 : 1),
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: ClipPath(
          clipper: clipper,
          child: Material(
            // A finished round only takes the tiles out of play; dimming them
            // any further would make the hive look broken rather than done.
            color: background.withValues(alpha: enabled ? 1 : 0.82),
            child: InkWell(
              onTap: widget.onTap,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              // Keep the board focused so physical typing survives a tap here.
              canRequestFocus: false,
              splashColor: (widget.isCenter ? Colors.white : decor.accentColor)
                  .withValues(alpha: 0.3),
              highlightColor: Colors.white.withValues(alpha: 0.08),
              child: Center(child: letter),
            ),
          ),
        ),
      ),
    );
  }
}

/// A pointy-top hexagon with softened corners.
class _HexClipper extends CustomClipper<Path> {
  const _HexClipper({required this.corner});

  final double corner;

  static const List<Offset> _vertices = [
    Offset(0.5, 0),
    Offset(1, 0.25),
    Offset(1, 0.75),
    Offset(0.5, 1),
    Offset(0, 0.75),
    Offset(0, 0.25),
  ];

  @override
  Path getClip(Size size) {
    final points = [
      for (final vertex in _vertices)
        Offset(vertex.dx * size.width, vertex.dy * size.height),
    ];
    final path = Path();

    for (var i = 0; i < points.length; i++) {
      final current = points[i];
      final previous = points[(i - 1 + points.length) % points.length];
      final next = points[(i + 1) % points.length];
      // Stop short of each corner and curve around it instead, so the tile
      // has the soft edge the rest of the app's surfaces have.
      final from = _towards(current, previous, corner);
      final to = _towards(current, next, corner);

      if (i == 0) {
        path.moveTo(from.dx, from.dy);
      } else {
        path.lineTo(from.dx, from.dy);
      }
      path.quadraticBezierTo(current.dx, current.dy, to.dx, to.dy);
    }

    return path..close();
  }

  Offset _towards(Offset from, Offset to, double distance) {
    final delta = to - from;
    final length = delta.distance;
    if (length == 0) return from;
    return from + delta * math.min(distance / length, 0.5);
  }

  @override
  bool shouldReclip(_HexClipper oldClipper) => oldClipper.corner != corner;
}
