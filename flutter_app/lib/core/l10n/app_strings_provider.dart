import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_strings.dart';
import 'locale_notifier.dart';

final appStringsProvider = Provider<AppStrings>((ref) {
  final locale = ref.watch(appLocaleProvider);
  return AppStrings(locale);
});
