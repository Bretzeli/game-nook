import 'package:flutter_app/features/games/spelling_bee/data/spelling_bee_word_repository.dart';
import 'package:flutter_app/features/games/spelling_bee/domain/spelling_bee_word_index.dart';

/// A hand-made stand-in for the bundled lists, built around the pangram
/// PRODUCE so that the seven letters of every fixture puzzle are known even
/// though the centre letter is still drawn at random.
const List<String> kFixtureNormalWords = [
  'PRODUCE',
  'RECORD',
  'CRUDE',
  'CODE',
  'CURE',
  'CORD',
  'COUP',
  'DUPE',
];

const List<String> kFixtureDifficultWords = [
  'DECOR',
  'CODER',
  'CROUP',
  'CEDE',
];

/// Accepted, but on neither list: these score bonus points.
const List<String> kFixtureBonusWords = ['CURD', 'DOUR', 'ROPE', 'EURO'];

/// Uses letters the hive does not have, so it may never turn up in a puzzle.
const String kFixtureForeignWord = 'ZEBRA';

BeeWordIndex buildFixtureIndex({
  String languageCode = 'en',
  List<String>? normal,
  List<String>? difficult,
  List<String>? bonus,
}) {
  final normalWords = normal ?? kFixtureNormalWords;
  final difficultWords = difficult ?? kFixtureDifficultWords;
  final bonusWords = bonus ?? kFixtureBonusWords;

  return BeeWordIndex(
    languageCode: languageCode,
    normal: BeeWordSet.build(normalWords, languageCode),
    difficult: BeeWordSet.build(difficultWords, languageCode),
    // The real `all.txt` holds the listed words too, so the fixture does the
    // same: bonus words are what is left after the lists are taken out.
    accepted: BeeWordSet.build([
      ...normalWords,
      ...difficultWords,
      ...bonusWords,
      kFixtureForeignWord,
    ], languageCode),
  );
}

/// Serves a fixed index, so a test knows every word that is in play.
class FixtureBeeRepository extends SpellingBeeWordRepository {
  FixtureBeeRepository({BeeWordIndex? index, Map<String, BeeWordIndex>? byLanguage})
    : _index = index ?? buildFixtureIndex(),
      _byLanguage = byLanguage ?? const {};

  final BeeWordIndex _index;

  /// Per-language indexes, for tests that switch the app language.
  final Map<String, BeeWordIndex> _byLanguage;

  @override
  Future<BeeWordIndex> index(String languageCode) async =>
      _byLanguage[languageCode] ?? _index;
}
