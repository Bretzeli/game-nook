import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/layout/responsive_scale.dart';
import '../../../../core/theme/app_theme_extension.dart';

/// A short line in the strip under the board — why a guess was turned down,
/// or where the round stands.
class WordleMessagePill extends StatelessWidget {
  const WordleMessagePill({
    super.key,
    required this.message,
    this.icon,
    this.accent,
  });

  final String message;
  final IconData? icon;

  /// Tints the outline, glow and icon; the theme's second accent when `null`.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final theme = Theme.of(context);
    final color = accent ?? decor.accentSecondary;

    return Container(
          constraints: BoxConstraints(maxWidth: context.rs(340)),
          padding: EdgeInsets.symmetric(
            horizontal: context.rs(16),
            vertical: context.rs(10),
          ),
          decoration: BoxDecoration(
            color: decor.cardColor,
            borderRadius: decor.buttonRadius,
            border: Border.all(color: color.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.18),
                blurRadius: context.rs(18),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: context.rs(16), color: color),
                SizedBox(width: context.rs(8)),
              ],
              Flexible(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 180.ms)
        .slideY(begin: 0.35, end: 0, curve: Curves.easeOut);
  }
}
