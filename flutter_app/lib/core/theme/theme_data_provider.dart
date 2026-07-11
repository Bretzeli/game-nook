import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_themes.dart';
import 'theme_notifier.dart';

final themeDataProvider = Provider<ThemeData>((ref) {
  final variant = ref.watch(themeVariantProvider);
  return AppThemes.forVariant(variant);
});
