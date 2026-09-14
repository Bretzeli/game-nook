enum WordlePhase { loading, playing, won, lost, failed }

extension WordlePhaseX on WordlePhase {
  bool get isFinished => this == WordlePhase.won || this == WordlePhase.lost;
}

/// What asking for a hint did.
enum WordleHintOutcome {
  /// The row was filled with a word that could still be the solution.
  filled,

  /// Every other candidate has been ruled out, so the only word left to fill
  /// in would be the solution itself — the player gets to decide.
  onlySolutionLeft,

  /// No game is running.
  unavailable,
}
