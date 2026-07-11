import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme_variant.dart';

class ThemeVariantNotifier extends Notifier<AppThemeVariant> {
  @override
  AppThemeVariant build() => AppThemeVariant.classicDark;

  void setVariant(AppThemeVariant variant) {
    if (state == variant) return;
    state = variant;
  }
}

final themeVariantProvider =
    NotifierProvider<ThemeVariantNotifier, AppThemeVariant>(
  ThemeVariantNotifier.new,
);
