import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/app_strings_provider.dart';
import '../core/layout/responsive_scale.dart';
import '../core/theme/app_theme_extension.dart';
import '../core/theme/app_theme_variant.dart';
import '../core/theme/theme_notifier.dart';

class ThemeSelector extends ConsumerWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final current = ref.watch(themeVariantProvider);
    final decor = context.decor;

    return PopupMenuButton<AppThemeVariant>(
      tooltip: strings.themeLabel,
      offset: Offset(0, context.rs(44)),
      shape: RoundedRectangleBorder(
        borderRadius: decor.cardRadius,
        side: BorderSide(color: decor.cardBorderColor),
      ),
      color: decor.cardColor,
      onSelected: (variant) =>
          ref.read(themeVariantProvider.notifier).setVariant(variant),
      itemBuilder: (context) {
        return AppThemeVariant.values.map((variant) {
          final selected = variant == current;
          return PopupMenuItem<AppThemeVariant>(
            value: variant,
            child: Row(
              children: [
                _ThemeSwatch(variant: variant, selected: selected),
                SizedBox(width: context.rs(10)),
                Expanded(
                  child: Text(strings.themeName(variant)),
                ),
                if (selected)
                  Icon(Icons.check_rounded, size: context.rs(18), color: decor.accentColor),
              ],
            ),
          );
        }).toList();
      },
      child: _ThemeChip(current: current),
    );
  }
}

class _ThemeChip extends StatefulWidget {
  const _ThemeChip({required this.current});

  final AppThemeVariant current;

  @override
  State<_ThemeChip> createState() => _ThemeChipState();
}

class _ThemeChipState extends State<_ThemeChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(context.rs(6)),
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
        child: _ThemeSwatch(variant: widget.current, selected: true, compact: true),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.variant,
    required this.selected,
    this.compact = false,
  });

  final AppThemeVariant variant;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (Color c1, Color c2) = switch (variant) {
      AppThemeVariant.classicDark => (
          const Color(0xFF1A1A2E),
          const Color(0xFFF0A500),
        ),
      AppThemeVariant.classicLight => (
          const Color(0xFFF8F9FC),
          const Color(0xFF6366F1),
        ),
      AppThemeVariant.sunset => (
          const Color(0xFF2D1B4E),
          const Color(0xFFFF6B6B),
        ),
      AppThemeVariant.ocean => (
          const Color(0xFF0A1628),
          const Color(0xFF00D4AA),
        ),
    };

    final size = context.rs(compact ? 18.0 : 24.0);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.rs(compact ? 4 : 6)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c1, c2],
        ),
        border: selected
            ? Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: c2.withValues(alpha: 0.4),
            blurRadius: selected ? 6 : 2,
          ),
        ],
      ),
    );
  }
}
