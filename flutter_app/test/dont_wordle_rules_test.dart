import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/games/dont_wordle/domain/dont_wordle_models.dart';
import 'package:flutter_app/features/games/dont_wordle/domain/dont_wordle_rules.dart';
import 'package:flutter_app/features/games/wordle_shared/domain/wordle_models.dart';
import 'package:flutter_app/features/games/wordle_shared/domain/wordle_rules.dart';

const _solution = 'SNAKE';

/// Guesses that share no letter with the solution, so each one is survived.
const _misses = [
  'BBBBB',
  'CCCCC',
  'DDDDD',
  'FFFFF',
  'GGGGG',
  'HHHHH',
  'IIIII',
  'JJJJJ',
];

WordleRow _row(String guess) =>
    WordleRow(word: guess, statuses: evaluateGuess(guess, _solution));

List<WordleRow> _missRows(int count) => [
  for (final word in _misses.take(count)) _row(word),
];

/// Counts that never corner anyone: plenty of words, two solutions.
List<DontWordleWordsLeft> _plenty(int guesses) => [
  for (var i = 0; i <= guesses; i++) (words: 500 - i, solutions: 2),
];

DontWordleProgress _progress(
  List<WordleRow> rows,
  List<DontWordleWordsLeft> wordsLeft, {
  int avoidAttempts = 6,
}) => dontWordleProgress(
  rows: rows,
  solution: _solution,
  wordsLeft: wordsLeft,
  avoidAttempts: avoidAttempts,
);

void main() {
  group('dontWordleProgress', () {
    test('a fresh round is avoiding the word at its first guess', () {
      final progress = _progress(const [], [(words: 9000, solutions: 2000)]);

      expect(progress.phase, DontWordlePhase.avoiding);
      expect(progress.attempt, 1);
      expect(progress.attempts, 6);
      expect(progress.wordsLeft, (words: 9000, solutions: 2000));
      expect(progress.hasSurvived, isFalse);
      expect(progress.outcome, isNull);
    });

    test('follows the guesses and the words they leave', () {
      final progress = _progress(_missRows(2), [
        (words: 9000, solutions: 2000),
        (words: 3000, solutions: 400),
        (words: 700, solutions: 60),
      ]);

      expect(progress.attempt, 3);
      expect(progress.wordsLeft, (words: 700, solutions: 60));
    });

    test('guessing the solution while avoiding it ends the round', () {
      final progress = _progress([_row('BBBBB'), _row(_solution)], [
        (words: 9000, solutions: 2000),
        (words: 3000, solutions: 400),
        (words: 1, solutions: 1),
      ]);

      expect(progress.outcome, DontWordleOutcome.hitSolution);
      expect(progress.attempt, 2);
      expect(progress.hasSurvived, isFalse);
    });

    test('no other solution left is not the end while other words fit', () {
      final progress = _progress(_missRows(2), [
        (words: 9000, solutions: 2000),
        (words: 40, solutions: 3),
        (words: 2, solutions: 1),
      ]);

      expect(progress.isFinished, isFalse);
      expect(progress.phase, DontWordlePhase.avoiding);
    });

    test('only the solution left with guesses still to make corners', () {
      final progress = _progress(_missRows(5), [
        ..._plenty(4),
        (words: 1, solutions: 1),
      ]);

      // A sixth guess would have to miss the only word that fits.
      expect(progress.outcome, DontWordleOutcome.cornered);
      expect(progress.attempt, 5);
      expect(progress.hasSurvived, isFalse);
    });

    test('the last guess to survive may leave only the solution', () {
      final progress = _progress(_missRows(6), [
        ..._plenty(5),
        (words: 1, solutions: 1),
      ]);

      // Nothing more has to miss it: the single word left is there to find.
      expect(progress.isFinished, isFalse);
      expect(progress.phase, DontWordlePhase.finding);
      expect(progress.attempt, 1);
      expect(progress.hasSurvived, isTrue);
      expect(progress.wordsLeft, (words: 1, solutions: 1));
    });

    test('surviving every guess moves on to finding the word', () {
      final progress = _progress(_missRows(6), _plenty(6));

      expect(progress.phase, DontWordlePhase.finding);
      expect(progress.attempt, 1);
      expect(progress.attempts, kDontWordleFindAttempts);
      expect(progress.hasSurvived, isTrue);
    });

    test('the number of guesses to survive is up to the round', () {
      final progress = _progress(_missRows(3), _plenty(3), avoidAttempts: 3);

      expect(progress.phase, DontWordlePhase.finding);
      expect(progress.hasSurvived, isTrue);
    });

    test('while finding, a single word left is no longer a loss', () {
      final progress = _progress(_missRows(7), [
        ..._plenty(6),
        (words: 1, solutions: 1),
      ]);

      expect(progress.phase, DontWordlePhase.finding);
      expect(progress.attempt, 2);
    });

    test('finding the word wins the round', () {
      final progress = _progress([..._missRows(7), _row(_solution)], [
        ..._plenty(7),
        (words: 1, solutions: 1),
      ]);

      expect(progress.outcome, DontWordleOutcome.solved);
      expect(progress.attempt, 2);
      expect(progress.hasSurvived, isTrue);
    });

    test('missing both tries still counts as surviving', () {
      final progress = _progress(_missRows(8), _plenty(8));

      expect(progress.outcome, DontWordleOutcome.survived);
      expect(progress.hasSurvived, isTrue);
    });

    test('giving up ends the round where it stood', () {
      const solutionRow = WordleRow(
        word: _solution,
        statuses: [
          LetterStatus.correct,
          LetterStatus.correct,
          LetterStatus.correct,
          LetterStatus.correct,
          LetterStatus.correct,
        ],
        isSolution: true,
      );

      final early = _progress([_row('BBBBB'), solutionRow], _plenty(1));
      expect(early.outcome, DontWordleOutcome.gaveUp);
      expect(early.hasSurvived, isFalse);

      final late = _progress([..._missRows(6), solutionRow], _plenty(6));
      expect(late.outcome, DontWordleOutcome.gaveUp);
      expect(late.hasSurvived, isTrue);
    });

    test('knows nothing about rows it is not shown', () {
      final rows = [_row('BBBBB'), _row(_solution)];

      final earlier = dontWordleProgress(
        rows: rows.take(1),
        solution: _solution,
        wordsLeft: [
          (words: 9000, solutions: 2000),
          (words: 3000, solutions: 400),
          (words: 1, solutions: 1),
        ],
        avoidAttempts: 6,
      );

      expect(earlier.isFinished, isFalse);
      expect(earlier.attempt, 2);
      expect(earlier.wordsLeft, (words: 3000, solutions: 400));
    });
  });

  group('dontWordleHintWord', () {
    String? hint(
      List<String> solutions,
      List<String> words, {
      Random? random,
    }) => dontWordleHintWord(
      possibleSolutions: solutions,
      possibleWords: words,
      solution: _solution,
      random: random ?? Random(1),
    );

    test('prefers a word that could have been the solution', () {
      final seen = <String?>{
        for (var seed = 0; seed < 40; seed++)
          hint(
            ['SHAKE', _solution, 'STAKE'],
            ['SHAKE', 'SNARE', _solution, 'STAKE', 'SPARE'],
            random: Random(seed),
          ),
      };

      // Every other possible solution turns up, and nothing else.
      expect(seen, {'SHAKE', 'STAKE'});
    });

    test('falls back to any word that fits once no other solution does', () {
      final seen = <String?>{
        for (var seed = 0; seed < 40; seed++)
          hint(
            [_solution],
            ['SNARE', _solution, 'SPARE'],
            random: Random(seed),
          ),
      };

      expect(seen, {'SNARE', 'SPARE'});
    });

    test('has nothing to offer when only the solution fits', () {
      expect(hint([_solution], [_solution]), isNull);
    });
  });
}
