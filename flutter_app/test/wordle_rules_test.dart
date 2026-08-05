import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/games/wordle/domain/wordle_alphabet.dart';
import 'package:flutter_app/features/games/wordle/domain/wordle_models.dart';
import 'package:flutter_app/features/games/wordle/domain/wordle_rules.dart';

WordleRow _row(String guess, String solution) =>
    WordleRow(word: guess, statuses: evaluateGuess(guess, solution));

void main() {
  group('evaluateGuess', () {
    test('marks exact hits', () {
      expect(
        evaluateGuess('CRANE', 'CRANE'),
        List.filled(5, LetterStatus.correct),
      );
    });

    test('marks misplaced letters', () {
      expect(evaluateGuess('ANGEL', 'GLEAN'), [
        LetterStatus.present, // A
        LetterStatus.present, // N
        LetterStatus.present, // G
        LetterStatus.present, // E
        LetterStatus.present, // L
      ]);
    });

    test('does not over-report duplicates', () {
      // THERE has two E's, one of them matched exactly, so only one of the
      // three E's in the guess can still turn yellow.
      expect(evaluateGuess('EERIE', 'THERE'), [
        LetterStatus.present,
        LetterStatus.absent,
        LetterStatus.present,
        LetterStatus.absent,
        LetterStatus.correct,
      ]);
    });
  });

  group('keyboardStatuses', () {
    test('keeps the best status per letter', () {
      final rows = [_row('SPEAR', 'SNAKE'), _row('SNAIL', 'SNAKE')];

      final statuses = keyboardStatuses(rows, rows.length);

      expect(statuses['S'], LetterStatus.correct);
      expect(statuses['A'], LetterStatus.correct);
      expect(statuses['E'], LetterStatus.present);
      expect(statuses['P'], LetterStatus.absent);
    });

    test('ignores rows past the reveal and the given-up solution', () {
      final rows = [
        _row('SPEAR', 'SNAKE'),
        const WordleRow(
          word: 'SNAKE',
          statuses: [
            LetterStatus.correct,
            LetterStatus.correct,
            LetterStatus.correct,
            LetterStatus.correct,
            LetterStatus.correct,
          ],
          isSolution: true,
        ),
      ];

      expect(keyboardStatuses(rows, 1)['P'], LetterStatus.absent);
      expect(keyboardStatuses(rows, 1)['N'], isNull);
      expect(keyboardStatuses(rows, 2)['N'], isNull);
    });
  });

  group('isConsistentWith', () {
    test('keeps words that would have produced the same colours', () {
      final rows = [_row('SPEAR', 'SNAKE')];

      expect(isConsistentWith('SNAKE', rows), isTrue);
      expect(isConsistentWith('SHAVE', rows), isTrue);
    });

    test('drops words the board already ruled out', () {
      final rows = [_row('SPEAR', 'SNAKE')];

      // Uses a grey letter.
      expect(isConsistentWith('SPINE', rows), isFalse);
      // Misses a letter known to be in the word.
      expect(isConsistentWith('SILTY', rows), isFalse);
      // Moves a green letter away from its confirmed slot.
      expect(isConsistentWith('AMAZE', rows), isFalse);
      // Leaves a yellow letter in the slot it was already ruled out for —
      // there it would have come back green, not yellow.
      expect(isConsistentWith('SEDAN', rows), isFalse);
    });

    test('respects how often a duplicated letter occurs', () {
      // EERIE against THERE: exactly two E's, so a candidate with three or
      // with one cannot be the solution.
      final rows = [_row('EERIE', 'THERE')];

      expect(isConsistentWith('THERE', rows), isTrue);
      expect(isConsistentWith('EDGES', rows), isFalse);
    });

    test('a word is always consistent with its own feedback', () {
      const solution = 'GEESE';
      final rows = [
        _row('SEEDS', solution),
        _row('CRANE', solution),
        _row('TEASE', solution),
      ];

      expect(isConsistentWith(solution, rows), isTrue);
    });

    test('ignores a row filled in by giving up', () {
      const solutionRow = WordleRow(
        word: 'SNAKE',
        statuses: [
          LetterStatus.correct,
          LetterStatus.correct,
          LetterStatus.correct,
          LetterStatus.correct,
          LetterStatus.correct,
        ],
        isSolution: true,
      );

      expect(isConsistentWith('CRANE', [solutionRow]), isTrue);
    });

    test('a consistent word is always legal in hard mode', () {
      const solution = 'SNAKE';
      final rows = [_row('SPEAR', solution), _row('SHALE', solution)];
      final constraints = HardModeConstraints.fromRows(rows);

      for (final candidate in ['SNAKE', 'SCALE', 'SHAVE', 'STAGE', 'SUAVE']) {
        if (!isConsistentWith(candidate, rows)) continue;
        expect(
          constraints.validate(candidate),
          isNull,
          reason: '$candidate is consistent, so hard mode must accept it',
        );
      }
    });
  });

  group('hard mode', () {
    HardModeViolation? validate(List<WordleRow> rows, String guess) =>
        HardModeConstraints.fromRows(rows).validate(guess);

    test('accepts a guess that uses every hint', () {
      final rows = [_row('SPEAR', 'SNAKE')];

      expect(validate(rows, 'SNAKE'), isNull);
    });

    test('green letters have to stay put', () {
      final rows = [_row('SPEAR', 'SNAKE')];

      final violation = validate(rows, 'AISLE');

      expect(violation?.kind, HardModeViolationKind.fixedPosition);
      expect(violation?.letter, 'S');
      expect(violation?.position, 1);
    });

    test('known letters have to be used', () {
      final rows = [_row('SPEAR', 'SNAKE')];

      final violation = validate(rows, 'SHOTS');

      expect(violation?.kind, HardModeViolationKind.missingLetter);
      expect({'E', 'A'}, contains(violation?.letter));
    });

    test('a misplaced letter has to move somewhere else', () {
      final rows = [_row('SPEAR', 'SNAKE')];

      // A stays in the very position it was already ruled out for.
      final violation = validate(rows, 'SEDAN');

      expect(violation?.kind, HardModeViolationKind.mustMove);
      expect(violation?.letter, 'A');
      expect(violation?.position, 4);
    });

    test('grey letters must not come back', () {
      final rows = [_row('SPEAR', 'SNAKE')];

      final violation = validate(rows, 'SPARE');

      expect(violation?.kind, HardModeViolationKind.forbiddenLetter);
      expect({'P', 'R'}, contains(violation?.letter));
    });

    test('a letter greyed out only as a duplicate stays allowed', () {
      // One E in the solution, so the second E of ELEGY is grey while the
      // first is green: E itself is not ruled out.
      final rows = [_row('ELEGY', 'EARLY')];
      final constraints = HardModeConstraints.fromRows(rows);

      expect(constraints.excludedLetters, isNot(contains('E')));
      expect(constraints.minCounts['E'], 1);
      expect(constraints.validate('EARLY'), isNull);
    });

    test('counts how often a repeated letter was confirmed', () {
      final rows = [_row('SEEDS', 'GEESE')];
      final constraints = HardModeConstraints.fromRows(rows);

      // Two of the three E's showed up, so at least two have to be reused.
      expect(constraints.minCounts['E'], 2);
      expect(constraints.minCounts['S'], 1);
      expect(constraints.validate('GEESE'), isNull);
      expect(
        constraints.validate('REEVE')?.kind,
        HardModeViolationKind.missingLetter,
      );
    });
  });

  group('WordleAlphabet', () {
    test('upper-cases and keeps German letters single-width', () {
      expect(WordleAlphabet.normalizeWord('gruß', 'de'), 'GRUß');
      expect(WordleAlphabet.normalizeWord('Käfer', 'de'), 'KÄFER');
      expect(WordleAlphabet.normalizeWord('Käfer', 'de')?.length, 5);
    });

    test('rejects entries that are not plain words', () {
      expect(WordleAlphabet.normalizeWord('z.B.', 'de'), isNull);
      expect(WordleAlphabet.normalizeWord('US-Dollar', 'de'), isNull);
      expect(WordleAlphabet.normalizeWord('', 'de'), isNull);
      expect(WordleAlphabet.normalizeWord('café', 'en'), isNull);
    });

    test('trims the line endings the word lists ship with', () {
      expect(WordleAlphabet.normalizeWord('crane\r', 'en'), 'CRANE');
    });

    test('normalises single key strokes', () {
      expect(WordleAlphabet.normalizeChar('ü', 'de'), 'Ü');
      expect(WordleAlphabet.normalizeChar('ü', 'en'), isNull);
      expect(WordleAlphabet.normalizeChar('1', 'en'), isNull);
    });
  });
}
