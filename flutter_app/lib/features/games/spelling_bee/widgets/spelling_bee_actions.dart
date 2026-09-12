import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/layout/responsive_scale.dart';
import '../../../../core/theme/app_theme_extension.dart';
import 'spelling_bee_palette.dart';

/// Delete, shuffle and enter — the three things to do with a typed word.
class SpellingBeeActions extends StatelessWidget {
  const SpellingBeeActions({
    super.key,
    required this.strings,
    required this.canDelete,
    required this.canSubmit,
    required this.canShuffle,
    required this.shuffleToken,
    required this.onDelete,
    required this.onShuffle,
    required this.onSubmit,
  });

  final AppStrings strings;
  final bool canDelete;
  final bool canSubmit;
  final bool canShuffle;

  /// Changes with every shuffle, to spin the button along with the hive.
  final int shuffleToken;

  final VoidCallback onDelete;
  final VoidCallback onShuffle;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final palette = SpellingBeePalette.of(context);

    Widget shuffleIcon = Icon(
      Icons.autorenew_rounded,
      size: context.rs(24),
      color: context.decor.subtleTextColor,
    );
    if (shuffleToken > 0) {
      shuffleIcon = shuffleIcon
          .animate(key: ValueKey('spin-$shuffleToken'))
          .rotate(begin: -1, end: 0, duration: 620.ms, curve: Curves.easeOutBack);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ActionButton(
          label: strings.spellingBeeDelete,
          onTap: canDelete ? onDelete : null,
        ),
        SizedBox(width: context.rs(14)),
        _ActionButton(
          tooltip: strings.spellingBeeShuffle,
          icon: shuffleIcon,
          onTap: canShuffle ? onShuffle : null,
        ),
        SizedBox(width: context.rs(14)),
        _ActionButton(
          label: strings.spellingBeeEnter,
          accent: palette.normal,
          onTap: canSubmit ? onSubmit : null,
        ),
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    this.label,
    this.icon,
    this.tooltip,
    this.accent,
    required this.onTap,
  });

  final String? label;
  final Widget? icon;
  final String? tooltip;

  /// Set on the button that submits, so the one that scores stands out.
  final Color? accent;

  final VoidCallback? onTap;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final theme = Theme.of(context);
    final enabled = widget.onTap != null;
    final accent = widget.accent ?? decor.subtleTextColor;
    final highlight = _hovered && enabled;

    Widget button = AnimatedScale(
      scale: _pressed && enabled ? 0.94 : 1,
      duration: const Duration(milliseconds: 120),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: widget.icon != null ? context.rs(18) : context.rs(26),
          vertical: context.rs(14),
        ),
        decoration: BoxDecoration(
          color: highlight
              ? accent.withValues(alpha: 0.14)
              : decor.cardColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(context.rs(28)),
          border: Border.all(
            color: highlight ? accent : decor.subtleNavBorder,
            width: 0.5,
          ),
        ),
        child:
            widget.icon ??
            Text(
              widget.label!,
              style: theme.textTheme.labelLarge?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: widget.accent ?? decor.subtleTextColor,
              ),
            ),
      ),
    );

    if (!enabled) button = Opacity(opacity: 0.45, child: button);
    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: button,
      ),
    );
  }
}
