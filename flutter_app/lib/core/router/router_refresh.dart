import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/locale_notifier.dart';
import '../theme/theme_notifier.dart';

/// Notifies [GoRouter] when Riverpod-driven app settings change.
class RouterRefresh extends ChangeNotifier {
  RouterRefresh(Ref ref) {
    ref.listen(appLocaleProvider, (_, _) => notifyListeners());
    ref.listen(themeVariantProvider, (_, _) => notifyListeners());
  }
}
