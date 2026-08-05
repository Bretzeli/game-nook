/// One sense of a word: its part of speech, the definition itself, a handful
/// of broader/related terms, and example sentences — mirrors the 4-element
/// arrays the dictionary assets store each meaning as.
class WordMeaning {
  const WordMeaning({
    required this.partOfSpeech,
    required this.definition,
    required this.relatedTerms,
    required this.examples,
  });

  final String partOfSpeech;
  final String definition;
  final List<String> relatedTerms;
  final List<String> examples;

  factory WordMeaning.fromJson(List<dynamic> json) {
    return WordMeaning(
      partOfSpeech: _stringAt(json, 0),
      definition: _stringAt(json, 1),
      relatedTerms: _listAt(json, 2),
      examples: _listAt(json, 3),
    );
  }

  static String _stringAt(List<dynamic> json, int index) =>
      index < json.length ? (json[index] as String? ?? '') : '';

  static List<String> _listAt(List<dynamic> json, int index) =>
      index < json.length
      ? List<String>.from(json[index] as List? ?? const [])
      : const [];
}

/// Everything the dictionary knows about one word.
class WordDefinition {
  const WordDefinition({
    required this.word,
    required this.meanings,
    required this.synonyms,
    required this.antonyms,
  });

  /// The word as it appears in the dictionary (upper case).
  final String word;
  final List<WordMeaning> meanings;
  final List<String> synonyms;
  final List<String> antonyms;

  factory WordDefinition.fromJson(String word, Map<String, dynamic> json) {
    final meanings = json['MEANINGS'] as List? ?? const [];
    return WordDefinition(
      word: word,
      meanings: [
        for (final meaning in meanings)
          WordMeaning.fromJson(meaning as List<dynamic>),
      ],
      synonyms: List<String>.from(json['SYNONYMS'] as List? ?? const []),
      antonyms: List<String>.from(json['ANTONYMS'] as List? ?? const []),
    );
  }
}
