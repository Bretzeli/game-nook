import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/layout/responsive_scale.dart';
import 'core/l10n/locale_notifier.dart';
import 'core/router/app_router.dart';
import 'core/theme/theme_data_provider.dart';

class GameNookApp extends ConsumerWidget {
  const GameNookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeDataProvider);
    final locale = ref.watch(appLocaleProvider);
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Game Nook',
      debugShowCheckedModeBanner: false,
      theme: theme,
      themeAnimationDuration: const Duration(milliseconds: 450),
      themeAnimationCurve: Curves.easeInOutCubic,
      locale: locale,
      routerConfig: router,
      builder: (context, child) {
        final width = MediaQuery.sizeOf(context).width;
        final scale = layoutScaleForWidth(width);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
