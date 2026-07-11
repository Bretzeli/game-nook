import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/layout/responsive_scale.dart';
import '../core/l10n/app_strings_provider.dart';
import '../core/theme/app_theme_extension.dart';
import 'language_selector.dart';
import 'theme_selector.dart';

class AppNavBar extends ConsumerWidget {
  const AppNavBar({
    super.key,
    required this.title,
    this.showHomeButton = false,
  });

  final String title;
  final bool showHomeButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decor = context.decor;
    final theme = Theme.of(context);
    final hPad = context.rs(16);
    final vPad = context.rs(12);
    final radius = context.rs(20);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(hPad, context.rs(12), hPad, context.rs(8)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: decor.navBarColor,
              border: Border.all(
                color: decor.subtleNavBorder,
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: decor.glowColor.withValues(alpha: 0.06),
                  blurRadius: context.rs(20),
                  offset: Offset(0, context.rs(6)),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.rs(16),
                vertical: vPad,
              ),
              child: SizedBox(
                height: context.rs(40),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: context.rs(96)),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.3),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          title,
                          key: ValueKey(title),
                          style: theme.textTheme.titleLarge,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (showHomeButton)
                          _NavIconButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: ref.watch(appStringsProvider).backToHome,
                            onPressed: () => context.go('/'),
                          )
                        else
                          const SizedBox.shrink(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const LanguageSelector(),
                            SizedBox(width: context.rs(8)),
                            const ThemeSelector(),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavIconButton extends StatefulWidget {
  const _NavIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<_NavIconButton> createState() => _NavIconButtonState();
}

class _NavIconButtonState extends State<_NavIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _hovered
              ? decor.accentColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: decor.buttonRadius,
        ),
        child: IconButton(
          icon: Icon(widget.icon, size: context.rs(22)),
          tooltip: widget.tooltip,
          onPressed: widget.onPressed,
          color: decor.accentColor,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
