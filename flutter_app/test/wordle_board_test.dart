import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/games/wordle_shared/domain/wordle_board.dart';
import 'package:flutter_app/features/games/wordle_shared/domain/wordle_models.dart';

WordleBoard _board() => WordleBoard.start(
  languageCode: 'en',
  solution: 'SNAKE',
  acceptedWords: const {'SNAKE', 'SPEAR', 'AISLE', 'CRANE'},
  round: 1,
);

WordleBoard _typed(WordleBoard board, String word) =>
    word.split('').fold(board, (board, letter) => board.typeLetter(letter));

void main() {
  test('a board without a word ignores every edit', () {
    const board = WordleBoard.empty(languageCode: 'en', wordLength: 5);

    expect(board.hasSolution, isFalse);
    expect(board.typeLetter('A'), same(board));
    expect(board.backspace(), same(board));
    expect(board.moveCursor(1), same(board));
    expect(board.revealSolution(), same(board));
  });

  test('typing normalises letters and stops at the end of the row', () {
    final board = _typed(_board(), 'sna');
    expect(board.typedWord, 'SNA');
    expect(board.cursor, 3);

    // Anything that is not a letter of the language changes nothing.
    expect(board.typeLetter('1'), same(board));

    final full = _typed(board, 'kes');
    expect(full.typedWord, 'SNAKE');
    expect(full.isInputComplete, isTrue);
    expect(full.typeLetter('X'), same(full));
  });

  test('submitting scores the row and clears the input', () {
    final board = _typed(_board(), 'SPEAR').submitInput();

    expect(board.rows.single.word, 'SPEAR');
    expect(board.rows.single.statuses.first, LetterStatus.correct);
    expect(board.guessCount, 1);
    expect(board.typedWord, isEmpty);
    expect(board.cursor, 0);
  });

  test('turns down an unfinished row and unknown words', () {
    expect(
      _typed(_board(), 'SNA').validateInput(hardMode: false)?.kind,
      WordleRejectionKind.tooShort,
    );
    expect(
      _typed(_board(), 'ZZZZZ').validateInput(hardMode: false)?.kind,
      WordleRejectionKind.notInWordList,
    );
  });

  test('hard mode only applies when asked for', () {
    // After SPEAR, AISLE moves the confirmed S away from the first slot.
    final board = _typed(_typed(_board(), 'SPEAR').submitInput(), 'AISLE');

    expect(board.validateInput(hardMode: false), isNull);
    expect(
      board.validateInput(hardMode: true)?.kind,
      WordleRejectionKind.hardMode,
    );
  });

  test('a repeated guess is only turned down when asked to', () {
    final board = _typed(_typed(_board(), 'CRANE').submitInput(), 'CRANE');

    expect(board.validateInput(hardMode: false), isNull);
    expect(
      board.validateInput(hardMode: false, rejectRepeats: true)?.kind,
      WordleRejectionKind.alreadyGuessed,
    );
  });

  test('revealing the solution adds it as a row of its own', () {
    final board = _typed(_board(), 'SP').revealSolution();

    expect(board.rows.single.word, 'SNAKE');
    expect(board.rows.single.isSolution, isTrue);
    expect(board.guessCount, 0);
    expect(board.typedWord, isEmpty);
  });

  test('filling the row replaces what was typed', () {
    final board = _typed(_board(), 'SP').fillInput('CRANE');

    expect(board.typedWord, 'CRANE');
    expect(board.cursor, 5);
    // A word that does not fit the row is ignored.
    expect(board.fillInput('CRANES'), same(board));
  });
}
