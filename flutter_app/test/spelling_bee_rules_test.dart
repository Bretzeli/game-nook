import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/games/spelling_bee/domain/spelling_bee_models.dart';
import 'package:flutter_app/features/games/spelling_bee/domain/spelling_bee_puzzle_factory.dart';
import 'package:flutter_app/features/games/spelling_bee/domain/spelling_bee_rules.dart';
import 'package:flutter_app/features/games/spelling_bee/domain/spelling_bee_word_index.dart';

import 'spelling_bee_fixture.dart';

const Set<String> _produce = {'P', 'R', 'O', 'D', 'U', 'C', 'E'};

BeePuzzle _puzzle({
  String center = 'C',
  Map<String, BeeTier> listed = const {
    'CODE': BeeTier.normal,
    'CRUDE': BeeTier.difficult,
  },
  Set<String> bonus = const {'CURD'},
}) {
  return BeePuzzle(
    languageCode: 'en',
    centerLetter: center,
    outerLetters: _produce.where((letter) => letter != center).toList(),
    listedWords: listed,
    bonusWords: bonus,
  );
}

void main() {
  group('scoring', () {
    test('a four letter word is worth one point', () {
      expect(beeWordPoints('CODE', _produce), 1);
    });

    test('a longer word is worth a point per letter', () {
      expect(beeWordPoints('CRUDE', _produce), 5);
      expect(beeWordPoints('RECORD', _produce), 6);
    });

    test('a pangram pays the whole hive on top', () {
      expect(isBeePangram('PRODUCE', _produce), isTrue);
      expect(beeWordPoints('PRODUCE', _produce), 7 + kBeePangramBonus);
    });

    test('a word that misses one letter is not a pangram', () {
      expect(isBeePangram('RECORD', _produce), isFalse);
    });

    test('only a word on neither list pays the rare bonus', () {
      expect(beeScoreFor('CRUDE', BeeTier.normal, _produce), 5);
      expect(beeScoreFor('CRUDE', BeeTier.difficult, _produce), 5);
      expect(
        beeScoreFor('CRUDE', BeeTier.bonus, _produce),
        5 + kBeeRareBonus,
      );
    });

    test('a bar is worth every point its words can pay', () {
      final puzzle = _puzzle();
      expect(puzzle.maxPoints[BeeTier.normal], beeWordPoints('CODE', _produce));
      expect(
        puzzle.maxPoints[BeeTier.difficult],
        beeWordPoints('CRUDE', _produce),
      );
    });
  });

  group('validateBeeWord', () {
    test('accepts a word from either list and a bonus word', () {
      final puzzle = _puzzle();
      expect(validateBeeWord('CODE', puzzle, const {}), isNull);
      expect(validateBeeWord('CRUDE', puzzle, const {}), isNull);
      expect(validateBeeWord('CURD', puzzle, const {}), isNull);
    });

    test('turns down a word below the minimum length', () {
      final rejection = validateBeeWord('COD', _puzzle(), const {});
      expect(rejection?.kind, BeeRejectionKind.tooShort);
    });

    test('names the letter that is not in the hive', () {
      final rejection = validateBeeWord('CODA', _puzzle(), const {});
      expect(rejection?.kind, BeeRejectionKind.badLetters);
      expect(rejection?.letter, 'A');
    });

    test('names the middle letter when it is missing', () {
      final rejection = validateBeeWord('DUPE', _puzzle(), const {});
      expect(rejection?.kind, BeeRejectionKind.missingCenter);
      expect(rejection?.letter, 'C');
    });

    test('a hive letter beats a missing middle letter as the reason', () {
      // Both rules are broken; the letter that is not there at all is the
      // more useful thing to be told about.
      final rejection = validateBeeWord('DUPA', _puzzle(), const {});
      expect(rejection?.kind, BeeRejectionKind.badLetters);
    });

    test('turns down a word it has already been given', () {
      final rejection = validateBeeWord('CODE', _puzzle(), const {'CODE'});
      expect(rejection?.kind, BeeRejectionKind.alreadyFound);
    });

    test('turns down letters that spell nothing', () {
      final rejection = validateBeeWord('CCCC', _puzzle(), const {});
      expect(rejection?.kind, BeeRejectionKind.notAWord);
    });
  });

  group('buildBeePuzzle', () {
    test('seeds the hive from a pangram and lists what it spells', () {
      final puzzle = buildBeePuzzle(buildFixtureIndex(), Random(7));

      expect(puzzle.letters, _produce);
      expect(puzzle.outerLetters, hasLength(kBeeOuterLetterCount));
      expect(puzzle.outerLetters, isNot(contains(puzzle.centerLetter)));

      for (final word in puzzle.listedWords.keys) {
        expect(word.length, greaterThanOrEqualTo(kBeeMinWordLength));
        expect(word.contains(puzzle.centerLetter), isTrue, reason: word);
        expect(word.split('').toSet().difference(_produce), isEmpty);
      }
      // The pangram it was seeded from always carries the middle letter, so
      // the pangram bonus is never out of reach.
      expect(puzzle.listedWords['PRODUCE'], BeeTier.normal);
    });

    test('every hive spells a pangram from the common list', () {
      final index = buildFixtureIndex();

      for (var seed = 0; seed < 16; seed++) {
        final puzzle = buildBeePuzzle(index, Random(seed));
        final pangrams = puzzle
            .wordsOf(BeeTier.normal)
            .where((word) => isBeePangram(word, puzzle.letters));

        expect(
          pangrams,
          isNotEmpty,
          reason: 'seed $seed left the pangram bonus out of reach',
        );
      }
    });

    test('splits the words across the two listed tiers', () {
      final puzzle = buildBeePuzzle(buildFixtureIndex(), Random(7));

      for (final entry in puzzle.listedWords.entries) {
        expect(
          entry.value,
          kFixtureNormalWords.contains(entry.key)
              ? BeeTier.normal
              : BeeTier.difficult,
        );
      }
      expect(puzzle.wordsOf(BeeTier.normal), isNotEmpty);
    });

    test('keeps the rest of the accepted words as bonus words', () {
      final puzzle = buildBeePuzzle(buildFixtureIndex(), Random(7));

      for (final word in puzzle.bonusWords) {
        expect(puzzle.listedWords.containsKey(word), isFalse);
        expect(puzzle.tierOf(word), BeeTier.bonus);
      }
      expect(puzzle.bonusWords, isNot(contains(kFixtureForeignWord)));
    });

    test('never draws an English hive with an S in it', () {
      final index = buildFixtureIndex(
        normal: [...kFixtureNormalWords, 'SPARKED'],
      );

      for (var seed = 0; seed < 12; seed++) {
        expect(buildBeePuzzle(index, Random(seed)).letters, _produce);
      }
    });

    test('a German hive may hold an S', () {
      final puzzle = buildBeePuzzle(
        buildFixtureIndex(
          languageCode: 'de',
          normal: ['SPRACHE', 'HASE', 'RACHE', 'SPRACH'],
          difficult: ['ASCHE'],
          bonus: ['HEER'],
        ),
        Random(3),
      );

      expect(puzzle.letters, {'S', 'P', 'R', 'A', 'C', 'H', 'E'});
    });

    test('an empty index yields no puzzle rather than a broken one', () {
      final puzzle = buildBeePuzzle(const BeeWordIndex.empty('en'), Random(1));
      expect(puzzle.isEmpty, isTrue);
    });
  });

  group('letter masks', () {
    test('a mask holds each letter once, whatever the word', () {
      expect(beeLetterCount(beeLetterMaskOf('CODED', 'en')), 4);
      expect(beeLetterCount(beeLetterMaskOf('PRODUCE', 'en')), kBeeLetterCount);
    });

    test('the letters of a mask come back in alphabetical order', () {
      expect(beeLettersOf(beeLetterMaskOf('CODE', 'en'), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'), [
        'C',
        'D',
        'E',
        'O',
      ]);
    });
  });
}
