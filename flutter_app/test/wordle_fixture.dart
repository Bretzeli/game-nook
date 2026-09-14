import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/dictionary/dictionary_repository.dart';
import 'package:flutter_app/core/dictionary/word_definition.dart';
import 'package:flutter_app/features/games/wordle_shared/data/wordle_word_repository.dart';
import 'package:flutter_app/features/games/wordle_shared/domain/wordle_models.dart';
import 'package:flutter_app/features/games/wordle_shared/state/wordle_board_controller.dart';

/// A repository serving one fixed set of same-length words, for tests that
/// need to know exactly which candidates are in play.
///
/// Solutions are drawn from [words] — joined by [difficultWords] when the
/// difficult list is asked for; [extraGuesses] are accepted as guesses on top
/// of them without ever being the solution.
class FixedWordRepository extends WordleWordRepository {
  FixedWordRepository(
    this.words, {
    this.extraGuesses = const [],
    this.difficultWords = const [],
  });

  final List<String> words;
  final List<String> extraGuesses;
  final List<String> difficultWords;

  @override
  Future<List<int>> availableLengths(
    String languageCode,
    WordleDifficulty difficulty,
  ) async => [words.first.length];

  @override
  Future<List<String>> solutionPool(
    String languageCode,
    WordleDifficulty difficulty,
    int length,
  ) async => difficulty == WordleDifficulty.normal
      ? words
      : [...words, ...difficultWords];

  @override
  Future<Set<String>> acceptedWords(String languageCode, int length) async => {
    ...words,
    ...difficultWords,
    ...extraGuesses,
  };
}

/// Reading the word lists is real async work that the fake clock inside
/// `testWidgets` cannot drive, so it is done up front and handed to the app as
/// a warm repository. Everything a page then asks for resolves as a
/// microtask, exactly like a second visit to the game does.
Future<WordleWordRepository> warmWordRepository(
  WidgetTester tester,
  List<String> languages,
) async {
  final repository = WordleWordRepository();
  await tester.runAsync(() async {
    for (final language in languages) {
      await repository.roundWords(
        language,
        WordleDifficulty.normal,
        kWordleDefaultLength,
      );
    }
  });
  return repository;
}

/// Stands in for the bundled dictionaries, which are far too large to decode
/// under a widget test's fake clock. [knows] decides whether the solution —
/// whichever word the game picked — has an entry.
class FakeDictionary extends DictionaryRepository {
  FakeDictionary({required this.knows});

  final bool knows;

  @override
  Future<WordDefinition?> define(String languageCode, String word) async {
    if (!knows) return null;
    return WordDefinition(
      word: word.toUpperCase(),
      meanings: const [
        WordMeaning(
          partOfSpeech: 'Noun',
          definition: 'a large long-necked wading bird',
          relatedTerms: [],
          examples: ['a crane took off from the reeds'],
        ),
      ],
      synonyms: const ['heron'],
      antonyms: const [],
    );
  }
}

/// Waits until [provider] holds a state that [isReady] accepts.
///
/// A restart keeps the previous board on screen while the new word list is
/// read, so [isReady] should tell the old round from the new one.
Future<S> waitForState<S>(
  ProviderContainer container,
  ProviderListenable<S> provider,
  bool Function(S state) isReady,
) async {
  final completer = Completer<S>();
  final subscription = container.listen<S>(provider, (_, next) {
    if (isReady(next) && !completer.isCompleted) completer.complete(next);
  }, fireImmediately: true);
  addTearDown(subscription.close);

  final state = container.read(provider);
  if (isReady(state)) return state;
  return completer.future.timeout(const Duration(seconds: 60));
}

/// Types [word] letter by letter.
void typeWord(WordleBoardControls controls, String word) {
  for (final letter in word.split('')) {
    controls.typeLetter(letter);
  }
}

/// flutter_animate defers a freshly mounted animation by a zero timer, so one
/// settle pass can end with that timer still queued.
Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pumpAndSettle();
}
