import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/wordle_alphabet.dart';
import '../domain/wordle_models.dart';

/// Loads the bundled word lists and keeps the parsed results in memory.
///
/// A list is read from disk at most once per language and, because parsing
/// 340k lines is not something the UI thread should do, the scan happens in a
/// background isolate. Results are cached twice over: the word count per
/// length (which drives the length picker) and the deduplicated words of a
/// single length (which serve as solution pool and as accepted-guess set).
class WordleWordRepository {
  final Map<String, Map<int, int>> _countsByLength = {};
  final Map<String, List<String>> _wordsByLength = {};
  final Map<String, Set<String>> _acceptedWords = {};
  final Map<String, Future<void>> _queues = {};

  /// Words of [length] from the list backing [difficulty] — the pool a
  /// solution is drawn from.
  Future<List<String>> solutionPool(
    String languageCode,
    WordleDifficulty difficulty,
    int length,
  ) async {
    await _ensureParsed(languageCode, difficulty, length: length);
    return _wordsByLength[_wordsKey(languageCode, difficulty, length)] ??
        const [];
  }

  /// Every word of [length] the language knows, independent of the selected
  /// difficulty: a guess is accepted as soon as it appears here.
  Future<Set<String>> acceptedWords(String languageCode, int length) async {
    final key = _wordsKey(languageCode, WordleDifficulty.allWords, length);
    final cached = _acceptedWords[key];
    if (cached != null) return cached;

    final words = await solutionPool(
      languageCode,
      WordleDifficulty.allWords,
      length,
    );
    return _acceptedWords[key] ??= words.toSet();
  }

  /// Word lengths that hold at least [kWordleMinWordsPerLength] words in the
  /// list backing [difficulty], within the range the picker offers.
  Future<List<int>> availableLengths(
    String languageCode,
    WordleDifficulty difficulty,
  ) async {
    await _ensureParsed(languageCode, difficulty);
    final counts = _countsByLength[_listKey(languageCode, difficulty)] ?? {};

    final lengths = <int>[
      for (var length = kWordleMinLength; length <= kWordleMaxLength; length++)
        if ((counts[length] ?? 0) >= kWordleMinWordsPerLength) length,
    ];
    return lengths;
  }

  String _listKey(String languageCode, WordleDifficulty difficulty) =>
      '$languageCode/${difficulty.fileName}';

  String _wordsKey(
    String languageCode,
    WordleDifficulty difficulty,
    int length,
  ) => '${_listKey(languageCode, difficulty)}/$length';

  /// Parses the list if the caches cannot answer the request yet. Requests for
  /// the same file are queued so a list is never scanned twice in parallel.
  Future<void> _ensureParsed(
    String languageCode,
    WordleDifficulty difficulty, {
    int? length,
  }) {
    final listKey = _listKey(languageCode, difficulty);
    if (_isCached(languageCode, difficulty, length)) return Future.value();

    final previous = _queues[listKey] ?? Future.value();
    final next = previous.then((_) async {
      if (_isCached(languageCode, difficulty, length)) return;

      final content = await rootBundle.loadString(
        'assets/wordlists/$languageCode/${difficulty.fileName}',
        cache: false,
      );
      final result = await compute(
        _parseWordList,
        _ParseRequest(
          content: content,
          languageCode: languageCode,
          keepLength: length,
        ),
      );

      _countsByLength[listKey] = result.countsByLength;
      if (length != null) {
        _wordsByLength[_wordsKey(languageCode, difficulty, length)] =
            result.words;
      }
    });

    _queues[listKey] = next.catchError((_) {});
    return next;
  }

  bool _isCached(
    String languageCode,
    WordleDifficulty difficulty,
    int? length,
  ) {
    if (length != null) {
      return _wordsByLength.containsKey(
        _wordsKey(languageCode, difficulty, length),
      );
    }
    return _countsByLength.containsKey(_listKey(languageCode, difficulty));
  }
}

class _ParseRequest {
  const _ParseRequest({
    required this.content,
    required this.languageCode,
    required this.keepLength,
  });

  final String content;
  final String languageCode;
  final int? keepLength;
}

class _ParseResult {
  const _ParseResult({required this.countsByLength, required this.words});

  final Map<int, int> countsByLength;
  final List<String> words;
}

/// Runs in a background isolate: normalises every entry, drops anything that
/// is not a plain word of the language (abbreviations, hyphenated forms,
/// duplicates that only differ in case) and collects the length histogram plus
/// the words of the requested length.
_ParseResult _parseWordList(_ParseRequest request) {
  final counts = <int, int>{};
  final seen = <String>{};
  final words = <String>[];

  for (final line in const LineSplitter().convert(request.content)) {
    final word = WordleAlphabet.normalizeWord(line, request.languageCode);
    if (word == null || !seen.add(word)) continue;

    counts.update(word.length, (value) => value + 1, ifAbsent: () => 1);
    if (word.length == request.keepLength) words.add(word);
  }

  return _ParseResult(countsByLength: counts, words: words);
}
