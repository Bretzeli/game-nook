import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/locale_notifier.dart';
import '../../../../core/words/word_alphabet.dart';
import '../data/spelling_bee_word_repository.dart';
import '../domain/spelling_bee_models.dart';
import '../domain/spelling_bee_puzzle_factory.dart';
import '../domain/spelling_bee_rules.dart';
import 'spelling_bee_game_state.dart';

/// Long enough for any word a hive can spell, short enough that a stuck key
/// cannot push the input past the width of the screen.
const int kBeeMaxInputLength = 24;

final spellingBeeWordRepositoryProvider = Provider<SpellingBeeWordRepository>((
  ref,
) {
  ref.keepAlive();
  return SpellingBeeWordRepository();
});

class SpellingBeeController extends Notifier<SpellingBeeGameState> {
  final Random _random = Random();
  int _loadToken = 0;

  /// Counts every puzzle this controller has dealt. It lives on the notifier
  /// rather than on the state so that it keeps climbing when the provider is
  /// rebuilt — switching the app language deals a new puzzle, and the board
  /// has to see that as a new round rather than as the same one again.
  int _round = 0;

  @override
  SpellingBeeGameState build() {
    ref.keepAlive();

    // Switching the app language switches the word lists, and with them the
    // puzzle — rebuilding this provider is exactly that.
    final languageCode = ref.watch(appLocaleProvider).languageCode;
    _start(languageCode);

    return SpellingBeeGameState.loading(languageCode);
  }

  void newGame() => _start(state.languageCode);

  void typeLetter(String character) {
    if (!state.isPlaying || state.input.length >= kBeeMaxInputLength) return;
    final letter = WordAlphabet.normalizeChar(character, state.languageCode);
    if (letter == null) return;
    state = state.copyWith(input: state.input + letter);
  }

  void backspace() {
    if (!state.isPlaying || state.input.isEmpty) return;
    state = state.copyWith(
      input: state.input.substring(0, state.input.length - 1),
    );
  }

  void clearInput() {
    if (!state.isPlaying || state.input.isEmpty) return;
    state = state.copyWith(input: '');
  }

  /// Rearranges the outer letters. A hive that always looks the same hides
  /// words, and moving the letters around is how a player shakes them loose.
  void shuffle() {
    if (state.outerLetters.length < 2) return;

    final letters = [...state.outerLetters];
    // A shuffle that leaves every letter where it was reads as a dead button,
    // so keep drawing until something actually moved.
    for (var attempt = 0; attempt < 8; attempt++) {
      letters.shuffle(_random);
      if (!_sameOrder(letters, state.outerLetters)) break;
    }
    state = state.copyWith(outerLetters: letters);
  }

  /// Submits the typed word. Returns `null` when it counted, otherwise the
  /// reason it did not.
  BeeRejection? submit() {
    if (!state.isPlaying) return null;

    final word = state.input;
    final rejection = validateBeeWord(word, state.puzzle, state.foundWords);
    if (rejection != null) return rejection;

    final tier = state.puzzle.tierOf(word)!;
    final points = beeScoreFor(word, tier, state.puzzle.letters);
    final scores = {...state.scores};
    scores[tier] = (scores[tier] ?? 0) + points;

    final next = state.copyWith(
      input: '',
      found: [
        BeeFoundWord(
          word: word,
          tier: tier,
          points: points,
          isPangram: isBeePangram(word, state.puzzle.letters),
        ),
        ...state.found,
      ],
      scores: scores,
    );

    // Nothing left to look for ends the round on the spot, so the board can
    // celebrate instead of waiting for a player who has already won.
    state = next.isComplete ? next.copyWith(phase: BeePhase.finished) : next;
    return null;
  }

  /// Ends the round and shows every word that was there to find.
  void revealAll() {
    if (!state.canGiveUp) return;
    state = state.copyWith(
      input: '',
      phase: BeePhase.finished,
      revealed: true,
    );
  }

  Future<void> _start(String languageCode) async {
    final token = ++_loadToken;
    // Captured while it is guaranteed to be valid: after an await this tells
    // us whether the provider was disposed or rebuilt in the meantime.
    final ref = this.ref;
    final repository = ref.read(spellingBeeWordRepositoryProvider);

    try {
      final index = await repository.index(languageCode);
      if (token != _loadToken || !ref.mounted) return;

      final puzzle = buildBeePuzzle(index, _random);
      if (puzzle.isEmpty) {
        state = _failed(languageCode);
        return;
      }

      state = SpellingBeeGameState(
        languageCode: languageCode,
        phase: BeePhase.playing,
        puzzle: puzzle,
        outerLetters: puzzle.outerLetters,
        input: '',
        found: const [],
        scores: const {},
        revealed: false,
        round: ++_round,
      );
    } catch (_) {
      if (token != _loadToken || !ref.mounted) return;
      state = _failed(languageCode);
    }
  }

  SpellingBeeGameState _failed(String languageCode) =>
      SpellingBeeGameState.loading(
        languageCode,
      ).copyWith(phase: BeePhase.failed);

  bool _sameOrder(List<String> a, List<String> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final spellingBeeGameProvider =
    NotifierProvider<SpellingBeeController, SpellingBeeGameState>(
      SpellingBeeController.new,
    );
