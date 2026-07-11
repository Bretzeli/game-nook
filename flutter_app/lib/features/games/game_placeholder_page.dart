import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/responsive_scale.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/app_strings_provider.dart';
import '../../core/theme/app_theme_extension.dart';

class GamePlaceholderPage extends ConsumerWidget {
  const GamePlaceholderPage({super.key, required this.gameId});

  final GameId gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final decor = context.decor;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.rs(32)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.rs(420)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(context.rs(28)),
                decoration: BoxDecoration(
                  color: decor.cardColor,
                  borderRadius: decor.cardRadius,
                  border: Border.all(
                    color: decor.cardBorderColor,
                    width: decor.cardBorderWidth,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: decor.glowColor.withValues(alpha: 0.2),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.construction_rounded,
                  size: context.rs(56),
                  color: decor.accentColor,
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .shimmer(
                    duration: 2400.ms,
                    color: decor.accentColor.withValues(alpha: 0.3),
                  )
                  .then()
                  .shake(hz: 0.3, rotation: 0.02),
              SizedBox(height: context.rs(28)),
              Text(
                strings.gameName(gameId),
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 150.ms),
              SizedBox(height: context.rs(12)),
              Text(
                strings.gamePlaceholderBody(gameId),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: decor.subtleTextColor,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 250.ms),
              SizedBox(height: context.rs(8)),
              Text(
                strings.comingSoon,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: decor.accentSecondary,
                  letterSpacing: 1.2,
                ),
              ).animate().fadeIn(delay: 350.ms),
            ],
          ),
        ),
      ),
    );
  }
}
