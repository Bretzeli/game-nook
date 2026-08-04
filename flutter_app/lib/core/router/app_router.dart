import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme_extension.dart';
import '../l10n/app_strings.dart';
import '../l10n/app_strings_provider.dart';
import '../../features/games/game_placeholder_page.dart';
import '../../features/home/home_page.dart';
import '../../widgets/app_nav_bar.dart';
import 'router_refresh.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final strings = ref.watch(appStringsProvider);
    final decor = context.decor;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(gradient: decor.backgroundGradient),
          ),
          Column(
            children: [
              AppNavBar(
                title: _titleForPath(strings, location),
                showHomeButton: location != '/',
              ),
              Expanded(child: child),
            ],
          ),
        ],
      ),
    );
  }

  String _titleForPath(AppStrings strings, String path) {
    return switch (path) {
      '/' => strings.homeTitle,
      '/wordle' => strings.gameName(GameId.wordle),
      '/spelling-bee' => strings.gameName(GameId.spellingBee),
      '/sudoku' => strings.gameName(GameId.sudoku),
      '/dont-wordle' => strings.gameName(GameId.dontWordle),
      '/wormdle' => strings.gameName(GameId.wormdle),
      _ => strings.appName,
    };
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HomePage()),
          ),
          GoRoute(
            path: '/wordle',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: GamePlaceholderPage(gameId: GameId.wordle),
            ),
          ),
          GoRoute(
            path: '/spelling-bee',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: GamePlaceholderPage(gameId: GameId.spellingBee),
            ),
          ),
          GoRoute(
            path: '/sudoku',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: GamePlaceholderPage(gameId: GameId.sudoku),
            ),
          ),
          GoRoute(
            path: '/dont-wordle',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: GamePlaceholderPage(gameId: GameId.dontWordle),
            ),
          ),
          GoRoute(
            path: '/wormdle',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: GamePlaceholderPage(gameId: GameId.wormdle),
            ),
          ),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
