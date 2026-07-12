import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/layout/responsive_scale.dart';
import '../core/l10n/app_strings_provider.dart';
import '../core/theme/app_theme_extension.dart';
import 'worm_icon.dart';

class GameCard extends ConsumerStatefulWidget {
  const GameCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
    required this.index,
    required this.accentColor,
  });

  final String title;
  final String description;
  final Widget icon;
  final String route;
  final int index;
  final Color accentColor;

  @override
  ConsumerState<GameCard> createState() => _GameCardState();
}

class _GameCardState extends ConsumerState<GameCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final theme = Theme.of(context);
    final scale = _pressed ? 0.97 : (_hovered ? 1.02 : 1.0);
    final padding = context.rs(16);
    final watermarkSize = context.rs(80);

    return MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() {
            _hovered = false;
            _pressed = false;
          }),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: () => context.go(widget.route),
            child: AnimatedScale(
              scale: scale,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: decor.cardColor,
                  borderRadius: decor.cardRadius,
                  border: Border.all(
                    color: _hovered
                        ? widget.accentColor.withValues(alpha: 0.6)
                        : decor.cardBorderColor,
                    width: decor.cardBorderWidth,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_hovered ? decor.cardHoverGlow : decor.glowColor)
                          .withValues(alpha: _hovered ? 0.35 : 0.08),
                      blurRadius: _hovered ? context.rs(28) : context.rs(12),
                      offset: Offset(
                        0,
                        _hovered ? context.rs(10) : context.rs(4),
                      ),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: decor.cardRadius,
                  child: Stack(
                    children: [
                      Positioned(
                        right: -context.rs(12),
                        top: -context.rs(12),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: _hovered ? 0.2 : 0.06,
                          child: SizedBox(
                            width: watermarkSize,
                            height: watermarkSize,
                            child: FittedBox(child: _watermarkIcon()),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(padding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(context.rs(10)),
                                  decoration: BoxDecoration(
                                    color: widget.accentColor.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: decor.buttonRadius,
                                  ),
                                  child: widget.icon,
                                ),
                                SizedBox(width: context.rs(12)),
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    style: theme.textTheme.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: context.rs(2)),
                            Text(
                              widget.description,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: decor.subtleTextColor,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: context.rs(14)),
                            Row(
                              children: [
                                Text(
                                  ref.watch(appStringsProvider).comingSoon,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: widget.accentColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(width: context.rs(4)),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: context.rs(14),
                                  color: widget.accentColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(
          duration: 500.ms,
          delay: (80 * widget.index).ms,
          curve: Curves.easeOutCubic,
        )
        .slideY(
          begin: 0.15,
          end: 0,
          duration: 500.ms,
          delay: (80 * widget.index).ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _watermarkIcon() {
    final icon = widget.icon;
    if (icon is Icon) {
      return Icon(
        icon.icon,
        size: icon.size,
        color: icon.color?.withValues(alpha: 0.35) ?? Colors.white.withValues(alpha: 0.35),
        semanticLabel: icon.semanticLabel,
        textDirection: icon.textDirection,
      );
    }
    if (icon is WormIcon) {
      return WormIcon(color: icon.color.withValues(alpha: 0.35), size: icon.size);
    }
    return icon;
  }
}
