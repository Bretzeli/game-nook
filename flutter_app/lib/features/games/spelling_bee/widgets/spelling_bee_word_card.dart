import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/dictionary/word_definition_dialog.dart';
import '../../../../core/dictionary/word_definition_provider.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/layout/responsive_scale.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../domain/spelling_bee_models.dart';
import 'spelling_bee_palette.dart';

/// Opens the card for one word of the list: what it is worth, which bar it
/// belongs to, and what the dictionary has to say about it.
Future<void> showSpellingBeeWordCard(
  BuildContext context, {
  required AppStrings strings,
  required String languageCode,
  required String word,
  required BeeTier tier,
  required int points,
  required bool isPangram,
  required bool found,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => SpellingBeeWordCard(
      strings: strings,
      languageCode: languageCode,
      word: word,
      tier: tier,
      points: points,
      isPangram: isPangram,
      found: found,
    ),
  );
}

/// One word, up close.
///
/// The tier's colour is only ever a tint — a wash behind the header, the
/// border, the label and the points — so the card still reads as the app's
/// own card, just one that remembers which bar the word filled.
class SpellingBeeWordCard extends ConsumerWidget {
  const SpellingBeeWordCard({
    super.key,
    required this.strings,
    required this.languageCode,
    required this.word,
    required this.tier,
    required this.points,
    required this.isPangram,
    required this.found,
  });

  final AppStrings strings;

  /// Which language's dictionary the word should be looked up in.
  final String languageCode;

  final String word;
  final BeeTier tier;
  final int points;
  final bool isPangram;

  /// `false` for a word the player missed and only sees on the answer sheet.
  final bool found;

  String get _tierLabel => switch (tier) {
    BeeTier.normal => strings.spellingBeeTierNormal,
    BeeTier.difficult => strings.spellingBeeTierDifficult,
    BeeTier.bonus => strings.spellingBeeTierBonus,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decor = context.decor;
    final theme = Theme.of(context);
    final color = SpellingBeePalette.of(context).colorFor(tier);
    final lookup = ref.watch(
      wordDefinitionProvider((languageCode: languageCode, word: word)),
    );

    return Dialog(
      backgroundColor: decor.cardColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: decor.cardRadius,
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: context.rs(420),
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, color),
            Divider(
              height: 1,
              thickness: 1,
              color: color.withValues(alpha: 0.18),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  context.rs(20),
                  context.rs(14),
                  context.rs(20),
                  context.rs(4),
                ),
                child: Column(
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
                    SizedBox(height: context.rs(10)),
                    switch (lookup) {
                      AsyncData(:final value?) => WordDefinitionContent(
                        strings: strings,
                        definition: value,
                      ),
                      AsyncLoading() => Padding(
                        padding: EdgeInsets.symmetric(vertical: context.rs(12)),
                        child: Center(
                          child: SizedBox.square(
                            dimension: context.rs(20),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: color,
                            ),
                          ),
                        ),
                      ),
                      _ => Padding(
                        padding: EdgeInsets.only(bottom: context.rs(12)),
                        child: Text(
                          strings.dictionaryNoEntry,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: decor.subtleTextColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    },
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.rs(12),
                0,
                context.rs(12),
                context.rs(8),
              ),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    strings.spellingBeeClose,
                    style: TextStyle(color: decor.accentColor),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color color) {
    final decor = context.decor;
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        context.rs(20),
        context.rs(16),
        context.rs(20),
        context.rs(16),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.14), color.withValues(alpha: 0)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: context.rs(8),
            runSpacing: context.rs(6),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Tag(
                color: color,
                icon: Icons.circle,
                iconSize: context.rs(7),
                label: _tierLabel,
              ),
              if (isPangram)
                _Tag(
                  color: color,
                  icon: Icons.star_rounded,
                  iconSize: context.rs(12),
                  label: strings.spellingBeePangramLabel,
                ),
              if (!found)
                _Tag(
                  color: decor.subtleTextColor,
                  label: strings.spellingBeeMissedLabel,
                ),
            ],
          ),
          SizedBox(height: context.rs(10)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  word,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ),
              SizedBox(width: context.rs(12)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rs(10),
                  vertical: context.rs(5),
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(context.rs(20)),
                  border: Border.all(color: color.withValues(alpha: 0.45)),
                ),
                child: Text(
                  strings.spellingBeePoints(points),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A small label above the word: its tier, and whatever else sets it apart.
class _Tag extends StatelessWidget {
  const _Tag({
    required this.color,
    required this.label,
    this.icon,
    this.iconSize,
  });

  final Color color;
  final String label;
  final IconData? icon;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: iconSize, color: color),
          SizedBox(width: context.rs(5)),
        ],
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
