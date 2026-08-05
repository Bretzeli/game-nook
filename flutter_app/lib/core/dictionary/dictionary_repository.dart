import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'word_definition.dart';

/// Looks up word meanings from the bundled per-language dictionaries at
/// `assets/dicts/{lang}/dict.json`.
///
/// This lives in core rather than any one game's feature folder because it is
/// meant to be shared: several games can plausibly want "what does this word
/// mean" (Wordle, Spelling Bee, ...), and they should all hit the same cache
/// rather than each parsing their own copy of a multi-megabyte asset.
///
/// A language's dictionary is read and decoded at most once per app session
/// — including the case where the asset doesn't exist, so repeatedly asking
/// about a language with no dictionary never touches disk again.
class DictionaryRepository {
  final Map<String, Future<Map<String, dynamic>?>> _dictionaries = {};

  /// The definition of [word] in [languageCode].
  ///
  /// Returns `null` when `assets/dicts/{languageCode}/dict.json` doesn't
  /// exist, or when the file exists but has no entry for [word].
  Future<WordDefinition?> define(String languageCode, String word) async {
    final dictionary = await _dictionaryFor(languageCode);
    if (dictionary == null) return null;

    final key = word.trim().toUpperCase();
    final entry = dictionary[key];
    if (entry is! Map<String, dynamic>) return null;

    return WordDefinition.fromJson(key, entry);
  }

  Future<Map<String, dynamic>?> _dictionaryFor(String languageCode) {
    return _dictionaries.putIfAbsent(languageCode, () => _load(languageCode));
  }

  Future<Map<String, dynamic>?> _load(String languageCode) async {
    final String content;
    try {
      content = await rootBundle.loadString(
        'assets/dicts/$languageCode/dict.json',
        cache: false,
      );
    } catch (_) {
      // No dictionary bundled for this language.
      return null;
    }

    // These files run tens of megabytes, so decoding happens off the UI
    // isolate the same way the word lists do.
    return compute(_decodeDictionary, content);
  }
}

Map<String, dynamic> _decodeDictionary(String content) =>
    json.decode(content) as Map<String, dynamic>;

final dictionaryRepositoryProvider = Provider<DictionaryRepository>((ref) {
  ref.keepAlive();
  return DictionaryRepository();
});
