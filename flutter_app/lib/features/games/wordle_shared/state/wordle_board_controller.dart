import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/wordle_word_repository.dart';
import '../domain/wordle_board.dart';
import '../domain/wordle_models.dart';

/// A game state built around a [WordleBoard].
abstract interface class WordleBoardState<S> {
  WordleBoard get board;

  /// Whether the board takes typing right now.
  bool get acceptsInput;

  /// This state with [board] in place of the current one.
  S withBoard(WordleBoard board);
}

/// What the shared game view needs to drive a game.
abstract interface class WordleBoardControls {
  /// Returns whether the letter was taken, so a key press that did nothing
  /// can bubble on.
  bool typeLetter(String character);

  void backspace();

  void selectSlot(int index);

  void moveCursor(int delta);

  /// Submits the typed row. Returns `null` when it was accepted, otherwise the
  /// reason it was turned down.
  WordleRejection? submit();

  /// Starts a new round with the current settings.
  void newGame();
}

/// Typing and round loading, shared by the controllers of every Wordle-style
/// game. The game itself only decides what a submitted row means.
mixin WordleBoardController<S extends WordleBoardState<S>> on Notifier<S>
    implements WordleBoardControls {
  int _loadToken = 0;

  @override
  bool typeLetter(String character) =>
      _edit((board) => board.typeLetter(character));

  @override
  void backspace() => _edit((board) => board.backspace());

  @override
  void selectSlot(int index) => _edit((board) => board.selectSlot(index));

  @override
  void moveCursor(int delta) => _edit((board) => board.moveCursor(delta));

  bool _edit(WordleBoard Function(WordleBoard board) change) {
    if (!state.acceptsInput) return false;
    final board = change(state.board);
    if (identical(board, state.board)) return false;
    state = state.withBoard(board);
    return true;
  }

  /// Reads the words for a new round and hands them to [onLoaded], or calls
  /// [onFailed] when the lists cannot be read or have nothing to offer.
  ///
  /// Only the latest request is delivered: one that is overtaken by another,
  /// or outlived by the provider, ends silently.
  Future<void> loadRound({
    required String languageCode,
    required WordleDifficulty difficulty,
    required int wordLength,
    required void Function(WordleRoundWords words) onLoaded,
    required void Function() onFailed,
  }) async {
    final token = ++_loadToken;
    // Captured while it is guaranteed to be valid: after an await this tells
    // us whether the provider was disposed or rebuilt in the meantime.
    final ref = this.ref;
    final repository = ref.read(wordleWordRepositoryProvider);
    bool isCurrent() => token == _loadToken && ref.mounted;

    try {
      final words = await repository.roundWords(
        languageCode,
        difficulty,
        wordLength,
      );
      if (!isCurrent()) return;
      if (words.solutionPool.isEmpty) {
        onFailed();
      } else {
        onLoaded(words);
      }
    } catch (_) {
      if (isCurrent()) onFailed();
    }
  }
}
