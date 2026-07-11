import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/responsive_scale.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/app_strings_provider.dart';
import '../../core/theme/app_theme_extension.dart';
import '../../widgets/game_card.dart';
import '../../widgets/worm_icon.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  static const _baseGridWidth = 920.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final decor = context.decor;
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final scale = context.layoutScale;
    final gridWidth = width > _baseGridWidth * scale + context.rs(48)
        ? _baseGridWidth * scale
        : width - context.rs(48);

    final crossAxisCount = gridWidth > context.rs(780)
        ? 3
        : gridWidth > context.rs(480)
            ? 2
            : 1;

    final games = [
      (GameId.wordle, Icons.grid_on_rounded, '/wordle'),
      (GameId.spellingBee, Icons.hexagon_rounded, '/spelling-bee'),
      (GameId.sudoku, Icons.apps_rounded, '/sudoku'),
      (GameId.dontWordle, Icons.block_rounded, '/dont-wordle'),
      (GameId.wormdle, null, '/wormdle'),
    ];

    final iconSize = context.rs(24);
    final spacing = context.rs(14);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(context.rs(24), context.rs(8), context.rs(24), 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [decor.accentColor, decor.accentSecondary],
                  ).createShader(bounds),
                  child: Text(
                    strings.homePickGame,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 100.ms)
                    .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                SizedBox(height: context.rs(24)),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: SizedBox(
              width: gridWidth,
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  mainAxisExtent: crossAxisCount == 1
                      ? context.rs(130)
                      : context.rs(168),
                ),
                itemCount: games.length,
                itemBuilder: (context, index) {
                  final (gameId, iconData, route) = games[index];
                  final accent = index.isEven
                      ? decor.accentColor
                      : decor.accentSecondary;

                  final icon = iconData != null
                      ? Icon(iconData, color: accent, size: iconSize)
                      : WormIcon(color: accent, size: iconSize);

                  return GameCard(
                    title: strings.gameName(gameId),
                    description: strings.gameDescription(gameId),
                    icon: icon,
                    route: route,
                    index: index,
                    accentColor: accent,
                  );
                },
              ),
            ),
          ),
        ),
        SliverPadding(padding: EdgeInsets.only(bottom: context.rs(32))),
      ],
    );
  }
}
