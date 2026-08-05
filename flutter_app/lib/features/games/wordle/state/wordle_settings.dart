import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/wordle_models.dart';

/// Player preferences. They outlive a single round: changing the difficulty is
/// picked up by the next game, hard mode applies to the next guess, only the
/// word length restarts the game (see [WordleGameController.changeWordLength]).
class WordleSettings {
  const WordleSettings({
    this.wordLength = kWordleDefaultLength,
    this.difficulty = WordleDifficulty.normal,
    this.hardMode = false,
  });

  final int wordLength;
  final WordleDifficulty difficulty;
  final bool hardMode;

  WordleSettings copyWith({
    int? wordLength,
    WordleDifficulty? difficulty,
    bool? hardMode,
  }) {
    return WordleSettings(
      wordLength: wordLength ?? this.wordLength,
      difficulty: difficulty ?? this.difficulty,
      hardMode: hardMode ?? this.hardMode,
    );
  }
}

class WordleSettingsNotifier extends Notifier<WordleSettings> {
  @override
  WordleSettings build() {
    ref.keepAlive();
    return const WordleSettings();
  }

  void setWordLength(int length) {
    if (state.wordLength == length) return;
    state = state.copyWith(wordLength: length);
  }

  void setDifficulty(WordleDifficulty difficulty) {
    if (state.difficulty == difficulty) return;
    state = state.copyWith(difficulty: difficulty);
  }

  void setHardMode(bool enabled) {
    if (state.hardMode == enabled) return;
    state = state.copyWith(hardMode: enabled);
  }
}

final wordleSettingsProvider =
    NotifierProvider<WordleSettingsNotifier, WordleSettings>(
      WordleSettingsNotifier.new,
    );
