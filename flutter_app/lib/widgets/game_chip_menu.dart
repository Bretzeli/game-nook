import 'package:flutter/material.dart';

import '../core/layout/responsive_scale.dart';
import '../core/theme/app_theme_extension.dart';

/// One choice in a [GameChipMenu].
class GameMenuOption<T> {
  const GameMenuOption({
    required this.value,
    required this.label,
    this.enabled = true,
    this.disabledHint,
  });

  final T value;
  final String label;

  /// A choice that is shown but cannot be taken — the rule behind it is easier
  /// to see when the option is there and greyed out than when it is missing.
  final bool enabled;

  /// Why it cannot be taken, shown beside the label.
  final String? disabledHint;
}

/// A chip that opens a menu of choices, in the style the app's cards use.
///
/// The [child] is normally the [GameChip] that acts as the button.
class GameChipMenu<T> extends StatelessWidget {
  const GameChipMenu({
    super.key,
    required this.tooltip,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.child,
    this.footnote,
  });

  final String tooltip;
  final List<GameMenuOption<T>> options;

  /// The choice currently in force, which gets the tick.
  final T selected;

  final ValueChanged<T> onSelected;
  final Widget child;

  /// A line at the foot of the menu explaining what picking something does.
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;

    return PopupMenuButton<T>(
      tooltip: tooltip,
      offset: Offset(0, context.rs(40)),
      color: decor.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: decor.cardRadius,
        side: BorderSide(color: decor.cardBorderColor),
      ),
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in options) _item(context, decor, option),
        if (footnote != null) _footnote(context, decor, footnote!),
      ],
      child: child,
    );
  }

  PopupMenuItem<T> _item(
    BuildContext context,
    AppDecor decor,
    GameMenuOption<T> option,
  ) {
    final theme = Theme.of(context);

    return PopupMenuItem<T>(
      value: option.value,
      enabled: option.enabled,
      height: context.rs(40),
      child: Row(
        children: [
          SizedBox(
            width: context.rs(22),
            child: option.value == selected
                ? Icon(
                    Icons.check_rounded,
                    size: context.rs(18),
                    color: decor.accentColor,
                  )
                : null,
          ),
          Expanded(
            child: Text(
              option.label,
              style: option.enabled
                  ? null
                  : theme.textTheme.bodyMedium?.copyWith(
                      color: decor.subtleTextColor.withValues(alpha: 0.5),
                    ),
            ),
          ),
          if (!option.enabled && option.disabledHint != null) ...[
            SizedBox(width: context.rs(8)),
            Text(
              option.disabledHint!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: decor.subtleTextColor.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  PopupMenuItem<T> _footnote(
    BuildContext context,
    AppDecor decor,
    String text,
  ) {
    return PopupMenuItem<T>(
      enabled: false,
      height: context.rs(32),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: decor.subtleTextColor,
          fontSize: 12,
        ),
      ),
    );
  }
}
