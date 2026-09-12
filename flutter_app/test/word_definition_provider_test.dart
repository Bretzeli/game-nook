import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/dictionary/dictionary_repository.dart';
import 'package:flutter_app/core/dictionary/word_definition.dart';
import 'package:flutter_app/core/dictionary/word_definition_provider.dart';

/// Serves entries from a map instead of the bundled asset, and counts how
/// often it was asked.
class _StubRepository extends DictionaryRepository {
  _StubRepository(this.entries);

  final Map<String, WordDefinition> entries;
  int lookups = 0;

  @override
  Future<WordDefinition?> define(String languageCode, String word) async {
    lookups++;
    if (languageCode != 'en') return null;
    return entries[word.toUpperCase()];
  }
}

WordDefinition _definition(
  String word, {
  List<WordMeaning> meanings = const [],
  List<String> synonyms = const [],
}) {
  return WordDefinition(
    word: word,
    meanings: meanings,
    synonyms: synonyms,
    antonyms: const [],
  );
}

ProviderContainer _containerWith(_StubRepository repository) {
  return ProviderContainer.test(
    overrides: [dictionaryRepositoryProvider.overrideWithValue(repository)],
  );
}

Future<WordDefinition?> _lookUp(
  ProviderContainer container,
  String languageCode,
  String word,
) {
  return container.read(
    wordDefinitionProvider((languageCode: languageCode, word: word)).future,
  );
}

void main() {
  test('serves the entry the repository has', () async {
    final repository = _StubRepository({
      'CRANE': _definition(
        'CRANE',
        meanings: const [
          WordMeaning(
            partOfSpeech: 'Noun',
            definition: 'a large long-necked wading bird',
            relatedTerms: [],
            examples: [],
          ),
        ],
      ),
    });

    final definition = await _lookUp(_containerWith(repository), 'en', 'CRANE');

    expect(definition, isNotNull);
    expect(definition!.meanings.single.definition, contains('wading bird'));
  });

  test('a word the dictionary has nothing on stays null', () async {
    final definition = await _lookUp(
      _containerWith(_StubRepository(const {})),
      'en',
      'CRANE',
    );

    expect(definition, isNull);
  });

  test('a language without a dictionary stays null', () async {
    final repository = _StubRepository({'CRANE': _definition('CRANE')});

    final definition = await _lookUp(_containerWith(repository), 'de', 'CRANE');

    expect(definition, isNull);
  });

  test('an entry with nothing in it counts as no explanation', () async {
    // Abbreviations in particular are present but empty; offering to explain
    // one would open a dialog with nothing in it.
    final repository = _StubRepository({'AD': _definition('AD')});

    final definition = await _lookUp(_containerWith(repository), 'en', 'AD');

    expect(definition, isNull);
  });

  test('an entry with only synonyms still counts as an explanation', () async {
    final repository = _StubRepository({
      'AD': _definition('AD', synonyms: const ['Anno domini']),
    });

    final definition = await _lookUp(_containerWith(repository), 'en', 'AD');

    expect(definition, isNotNull);
    expect(definition!.synonyms, contains('Anno domini'));
  });

  test('an empty word is not looked up at all', () async {
    final repository = _StubRepository(const {});

    expect(await _lookUp(_containerWith(repository), 'en', ''), isNull);
    expect(repository.lookups, 0);
  });
}
