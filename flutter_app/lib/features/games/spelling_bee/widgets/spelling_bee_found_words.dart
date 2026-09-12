import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/layout/responsive_scale.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../domain/spelling_bee_models.dart';
import 'spelling_bee_palette.dart';

/// One word as the list shows it.
class _Entry {
  const _Entry({
    required this.word,
    required this.tier,
    required this.found,
    required this.isPangram,
  });

  final String word;
  final BeeTier tier;
  final bool found;
  final bool isPangram;
}

/// The words found so far — and, once the player has given up, the ones they
/// did not find, greyed out beside them.
///
/// Wide layouts get a panel next to the hive, narrow ones a single scrolling
/// line that opens into the full list, because on a phone the hive needs the
/// height more than the list does.
class SpellingBeeFoundWords extends StatelessWidget {
  const SpellingBeeFoundWords({
    super.key,
    required this.strings,
    required this.found,
    required this.puzzle,
    required this.revealed,
    required this.compact,
  });

  final AppStrings strings;

  /// Newest first.
  final List<BeeFoundWord> found;

  final BeePuzzle puzzle;
  final bool revealed;
  final bool compact;

  int get _listedFound =>
      found.where((word) => word.tier != BeeTier.bonus).length;

  int get _listedTotal => puzzle.listedWords.length;

  List<_Entry> _entries() {
    if (!revealed) {
      return [
        for (final word in found)
          _Entry(
            word: word.word,
            tier: word.tier,
            found: true,
            isPangram: word.isPangram,
          ),
      ];
    }

    // Giving up turns the list into the answer sheet: every listed word in
    // tier order, with the rare ones the player did find kept at the end so
    // their finds are never dropped from view.
    final foundWords = {for (final word in found) word.word: word};
    return [
      for (final tier in kBeeListedTiers)
        for (final word in puzzle.wordsOf(tier))
          _Entry(
            word: word,
            tier: tier,
            found: foundWords.containsKey(word),
            isPangram: isBeePangram(word, puzzle.letters),
          ),
      for (final word in found)
        if (word.tier == BeeTier.bonus)
          _Entry(
            word: word.word,
            tier: BeeTier.bonus,
            found: true,
            isPangram: word.isPangram,
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries();
    return compact
        ? _buildStrip(context, entries)
        : _buildPanel(context, entries);
  }

  Widget _buildStrip(BuildContext context, List<_Entry> entries) {
    final decor = context.decor;

    return SizedBox(
      height: context.rs(34),
      child: Row(
        children: [
          _CountButton(
            label: strings.spellingBeeFoundOf(_listedFound, _listedTotal),
            onTap: entries.isEmpty ? null : () => _openSheet(context, entries),
          ),
          SizedBox(width: context.rs(8)),
          Expanded(
            child: entries.isEmpty
                ? Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      strings.spellingBeeNoWordsYet,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontSize: 11,
                        color: decor.subtleTextColor.withValues(alpha: 0.7),
                      ),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: entries.length,
                    separatorBuilder: (context, _) =>
                        SizedBox(width: context.rs(6)),
                    itemBuilder: (context, index) => Center(
                      child: _WordChip(
                        entry: entries[index],
                        animateIn: !revealed,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(BuildContext context, List<_Entry> entries) {
    final decor = context.decor;
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(context.rs(12)),
      decoration: BoxDecoration(
        color: decor.cardColor.withValues(alpha: 0.55),
        borderRadius: decor.cardRadius,
        border: Border.all(color: decor.subtleNavBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_list_bulleted_rounded,
                size: context.rs(14),
                color: decor.subtleTextColor,
              ),
              SizedBox(width: context.rs(6)),
              Text(
                strings.spellingBeeWordsLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: decor.subtleTextColor,
                ),
              ),
              const Spacer(),
              Text(
                strings.spellingBeeFoundOf(_listedFound, _listedTotal),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 11,
                  color: decor.subtleTextColor,
                ),
              ),
            ],
          ),
          SizedBox(height: context.rs(10)),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      strings.spellingBeeNoWordsYet,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: decor.subtleTextColor.withValues(alpha: 0.7),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: _wrap(context, entries),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _wrap(BuildContext context, List<_Entry> entries) {
    return Wrap(
      spacing: context.rs(6),
      runSpacing: context.rs(6),
      children: [
        for (final entry in entries)
          _WordChip(entry: entry, animateIn: !revealed),
      ],
    );
  }

  void _openSheet(BuildContext context, List<_Entry> entries) {
    final decor = context.decor;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: decor.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: decor.cardRadius,
          side: BorderSide(color: decor.cardBorderColor),
        ),
        title: Text(
          strings.spellingBeeWordsLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        content: SizedBox(
          width: context.rs(360),
          child: SingleChildScrollView(child: _wrap(context, entries)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              strings.spellingBeeClose,
              style: TextStyle(color: decor.accentColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountButton extends StatelessWidget {
  const _CountButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final theme = Theme.of(context);

    final chip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rs(9),
        vertical: context.rs(5),
      ),
      decoration: BoxDecoration(
        color: decor.cardColor.withValues(alpha: 0.5),
        borderRadius: decor.buttonRadius,
        border: Border.all(color: decor.subtleNavBorder, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.format_list_bulleted_rounded,
            size: context.rs(12),
            color: decor.subtleTextColor,
          ),
          SizedBox(width: context.rs(5)),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: 11,
              color: decor.subtleTextColor,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: chip,
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  const _WordChip({required this.entry, required this.animateIn});

  final _Entry entry;
  final bool animateIn;

  @override
  Widget build(BuildContext context) {
    final palette = SpellingBeePalette.of(context);
    final theme = Theme.of(context);
    final color = palette.colorFor(entry.tier);
    final found = entry.found;

    final chip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rs(8),
        vertical: context.rs(4),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: found ? 0.16 : 0.05),
        borderRadius: BorderRadius.circular(context.rs(20)),
        border: Border.all(
          color: color.withValues(alpha: found ? 0.55 : 0.22),
          width: entry.isPangram && found ? 1 : 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (entry.isPangram) ...[
            Icon(
              Icons.star_rounded,
              size: context.rs(11),
              color: color.withValues(alpha: found ? 1 : 0.35),
            ),
            SizedBox(width: context.rs(3)),
          ],
          Text(
            entry.word,
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: 11,
              letterSpacing: 0.4,
              fontWeight: found ? FontWeight.w600 : FontWeight.w400,
              // A word that was missed keeps its tier's colour, faintly: the
              // answer sheet should still show which bar it belonged to.
              color: color.withValues(alpha: found ? 1 : 0.5),
            ),
          ),
        ],
      ),
    );

    if (!animateIn) return chip;

    // Plays once, when the word first joins the list.
    var animated = chip
        .animate(key: ValueKey('chip-${entry.word}'))
        .fadeIn(duration: 240.ms)
        .scaleXY(
          begin: 0.5,
          end: 1,
          duration: 420.ms,
          curve: Curves.easeOutBack,
        );
    if (entry.isPangram) {
      animated = animated.shimmer(
        delay: 200.ms,
        duration: 1200.ms,
        color: color.withValues(alpha: 0.8),
        padding: 0,
      );
    }
    return animated;
  }
}
