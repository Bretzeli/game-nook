import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme_extension.dart';
import '../domain/wordle_alphabet.dart';
import '../domain/wordle_models.dart';
import 'wordle_palette.dart';

/// On-screen keyboard that mirrors the hints: every key carries the best
/// status its letter has been scored with so far.
class WordleKeyboard extends StatelessWidget {
  const WordleKeyboard({
    super.key,
    required this.languageCode,
    required this.statuses,
    required this.enabled,
    required this.onLetter,
    required this.onBackspace,
    required this.onEnter,
  });

  final String languageCode;
  final Map<String, LetterStatus> statuses;
  final bool enabled;
  final ValueChanged<String> onLetter;
  final VoidCallback onBackspace;
  final VoidCallback onEnter;

  static const _qwerty = ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'];
  static const _qwertz = ['QWERTZUIOPÜ', 'ASDFGHJKLÖÄ', 'YXCVBNMß'];

  List<String> get _layout =>
      WordleAlphabet.isGerman(languageCode) ? _qwertz : _qwerty;

  @override
  Widget build(BuildContext context) {
    final palette = WordlePalette.of(context);
    final rows = _layout;
    final widestRow = rows
        .map((row) => row.length)
        .reduce((a, b) => math.max(a, b));

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = math.max(3.0, constraints.maxWidth * 0.006);
        // The bottom row carries two wide action keys next to its letters.
        final unitsInBottomRow = rows.last.length + 3;
        final units = math.max(widestRow, unitsInBottomRow).toDouble();
        final keyWidth =
            (constraints.maxWidth - gap * (units - 1)) / units;
        final keyHeight = math.min(keyWidth * 1.6, 68.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0) SizedBox(height: gap),
              _buildRow(
                context: context,
                palette: palette,
                letters: rows[index],
                isLast: index == rows.length - 1,
                keyWidth: keyWidth,
                keyHeight: keyHeight,
                gap: gap,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRow({
    required BuildContext context,
    required WordlePalette palette,
    required String letters,
    required bool isLast,
    required double keyWidth,
    required double keyHeight,
    required double gap,
  }) {
    final keys = <Widget>[];

    if (isLast) {
      keys.add(
        _WordleKey(
          palette: palette,
          width: keyWidth * 1.5 + gap * 0.5,
          height: keyHeight,
          onTap: enabled ? onEnter : null,
          icon: Icons.keyboard_return_rounded,
        ),
      );
      keys.add(SizedBox(width: gap));
    }

    for (var i = 0; i < letters.length; i++) {
      if (i > 0) keys.add(SizedBox(width: gap));
      final letter = letters[i];
      keys.add(
        _WordleKey(
          palette: palette,
          width: keyWidth,
          height: keyHeight,
          label: letter,
          status: statuses[letter],
          onTap: enabled ? () => onLetter(letter) : null,
        ),
      );
    }

    if (isLast) {
      keys.add(SizedBox(width: gap));
      keys.add(
        _WordleKey(
          palette: palette,
          width: keyWidth * 1.5 + gap * 0.5,
          height: keyHeight,
          onTap: enabled ? onBackspace : null,
          icon: Icons.backspace_outlined,
        ),
      );
    }

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: keys);
  }
}

class _WordleKey extends StatelessWidget {
  const _WordleKey({
    required this.palette,
    required this.width,
    required this.height,
    required this.onTap,
    this.label,
    this.icon,
    this.status,
  });

  final WordlePalette palette;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final String? label;
  final IconData? icon;
  final LetterStatus? status;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final background = switch (status) {
      null => palette.keyIdle,
      LetterStatus.absent => palette.keyAbsentBackground,
      _ => palette.colorFor(status!),
    };
    final foreground = switch (status) {
      null => palette.keyText,
      LetterStatus.absent => palette.keyAbsentText,
      _ => palette.onFilled,
    };
    final radius = BorderRadius.circular(math.min(decor.buttonBorderRadius, 10));

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          // Keep the board focused so physical typing survives a tap here.
          canRequestFocus: false,
          splashColor: decor.accentColor.withValues(alpha: 0.22),
          highlightColor: decor.accentColor.withValues(alpha: 0.1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background.withValues(alpha: onTap == null ? 0.5 : 1),
              borderRadius: radius,
              border: Border.all(
                color: switch (status) {
                  null => decor.cardBorderColor.withValues(alpha: 0.6),
                  // A faint edge keeps a ruled-out key readable as a key,
                  // rather than a flat patch melting into the background.
                  LetterStatus.absent => Colors.black.withValues(alpha: 0.18),
                  _ => Colors.transparent,
                },
                width: 1,
              ),
            ),
            child: icon != null
                ? Icon(icon, size: height * 0.42, color: foreground)
                : Text(
                    label!,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: math.min(height * 0.4, width * 0.52),
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: foreground,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
