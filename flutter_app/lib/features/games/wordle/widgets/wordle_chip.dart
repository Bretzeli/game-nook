import 'package:flutter/material.dart';

import '../../../../core/layout/responsive_scale.dart';
import '../../../../core/theme/app_theme_extension.dart';

/// Pill-shaped control in the same style as the nav bar selectors.
class WordleChip extends StatefulWidget {
  const WordleChip({
    super.key,
    required this.label,
    this.icon,
    this.trailingIcon,
    this.onTap,
    this.active = false,
    this.enabled = true,
  });

  final String label;
  final IconData? icon;
  final IconData? trailingIcon;
  final VoidCallback? onTap;

  /// Renders the chip in its "switched on" state (used by hard mode).
  final bool active;

  final bool enabled;

  @override
  State<WordleChip> createState() => _WordleChipState();
}

class _WordleChipState extends State<WordleChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final theme = Theme.of(context);
    final highlight = widget.active || (_hovered && widget.enabled);
    final foreground = widget.enabled
        ? (widget.active ? decor.accentColor : decor.subtleTextColor)
        : decor.subtleTextColor.withValues(alpha: 0.4);

    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(
        horizontal: context.rs(10),
        vertical: context.rs(7),
      ),
      decoration: BoxDecoration(
        color: highlight
            ? decor.accentColor.withValues(alpha: widget.active ? 0.16 : 0.1)
            : decor.cardColor.withValues(alpha: 0.5),
        borderRadius: decor.buttonRadius,
        border: Border.all(
          color: highlight ? decor.accentColor : decor.subtleNavBorder,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: context.rs(15), color: foreground),
            SizedBox(width: context.rs(6)),
          ],
          Text(
            widget.label,
            style: theme.textTheme.labelLarge?.copyWith(color: foreground),
          ),
          if (widget.trailingIcon != null) ...[
            SizedBox(width: context.rs(2)),
            Icon(widget.trailingIcon, size: context.rs(15), color: foreground),
          ],
        ],
      ),
    );

    if (!widget.enabled) return Opacity(opacity: 0.6, child: chip);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.onTap == null
          ? chip
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: chip,
            ),
    );
  }
}
