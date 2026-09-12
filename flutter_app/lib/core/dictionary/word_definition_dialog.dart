import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../layout/responsive_scale.dart';
import '../theme/app_theme_extension.dart';
import 'word_definition.dart';

/// Shows everything the dictionary knows about a word.
Future<void> showWordDefinitionDialog(
  BuildContext context, {
  required AppStrings strings,
  required WordDefinition definition,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) =>
        WordDefinitionDialog(strings: strings, definition: definition),
  );
}

/// The dictionary entry for one word, in the app's card styling.
///
/// Lives in core next to the repository because the entries themselves are
/// shared: any game that can show the player a word can show this.
class WordDefinitionDialog extends StatelessWidget {
  const WordDefinitionDialog({
    super.key,
    required this.strings,
    required this.definition,
  });

  final AppStrings strings;
  final WordDefinition definition;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: decor.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: decor.cardRadius,
        side: BorderSide(color: decor.cardBorderColor),
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.dictionaryLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: decor.subtleTextColor,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: context.rs(2)),
          Text(
            definition.word,
            style: theme.textTheme.titleLarge?.copyWith(
              color: decor.accentColor,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: context.rs(420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < definition.meanings.length; i++)
                _Meaning(
                  meaning: definition.meanings[i],
                  // Only worth numbering once there is more than one.
                  index: definition.meanings.length > 1 ? i + 1 : null,
                ),
              if (definition.synonyms.isNotEmpty)
                _WordList(
                  label: strings.dictionarySynonyms,
                  words: definition.synonyms,
                ),
              if (definition.antonyms.isNotEmpty)
                _WordList(
                  label: strings.dictionaryAntonyms,
                  words: definition.antonyms,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            strings.close,
            style: TextStyle(color: decor.accentColor),
          ),
        ),
      ],
    );
  }
}

/// One sense of the word: what it is, what it means, how it is used.
class _Meaning extends StatelessWidget {
  const _Meaning({required this.meaning, required this.index});

  final WordMeaning meaning;
  final int? index;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: context.rs(14)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (meaning.partOfSpeech.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.rs(8),
                vertical: context.rs(2),
              ),
              decoration: BoxDecoration(
                color: decor.accentSecondary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(context.rs(6)),
              ),
              child: Text(
                meaning.partOfSpeech,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: decor.accentSecondary,
                  fontSize: 11,
                ),
              ),
            ),
            SizedBox(height: context.rs(5)),
          ],
          Text(
            index == null
                ? meaning.definition
                : '$index. ${meaning.definition}',
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.35),
          ),
          for (final example in meaning.examples)
            Padding(
              padding: EdgeInsets.only(
                left: context.rs(10),
                top: context.rs(4),
              ),
              child: Text(
                '“$example”',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: decor.subtleTextColor,
                  fontStyle: FontStyle.italic,
                  height: 1.3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A labelled run of related words — synonyms or antonyms.
class _WordList extends StatelessWidget {
  const _WordList({required this.label, required this.words});

  final String label;
  final List<String> words;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(top: context.rs(4)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: decor.cardBorderColor, height: context.rs(18)),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: decor.subtleTextColor,
              fontSize: 12,
            ),
          ),
          SizedBox(height: context.rs(3)),
          Text(
            words.join(', '),
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
          ),
        ],
      ),
    );
  }
}
