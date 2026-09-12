import 'package:flutter/material.dart';

import '../core/layout/responsive_scale.dart';
import '../core/theme/app_theme_extension.dart';

/// The accented button a result banner ends with, filled or outlined according
/// to what the active theme does with its buttons.
class GameActionButton extends StatefulWidget {
  const GameActionButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  State<GameActionButton> createState() => _GameActionButtonState();
}

class _GameActionButtonState extends State<GameActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final theme = Theme.of(context);
    final filled = decor.buttonStyle != AppButtonStyle.outlined;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: context.rs(14),
            vertical: context.rs(9),
          ),
          decoration: BoxDecoration(
            color: filled
                ? decor.accentColor.withValues(alpha: _hovered ? 1 : 0.85)
                : decor.accentColor.withValues(alpha: _hovered ? 0.2 : 0.1),
            borderRadius: decor.buttonRadius,
            border: Border.all(color: decor.accentColor, width: 1),
          ),
          child: Text(
            widget.label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: filled ? Colors.white : decor.accentColor,
            ),
          ),
        ),
      ),
    );
  }
}
