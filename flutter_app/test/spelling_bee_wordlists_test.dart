import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/games/spelling_bee/data/spelling_bee_word_repository.dart';
import 'package:flutter_app/features/games/spelling_bee/domain/spelling_bee_models.dart';
import 'package:flutter_app/features/games/spelling_bee/domain/spelling_bee_puzzle_factory.dart';

/// Reads the lists that actually ship, so a missing or malformed asset shows
/// up here rather than as an empty hive on someone's screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final language in const ['en', 'de']) {
    test('$language deals a playable puzzle from the bundled lists', () async {
      final repository = SpellingBeeWordRepository();
      final index = await repository.index(language);

      expect(index.isEmpty, isFalse);
      expect(index.normal.length, greaterThan(500));
      expect(index.difficult.length, greaterThan(500));
      expect(index.accepted.length, greaterThan(index.normal.length));

      for (var seed = 0; seed < 5; seed++) {
        final puzzle = buildBeePuzzle(index, Random(seed));

        expect(puzzle.letters, hasLength(kBeeLetterCount));
        expect(
          puzzle.wordsOf(BeeTier.normal).length,
          greaterThanOrEqualTo(kBeeMinNormalWords),
          reason: 'seed $seed left the yellow bar too thin',
        );
        expect(
          puzzle.listedWords.length,
          greaterThanOrEqualTo(kBeeMinListedWords),
          reason: 'seed $seed left too little to find',
        );
        // Every hive can spell at least the pangram it was seeded from, and
        // that word is an everyday one rather than a dictionary curiosity.
        expect(
          puzzle.wordsOf(BeeTier.normal).any(
            (word) => isBeePangram(word, puzzle.letters),
          ),
          isTrue,
          reason: 'seed $seed left the pangram bonus out of reach',
        );
        expect(puzzle.bonusWords, isNotEmpty);
        if (language == 'en') {
          expect(puzzle.letters, isNot(contains('S')));
        }
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
