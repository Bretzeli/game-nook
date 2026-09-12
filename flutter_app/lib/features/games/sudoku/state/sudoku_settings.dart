import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sudoku_models.dart';

/// Player preferences. They outlive a single board: the size and the difficulty
/// decide what the next puzzle looks like, and the notes switch stays where it
/// was put from one puzzle to the next.
class SudokuSettings {
  const SudokuSettings({
    this.size = SudokuSize.initial,
    this.difficulty = SudokuDifficulty.medium,
    this.notesMode = false,
  });

  final SudokuSize size;
  final SudokuDifficulty difficulty;

  /// `true` while a tapped value goes into the cell as a pencil mark rather
  /// than as its answer.
  final bool notesMode;

  SudokuSettings copyWith({
    SudokuSize? size,
    SudokuDifficulty? difficulty,
    bool? notesMode,
  }) {
    return SudokuSettings(
      size: size ?? this.size,
      difficulty: difficulty ?? this.difficulty,
      notesMode: notesMode ?? this.notesMode,
    );
  }
}

class SudokuSettingsNotifier extends Notifier<SudokuSettings> {
  @override
  SudokuSettings build() {
    ref.keepAlive();
    return const SudokuSettings();
  }

  void setSize(SudokuSize size) {
    if (state.size == size) return;
    state = state.copyWith(size: size);
  }

  void setDifficulty(SudokuDifficulty difficulty) {
    if (state.difficulty == difficulty) return;
    state = state.copyWith(difficulty: difficulty);
  }

  void setNotesMode(bool enabled) {
    if (state.notesMode == enabled) return;
    state = state.copyWith(notesMode: enabled);
  }
}

final sudokuSettingsProvider =
    NotifierProvider<SudokuSettingsNotifier, SudokuSettings>(
      SudokuSettingsNotifier.new,
    );
