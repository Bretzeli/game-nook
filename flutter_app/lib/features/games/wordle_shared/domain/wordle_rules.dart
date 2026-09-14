import 'dart:typed_data';

import 'wordle_models.dart';

/// Scores [guess] against [solution] with the usual two-pass rule: exact hits
/// first, then remaining letters are matched against the leftover pool so that
/// duplicate letters cannot be over-reported.
List<LetterStatus> evaluateGuess(String guess, String solution) {
  final length = solution.length;
  final statuses = List<LetterStatus>.filled(length, LetterStatus.absent);
  final remaining = <String, int>{};

  for (var i = 0; i < length; i++) {
    if (guess[i] == solution[i]) {
      statuses[i] = LetterStatus.correct;
    } else {
      remaining.update(solution[i], (value) => value + 1, ifAbsent: () => 1);
    }
  }

  for (var i = 0; i < length; i++) {
    if (statuses[i] == LetterStatus.correct) continue;
    final letter = guess[i];
    final left = remaining[letter] ?? 0;
    if (left > 0) {
      statuses[i] = LetterStatus.present;
      remaining[letter] = left - 1;
    }
  }

  return statuses;
}

/// Whether [candidate] could still be the solution given everything the board
/// has revealed.
///
/// The test is to replay each previous guess against [candidate]: if that
/// would have produced exactly the colours the player already saw, nothing
/// learned so far rules the word out. Every surviving word is strictly closer
/// to the solution than one that was already excluded — and, because it
/// honours all greens, yellows and greys by construction, it is always a legal
/// guess in hard mode too.
bool isConsistentWith(String candidate, List<WordleRow> rows) =>
    rows.every((row) => isConsistentWithRow(candidate, row));

/// [isConsistentWith] for a single row, for narrowing a candidate list one
/// guess at a time. A row that taught nothing about [candidate] — the given-up
/// solution, or a word of another length — never rules it out.
bool isConsistentWithRow(String candidate, WordleRow row) {
  if (row.isSolution || row.word.length != candidate.length) return true;

  final replay = evaluateGuess(row.word, candidate);
  for (var i = 0; i < replay.length; i++) {
    if (replay[i] != row.statuses[i]) return false;
  }
  return true;
}

/// The [words] that [isConsistentWithRow] keeps, for sweeping whole word
/// lists: tens of thousands of words are checked against a guess the moment
/// it is submitted, so the replay runs on a reused letter count instead of
/// allocating per word.
List<String> wordsConsistentWithRow(Iterable<String> words, WordleRow row) {
  final guess = row.word;
  if (row.isSolution || guess.codeUnits.any((unit) => unit > 0xFF)) {
    return [
      for (final word in words)
        if (isConsistentWithRow(word, row)) word,
    ];
  }

  // Letters of the candidate that the guess did not hit in place, by code
  // unit; every supported letter fits in a byte.
  final unmatched = Uint8List(0x100);

  bool fits(String word) {
    if (word.length != guess.length) return true;
    final length = guess.length;

    for (var i = 0; i < length; i++) {
      final unit = word.codeUnitAt(i);
      final hit = guess.codeUnitAt(i) == unit;
      if (hit != (row.statuses[i] == LetterStatus.correct) || unit > 0xFF) {
        for (var j = 0; j < i; j++) {
          unmatched[word.codeUnitAt(j) & 0xFF] = 0;
        }
        return unit > 0xFF && isConsistentWithRow(word, row);
      }
      if (!hit) unmatched[unit]++;
    }

    var matches = true;
    for (var i = 0; i < length && matches; i++) {
      if (row.statuses[i] == LetterStatus.correct) continue;
      final unit = guess.codeUnitAt(i);
      final present = unmatched[unit] > 0;
      if (present) unmatched[unit]--;
      matches = present == (row.statuses[i] == LetterStatus.present);
    }

    for (var i = 0; i < length; i++) {
      unmatched[word.codeUnitAt(i)] = 0;
    }
    return matches;
  }

  return [
    for (final word in words)
      if (fits(word)) word,
  ];
}

/// Best status seen per letter, used to colour the keyboard. Only the first
/// [revealedRows] rows are taken into account so the keyboard updates in step
/// with the flip animation.
Map<String, LetterStatus> keyboardStatuses(
  List<WordleRow> rows,
  int revealedRows,
) {
  final result = <String, LetterStatus>{};

  for (var r = 0; r < revealedRows && r < rows.length; r++) {
    final row = rows[r];
    if (row.isSolution) continue;
    for (var i = 0; i < row.word.length; i++) {
      final letter = row.word[i];
      final status = row.statuses[i];
      final current = result[letter];
      if (current == null || _rank(status) > _rank(current)) {
        result[letter] = status;
      }
    }
  }

  return result;
}

int _rank(LetterStatus status) => switch (status) {
  LetterStatus.correct => 2,
  LetterStatus.present => 1,
  LetterStatus.absent => 0,
};

/// Everything the previous guesses revealed, in the form hard mode needs.
class HardModeConstraints {
  HardModeConstraints._({
    required this.fixedLetters,
    required this.ruledOutSpots,
    required this.minCounts,
    required this.excludedLetters,
  });

  /// Position -> letter that must stay there (green).
  final Map<int, String> fixedLetters;

  /// Letter -> positions it has already been ruled out for (yellow).
  final Map<String, Set<int>> ruledOutSpots;

  /// Letter -> how often it must appear at least.
  final Map<String, int> minCounts;

  /// Letters known not to be in the word at all (grey).
  final Set<String> excludedLetters;

  factory HardModeConstraints.fromRows(List<WordleRow> rows) {
    final fixedLetters = <int, String>{};
    final ruledOutSpots = <String, Set<int>>{};
    final minCounts = <String, int>{};
    final excluded = <String>{};
    final known = <String>{};

    for (final row in rows) {
      if (row.isSolution) continue;
      final counts = <String, int>{};

      for (var i = 0; i < row.word.length; i++) {
        final letter = row.word[i];
        switch (row.statuses[i]) {
          case LetterStatus.correct:
            fixedLetters[i] = letter;
            known.add(letter);
            counts.update(letter, (value) => value + 1, ifAbsent: () => 1);
          case LetterStatus.present:
            (ruledOutSpots[letter] ??= <int>{}).add(i);
            known.add(letter);
            counts.update(letter, (value) => value + 1, ifAbsent: () => 1);
          case LetterStatus.absent:
            excluded.add(letter);
        }
      }

      counts.forEach((letter, count) {
        if (count > (minCounts[letter] ?? 0)) minCounts[letter] = count;
      });
    }

    // A letter can be grey in one spot and green/yellow in another when the
    // guess used it more often than the solution does; only letters that were
    // never confirmed are truly out.
    excluded.removeAll(known);

    return HardModeConstraints._(
      fixedLetters: fixedLetters,
      ruledOutSpots: ruledOutSpots,
      minCounts: minCounts,
      excludedLetters: excluded,
    );
  }

  /// Returns the first rule [guess] breaks, or `null` when it uses every hint.
  HardModeViolation? validate(String guess) {
    final positions = fixedLetters.keys.toList()..sort();
    for (final position in positions) {
      final letter = fixedLetters[position]!;
      if (guess[position] != letter) {
        return HardModeViolation(
          kind: HardModeViolationKind.fixedPosition,
          letter: letter,
          position: position + 1,
        );
      }
    }

    for (final entry in ruledOutSpots.entries) {
      for (final position in entry.value.toList()..sort()) {
        if (guess[position] == entry.key) {
          return HardModeViolation(
            kind: HardModeViolationKind.mustMove,
            letter: entry.key,
            position: position + 1,
          );
        }
      }
    }

    final guessCounts = <String, int>{};
    for (var i = 0; i < guess.length; i++) {
      guessCounts.update(guess[i], (value) => value + 1, ifAbsent: () => 1);
    }

    for (final entry in minCounts.entries) {
      if ((guessCounts[entry.key] ?? 0) < entry.value) {
        return HardModeViolation(
          kind: HardModeViolationKind.missingLetter,
          letter: entry.key,
        );
      }
    }

    for (final letter in excludedLetters) {
      if (guessCounts.containsKey(letter)) {
        return HardModeViolation(
          kind: HardModeViolationKind.forbiddenLetter,
          letter: letter,
        );
      }
    }

    return null;
  }
}
