import 'package:flutter/material.dart';

import '../theme/app_theme_variant.dart';

enum GameId {
  wordle,
  spellingBee,
  sudoku,
  dontWordle,
  wormdle,
}

class AppStrings {
  const AppStrings(this._locale);

  final Locale _locale;

  bool get _isGerman => _locale.languageCode == 'de';

  String get appName => _isGerman ? 'Game Nook' : 'Game Nook';

  String get homeTitle => _isGerman ? 'Game Nook' : 'Game Nook';

  String get homePickGame =>
      _isGerman ? 'Wähle ein Spiel' : 'Pick a game';

  String get comingSoon => _isGerman ? 'Demnächst' : 'Coming soon';

  String get backToHome => _isGerman ? 'Zurück zur Startseite' : 'Back to home';

  String get languageLabel => _isGerman ? 'Sprache' : 'Language';

  String get themeLabel => _isGerman ? 'Design' : 'Theme';

  String get english => 'English';

  String get german => 'Deutsch';

  String themeName(AppThemeVariant variant) {
    return switch (variant) {
      AppThemeVariant.classicDark =>
        _isGerman ? 'Klassisch Dunkel' : 'Classic Dark',
      AppThemeVariant.classicLight =>
        _isGerman ? 'Klassisch Hell' : 'Classic Light',
      AppThemeVariant.sunset => _isGerman ? 'Sonnenuntergang' : 'Sunset',
      AppThemeVariant.ocean => _isGerman ? 'Ozean' : 'Ocean',
    };
  }

  String gameName(GameId game) {
    return switch (game) {
      GameId.wordle => 'Wordle',
      GameId.spellingBee => _isGerman ? 'Spelling Bee' : 'Spelling Bee',
      GameId.sudoku => 'Sudoku',
      GameId.dontWordle => "Don't Wordle",
      GameId.wormdle => 'Wormdle',
    };
  }

  String gameDescription(GameId game) {
    return switch (game) {
      GameId.wordle => _isGerman
          ? 'Errate das Wort in sechs Versuchen'
          : 'Guess the word in six tries',
      GameId.spellingBee => _isGerman
          ? 'Finde Wörter aus den gegebenen Buchstaben'
          : 'Find words from the given letters',
      GameId.sudoku => _isGerman
          ? 'Fülle das 9×9-Raster mit Zahlen'
          : 'Fill the 9×9 grid with numbers',
      GameId.dontWordle => _isGerman
          ? 'Vermeide das richtige Wort'
          : 'Avoid guessing the correct word',
      GameId.wormdle => _isGerman
          ? 'Errate das Wort, indem du pro Runde einen Buchstaben änderst'
          : 'Guess the word by changing one letter each round',
    };
  }

  String gamePlaceholderBody(GameId game) {
    return _isGerman
        ? '${gameName(game)} ist noch in Arbeit. Schau bald wieder vorbei!'
        : '${gameName(game)} is still in the works. Check back soon!';
  }
}
