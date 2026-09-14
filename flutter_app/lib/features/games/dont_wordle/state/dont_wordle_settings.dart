import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../wordle_shared/domain/wordle_models.dart';
import '../domain/dont_wordle_models.dart';

/// Player preferences, kept apart from Wordle's so each game remembers its
/// own. The word length and the number of guesses shape the board, so
/// changing either restarts the round; which words may be the solution is
/// picked up by the next one (see [DontWordleController]).
class DontWordleSettings {
  const DontWordleSettings({
    this.wordLength = kWordleDefaultLength,
    this.guesses = kDontWordleDefaultGuesses,
    this.difficultWords = false,
  });

  final int wordLength;

  /// Guesses to survive before the word may be found.
  final int guesses;

  /// Whether rarer words can be the solution too.
  final bool difficultWords;

  /// The list the solution is drawn from.
  WordleDifficulty get solutionList =>
      difficultWords ? WordleDifficulty.difficult : WordleDifficulty.normal;

  DontWordleSettings copyWith({
    int? wordLength,
    int? guesses,
    bool? difficultWords,
  }) {
    return DontWordleSettings(
      wordLength: wordLength ?? this.wordLength,
      guesses: guesses ?? this.guesses,
      difficultWords: difficultWords ?? this.difficultWords,
    );
  }
}

class DontWordleSettingsNotifier extends Notifier<DontWordleSettings> {
  @override
  DontWordleSettings build() {
    ref.keepAlive();
    return const DontWordleSettings();
  }

  void setWordLength(int length) {
    if (state.wordLength == length) return;
    state = state.copyWith(wordLength: length);
  }

  void setGuesses(int guesses) {
    if (state.guesses == guesses) return;
    state = state.copyWith(guesses: guesses);
  }

  void setDifficultWords(bool enabled) {
    if (state.difficultWords == enabled) return;
    state = state.copyWith(difficultWords: enabled);
  }
}

final dontWordleSettingsProvider =
    NotifierProvider<DontWordleSettingsNotifier, DontWordleSettings>(
      DontWordleSettingsNotifier.new,
    );
