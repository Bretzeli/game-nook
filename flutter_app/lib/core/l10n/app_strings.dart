import 'package:flutter/material.dart';

import '../../features/games/sudoku/domain/sudoku_models.dart';
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
          ? 'Fülle das Raster, ohne dich zu wiederholen'
          : 'Fill the grid without repeating yourself',
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

  String get play => _isGerman ? 'Spielen' : 'Play';

  // --- Wordle -------------------------------------------------------------

  String get wordleLengthLabel => _isGerman ? 'Länge' : 'Length';

  String wordleLetterCount(int count) =>
      _isGerman ? '$count Buchstaben' : '$count letters';

  String get wordleLengthUnavailable =>
      _isGerman ? 'Weniger als 20 Wörter' : 'Fewer than 20 words';

  String get wordleDifficultyLabel =>
      _isGerman ? 'Schwierigkeit' : 'Difficulty';

  String get wordleDifficultyNormal => 'Normal';

  String get wordleDifficultyHard => _isGerman ? 'Schwierig' : 'Difficult';

  String get wordleDifficultyAll => _isGerman ? 'Alle Wörter' : 'All words';

  String get wordleDifficultyHint => _isGerman
      ? 'Gilt ab dem nächsten Spiel'
      : 'Applies from the next game on';

  String get wordleHardMode => _isGerman ? 'Schwerer Modus' : 'Hard mode';

  String get wordleHardModeHint => _isGerman
      ? 'Alle Hinweise müssen im nächsten Versuch verwendet werden'
      : 'Every hint has to be used in your next guess';

  String get wordleNewGame => _isGerman ? 'Neues Spiel' : 'New game';

  String get wordleGiveUp => _isGerman ? 'Aufgeben' : 'Give up';

  String get wordleHint => _isGerman ? 'Tipp' : 'Hint';

  String get wordleHintDescription => _isGerman
      ? 'Füllt ein Wort ein, das noch zu allen Hinweisen passt'
      : 'Fills in a word that still fits every hint';

  String get wordleHintOnlySolutionTitle =>
      _isGerman ? 'Nur noch die Lösung' : 'Only the solution is left';

  String get wordleHintOnlySolutionBody => _isGerman
      ? 'Kein anderes Wort passt noch zu deinen Hinweisen. Soll die Lösung '
            'eingetragen werden?'
      : 'No other word still fits your hints. Shall the solution be filled in?';

  String get wordleHintSolve => _isGerman ? 'Lösung eintragen' : 'Fill it in';

  String get wordleHintKeepPlaying => _isGerman ? 'Weiterraten' : 'Keep trying';

  String get wordleNotEnoughLetters =>
      _isGerman ? 'Zu wenige Buchstaben' : 'Not enough letters';

  String get wordleNotInWordList =>
      _isGerman ? 'Nicht in der Wortliste' : 'Not in word list';

  String wordleHardModeFixedLetter(int position, String letter) => _isGerman
      ? '$position. Buchstabe muss $letter sein'
      : '${_ordinal(position)} letter must be $letter';

  String wordleHardModeMustMove(int position, String letter) => _isGerman
      ? '$letter passt nicht an Position $position'
      : '$letter does not belong in position $position';

  String wordleHardModeMustContain(String letter) => _isGerman
      ? 'Das Wort muss $letter enthalten'
      : 'Your guess must contain $letter';

  String wordleHardModeMustNotContain(String letter) => _isGerman
      ? 'Das Wort enthält kein $letter'
      : 'The word contains no $letter';

  String wordleWinTitle(int attempts) {
    if (_isGerman) {
      return switch (attempts) {
        1 => 'Genial!',
        2 => 'Großartig!',
        3 => 'Stark!',
        4 => 'Sehr gut!',
        5 => 'Gut gemacht!',
        _ => 'Puh, geschafft!',
      };
    }
    return switch (attempts) {
      1 => 'Genius!',
      2 => 'Magnificent!',
      3 => 'Impressive!',
      4 => 'Splendid!',
      5 => 'Great!',
      _ => 'Phew, got it!',
    };
  }

  String wordleWinDetail(int attempts, int maxAttempts) => _isGerman
      ? 'In $attempts von $maxAttempts Versuchen'
      : 'In $attempts of $maxAttempts tries';

  String get wordleLoseTitle => _isGerman ? 'Schade!' : 'Bad luck!';

  String get wordleSolutionLabel => _isGerman ? 'Lösung' : 'Solution';

  String get wordleLoadFailed => _isGerman
      ? 'Die Wortliste konnte nicht geladen werden.'
      : 'The word list could not be loaded.';

  String get wordleRetry => _isGerman ? 'Erneut versuchen' : 'Try again';

  // --- Spelling Bee -------------------------------------------------------

  String get spellingBeeNewGame => _isGerman ? 'Neues Spiel' : 'New game';

  String get spellingBeeGiveUp =>
      _isGerman ? 'Alle Wörter' : 'All words';

  String get spellingBeeGiveUpHint => _isGerman
      ? 'Beendet die Runde und zeigt jedes Wort'
      : 'Ends the round and reveals every word';

  String get spellingBeeShuffle => _isGerman ? 'Mischen' : 'Shuffle';

  String get spellingBeeDelete => _isGerman ? 'Löschen' : 'Delete';

  String get spellingBeeEnter => _isGerman ? 'Eingabe' : 'Enter';

  String get spellingBeeScoreLabel => _isGerman ? 'Punkte' : 'Points';

  String get spellingBeeTierNormal => _isGerman ? 'Normal' : 'Normal';

  String get spellingBeeTierDifficult =>
      _isGerman ? 'Schwierig' : 'Difficult';

  String get spellingBeeTierBonus => 'Bonus';

  String get spellingBeeNormalHint => _isGerman
      ? 'Alltägliche Wörter — die gelbe Leiste'
      : 'Everyday words — the yellow bar';

  String get spellingBeeDifficultHint => _isGerman
      ? 'Seltenere Wörter aus dem Wörterbuch — die silberne Leiste'
      : 'Rarer dictionary words — the silver bar';

  String get spellingBeeBonusHint => _isGerman
      ? 'Wörter aus keiner der beiden Listen geben Bonuspunkte'
      : 'Words in neither list pay bonus points';

  /// The same thing in the space a phone has for it.
  String get spellingBeeBonusHintShort => _isGerman
      ? 'Seltene Wörter zählen extra'
      : 'Rare words pay extra';

  String get spellingBeeWordsLabel => _isGerman ? 'Wörter' : 'Words';

  String spellingBeeFoundOf(int found, int total) =>
      _isGerman ? '$found von $total' : '$found of $total';

  String spellingBeeRareFinds(int count) {
    if (_isGerman) {
      return count == 1 ? '1 seltener Fund' : '$count seltene Funde';
    }
    return count == 1 ? '1 rare find' : '$count rare finds';
  }

  String get spellingBeeNoWordsYet =>
      _isGerman ? 'Noch keine Wörter' : 'No words yet';

  String spellingBeeTooShort(int minimum) => _isGerman
      ? 'Mindestens $minimum Buchstaben'
      : 'At least $minimum letters';

  String spellingBeeMissingCenter(String letter) => _isGerman
      ? 'Der mittlere Buchstabe $letter fehlt'
      : 'Missing the middle letter $letter';

  String spellingBeeBadLetter(String letter) => _isGerman
      ? '$letter liegt nicht im Feld'
      : '$letter is not in the hive';

  String get spellingBeeNotAWord =>
      _isGerman ? 'Nicht in der Wortliste' : 'Not in the word list';

  String get spellingBeeAlreadyFound =>
      _isGerman ? 'Schon gefunden' : 'Already found';

  String get spellingBeePangram => _isGerman ? 'Pangramm!' : 'Pangram!';

  String get spellingBeeRareFind =>
      _isGerman ? 'Seltener Fund!' : 'Rare find!';

  /// A pat on the back that grows with what the word was worth.
  String spellingBeePraise(int points) {
    if (_isGerman) {
      if (points >= 14) return 'Sensationell!';
      if (points >= 10) return 'Ausgezeichnet!';
      if (points >= 7) return 'Super!';
      if (points >= 5) return 'Stark!';
      return 'Gut!';
    }
    if (points >= 14) return 'Amazing!';
    if (points >= 10) return 'Excellent!';
    if (points >= 7) return 'Great!';
    if (points >= 5) return 'Nice!';
    return 'Good!';
  }

  String spellingBeeTierComplete(String tier) =>
      _isGerman ? '$tier komplett!' : '$tier complete!';

  String get spellingBeeCompleteTitle =>
      _isGerman ? 'Alle Wörter gefunden!' : 'Every word found!';

  String get spellingBeeRevealedTitle =>
      _isGerman ? 'Runde beendet' : 'Round over';

  String spellingBeeScoreDetail(int points, int found, int total) => _isGerman
      ? '$points Punkte · $found von $total Wörtern'
      : '$points points · $found of $total words';

  String get spellingBeeClose => _isGerman ? 'Schließen' : 'Close';

  String get spellingBeeMissedLabel => _isGerman ? 'Verpasst' : 'Missed';

  String get spellingBeeLoadFailed => _isGerman
      ? 'Die Wortliste konnte nicht geladen werden.'
      : 'The word list could not be loaded.';

  String get spellingBeeRetry => _isGerman ? 'Erneut versuchen' : 'Try again';

  // --- Sudoku -------------------------------------------------------------

  String get sudokuSizeLabel => _isGerman ? 'Größe' : 'Size';

  String sudokuSizeName(SudokuSize size) => '${size.length}×${size.length}';

  String get sudokuSizeHint => _isGerman
      ? 'Eine andere Größe beginnt ein neues Spiel'
      : 'A different size starts a new board';

  String get sudokuDifficultyLabel =>
      _isGerman ? 'Schwierigkeit' : 'Difficulty';

  String sudokuDifficultyName(SudokuDifficulty difficulty) {
    return switch (difficulty) {
      SudokuDifficulty.easy => _isGerman ? 'Leicht' : 'Easy',
      SudokuDifficulty.medium => _isGerman ? 'Mittel' : 'Medium',
      SudokuDifficulty.hard => _isGerman ? 'Schwer' : 'Hard',
    };
  }

  String get sudokuDifficultyHint => _isGerman
      ? 'Jedes Rätsel ist ohne Raten lösbar — je schwerer, desto weniger '
            'Zahlen sind vorgegeben'
      : 'Every puzzle can be solved without guessing — the harder it is, the '
            'fewer numbers you start with';

  String get sudokuNotes => _isGerman ? 'Notizen' : 'Notes';

  String get sudokuNotesHint => _isGerman
      ? 'Zahlen als Notiz eintragen — oder halte dafür die Umschalttaste'
      : 'Write values as pencil marks — or hold shift to note just one';

  String get sudokuCheckCell => _isGerman ? 'Feld prüfen' : 'Check cell';

  String get sudokuCheckCellHint => _isGerman
      ? 'Sagt, ob im gewählten Feld die richtige Zahl steht'
      : 'Says whether the selected cell holds the right value';

  String get sudokuCheckAll => _isGerman ? 'Alles prüfen' : 'Check all';

  String get sudokuCheckAllHint => _isGerman
      ? 'Prüft jedes Feld, das du selbst gefüllt hast'
      : 'Checks every cell you filled in yourself';

  String get sudokuSolveCell => _isGerman ? 'Feld lösen' : 'Solve cell';

  String get sudokuSolveCellHint => _isGerman
      ? 'Trägt die richtige Zahl im gewählten Feld ein'
      : 'Fills the right value into the selected cell';

  String get sudokuNewGame => _isGerman ? 'Neues Spiel' : 'New game';

  String get sudokuGiveUp => _isGerman ? 'Aufgeben' : 'Give up';

  String get sudokuGiveUpHint => _isGerman
      ? 'Beendet die Runde und füllt das Raster auf'
      : 'Ends the round and fills the grid in';

  String get sudokuErase => _isGerman ? 'Löschen' : 'Erase';

  String get sudokuSelectCellFirst =>
      _isGerman ? 'Wähle zuerst ein Feld' : 'Pick a cell first';

  String get sudokuNothingToCheck =>
      _isGerman ? 'Noch nichts eingetragen' : 'Nothing filled in yet';

  String get sudokuCellCorrect => _isGerman ? 'Das stimmt' : 'That one is right';

  String get sudokuCellWrong =>
      _isGerman ? 'Das stimmt nicht' : 'That one is wrong';

  String sudokuAllCorrect(int checked) => _isGerman
      ? 'Alle $checked Felder stimmen'
      : 'All $checked cells are right';

  String sudokuWrongCount(int wrong) {
    if (_isGerman) {
      return wrong == 1 ? '1 Feld stimmt nicht' : '$wrong Felder stimmen nicht';
    }
    return wrong == 1 ? '1 cell is wrong' : '$wrong cells are wrong';
  }

  String get sudokuRemainingLabel => _isGerman ? 'Übrig' : 'Left';

  String get sudokuSolvedTitle => _isGerman ? 'Gelöst!' : 'Solved!';

  String get sudokuRevealedTitle => _isGerman ? 'Runde beendet' : 'Round over';

  /// The board and how much help was taken, under the result.
  String sudokuResultDetail(
    SudokuSize size,
    SudokuDifficulty difficulty,
    int solvedForYou,
  ) {
    final board =
        '${sudokuSizeName(size)} · ${sudokuDifficultyName(difficulty)}';
    if (solvedForYou == 0) {
      return _isGerman ? '$board · ohne Hilfe' : '$board · no help taken';
    }
    if (_isGerman) {
      return solvedForYou == 1
          ? '$board · 1 Feld gelöst'
          : '$board · $solvedForYou Felder gelöst';
    }
    return solvedForYou == 1
        ? '$board · 1 cell solved for you'
        : '$board · $solvedForYou cells solved for you';
  }

  String get sudokuLoadFailed => _isGerman
      ? 'Das Rätsel konnte nicht erstellt werden.'
      : 'The puzzle could not be created.';

  String get sudokuRetry => _isGerman ? 'Erneut versuchen' : 'Try again';

  String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }
}
