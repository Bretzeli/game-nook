import '../domain/spelling_bee_models.dart';
import '../domain/spelling_bee_rules.dart';

class SpellingBeeGameState {
  const SpellingBeeGameState({
    required this.languageCode,
    required this.phase,
    required this.puzzle,
    required this.outerLetters,
    required this.input,
    required this.found,
    required this.scores,
    required this.revealed,
    required this.round,
  });

  SpellingBeeGameState.loading(this.languageCode)
    : phase = BeePhase.loading,
      puzzle = BeePuzzle.empty(),
      outerLetters = const [],
      input = '',
      found = const [],
      scores = const {},
      revealed = false,
      round = 0;

  final String languageCode;
  final BeePhase phase;
  final BeePuzzle puzzle;

  /// The six outer letters in the order the hive shows them. Shuffling
  /// reorders this rather than the puzzle, so a shuffle never reads as a new
  /// game.
  final List<String> outerLetters;

  /// The word being typed. It may hold letters the hive does not offer — they
  /// are shown greyed out and turned down on submit, rather than swallowed
  /// silently as they are typed.
  final String input;

  /// Everything found this round, newest first.
  final List<BeeFoundWord> found;

  final Map<BeeTier, int> scores;

  /// `true` once the player gave up and asked to see every word.
  final bool revealed;

  /// Bumped for every new puzzle so the board can reset its animations.
  final int round;

  bool get isPlaying => phase == BeePhase.playing;

  bool get isFinished => phase == BeePhase.finished;

  int get totalScore => scores.values.fold(0, (total, score) => total + score);

  int scoreOf(BeeTier tier) => scores[tier] ?? 0;

  int maxScoreOf(BeeTier tier) => puzzle.maxPoints[tier] ?? 0;

  double progressOf(BeeTier tier) =>
      beeTierProgress(scoreOf(tier), maxScoreOf(tier));

  int foundCountOf(BeeTier tier) =>
      found.where((word) => word.tier == tier).length;

  Set<String> get foundWords => {for (final word in found) word.word};

  /// Every listed word has been found, so there is nothing left to look for.
  bool get isComplete =>
      !puzzle.isEmpty &&
      kBeeListedTiers.every((tier) => scoreOf(tier) >= maxScoreOf(tier));

  bool get canGiveUp => isPlaying && !puzzle.isEmpty;

  SpellingBeeGameState copyWith({
    BeePhase? phase,
    List<String>? outerLetters,
    String? input,
    List<BeeFoundWord>? found,
    Map<BeeTier, int>? scores,
    bool? revealed,
  }) {
    return SpellingBeeGameState(
      languageCode: languageCode,
      phase: phase ?? this.phase,
      puzzle: puzzle,
      outerLetters: outerLetters ?? this.outerLetters,
      input: input ?? this.input,
      found: found ?? this.found,
      scores: scores ?? this.scores,
      revealed: revealed ?? this.revealed,
      round: round,
    );
  }
}
