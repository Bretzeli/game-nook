import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/dictionary/dictionary_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DictionaryRepository repository;

  setUp(() => repository = DictionaryRepository());

  test('finds a known word and parses its meanings, synonyms and antonyms', () async {
    final definition = await repository.define('en', 'RUN');

    expect(definition, isNotNull);
    expect(definition!.word, 'RUN');
    expect(definition.meanings, isNotEmpty);
    expect(definition.synonyms, isNotEmpty);

    final verb = definition.meanings.firstWhere(
      (m) => m.partOfSpeech == 'Verb',
    );
    expect(verb.definition, isNotEmpty);
    expect(verb.examples, isNotEmpty);
  });

  test('a word with antonyms parses them', () async {
    final definition = await repository.define('en', 'abactinal');

    expect(definition, isNotNull);
    expect(definition!.antonyms, contains('actinal'));
  });

  test('lookup is case- and whitespace-insensitive', () async {
    final lower = await repository.define('en', '  run  ');
    final upper = await repository.define('en', 'RUN');

    expect(lower, isNotNull);
    expect(lower!.word, upper!.word);
    expect(lower.meanings.length, upper.meanings.length);
  });

  test('an unknown word returns null instead of throwing', () async {
    final definition = await repository.define(
      'en',
      'thisisnotarealenglishword',
    );

    expect(definition, isNull);
  });

  test('a language with no bundled dictionary returns null', () async {
    final definition = await repository.define('xx', 'RUN');

    expect(definition, isNull);
  });

  test('repeatedly asking about a missing language stays cheap and null', () async {
    for (var i = 0; i < 3; i++) {
      expect(await repository.define('xx', 'RUN'), isNull);
    }
  });

  test('a second lookup reuses the decoded dictionary', () async {
    // Not a timing assertion — just that the cache doesn't corrupt or
    // re-derive a different result on repeat access.
    final first = await repository.define('en', 'RUN');
    final second = await repository.define('en', 'RUN');

    expect(first!.meanings.length, second!.meanings.length);
    expect(first.synonyms, second.synonyms);
  });
}
