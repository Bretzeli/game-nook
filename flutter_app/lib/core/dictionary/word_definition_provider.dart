import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dictionary_repository.dart';
import 'word_definition.dart';

/// One dictionary lookup: a word, in the language whose dictionary should be
/// searched.
typedef WordLookup = ({String languageCode, String word});

/// What the dictionary has to say about a word, or `null` when there is
/// nothing to say — the language has no bundled dictionary, the word isn't in
/// it, or the entry is empty.
///
/// A non-null value therefore means "there is an explanation worth showing",
/// which is exactly the question a caller wanting to offer one needs answered.
final wordDefinitionProvider =
    FutureProvider.family<WordDefinition?, WordLookup>((ref, lookup) async {
      if (lookup.word.isEmpty) return null;

      final definition = await ref
          .watch(dictionaryRepositoryProvider)
          .define(lookup.languageCode, lookup.word);

      if (definition == null || !definition.hasExplanation) return null;
      return definition;
    });
