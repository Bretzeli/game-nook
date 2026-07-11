enum AppThemeVariant {
  classicDark,
  classicLight,
  sunset,
  ocean;

  String get storageKey => name;

  static AppThemeVariant fromStorageKey(String key) {
    return AppThemeVariant.values.firstWhere(
      (variant) => variant.storageKey == key,
      orElse: () => AppThemeVariant.classicDark,
    );
  }
}
