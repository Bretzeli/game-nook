import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/app_strings_provider.dart';
import '../core/l10n/locale_notifier.dart';
import '../core/layout/responsive_scale.dart';
import '../core/theme/app_theme_extension.dart';

class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final locale = ref.watch(appLocaleProvider);
    final decor = context.decor;
    final current = locale.languageCode;

    return PopupMenuButton<String>(
      tooltip: strings.languageLabel,
      offset: Offset(0, context.rs(44)),
      shape: RoundedRectangleBorder(
        borderRadius: decor.cardRadius,
        side: BorderSide(color: decor.cardBorderColor),
      ),
      color: decor.cardColor,
      onSelected: (code) =>
          ref.read(appLocaleProvider.notifier).setLocale(Locale(code)),
      itemBuilder: (context) => [
        _buildItem(context, ref, 'en', strings.english, current == 'en'),
        _buildItem(context, ref, 'de', strings.german, current == 'de'),
      ],
      child: _SelectorChip(
        icon: Icons.translate_rounded,
        label: current.toUpperCase(),
      ),
    );
  }

  PopupMenuItem<String> _buildItem(
    BuildContext context,
    WidgetRef ref,
    String code,
    String label,
    bool selected,
  ) {
    final decor = context.decor;

    return PopupMenuItem<String>(
      value: code,
      child: Row(
        children: [
          if (selected)
            Icon(Icons.check_rounded, size: context.rs(18), color: decor.accentColor)
          else
            SizedBox(width: context.rs(18)),
          SizedBox(width: context.rs(8)),
          Text(label),
        ],
      ),
    );
  }
}

class _SelectorChip extends StatefulWidget {
  const _SelectorChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  State<_SelectorChip> createState() => _SelectorChipState();
}

class _SelectorChipState extends State<_SelectorChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: context.rs(10),
          vertical: context.rs(6),
        ),
        decoration: BoxDecoration(
          color: _hovered
              ? decor.accentColor.withValues(alpha: 0.12)
              : decor.cardColor.withValues(alpha: 0.5),
          borderRadius: decor.buttonRadius,
          border: Border.all(
            color: _hovered ? decor.accentColor : decor.subtleNavBorder,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: context.rs(16), color: decor.accentColor),
            SizedBox(width: context.rs(6)),
            Text(
              widget.label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: decor.accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
