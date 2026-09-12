import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sudoku_generator.dart';
import '../domain/sudoku_models.dart';
import 'sudoku_game_state.dart';
import 'sudoku_settings.dart';

/// Deals the puzzles. It is a class rather than a bare function so that a test
/// can hand the game a board it already knows the answer to.
class SudokuPuzzleFactory {
  const SudokuPuzzleFactory();

  SudokuPuzzle create({
    required SudokuSize size,
    required SudokuDifficulty difficulty,
  }) => generateSudoku(size: size, difficulty: difficulty);
}

final sudokuPuzzleFactoryProvider = Provider<SudokuPuzzleFactory>((ref) {
  ref.keepAlive();
  return const SudokuPuzzleFactory();
});

class SudokuController extends Notifier<SudokuGameState> {
  int _loadToken = 0;

  /// Counts the puzzles dealt. It lives on the notifier rather than in the
  /// state so that it keeps climbing across a rebuild of the provider.
  int _round = 0;

  @override
  SudokuGameState build() {
    ref.keepAlive();

    // Nothing here depends on the language — a board of numbers reads the same
    // in both — so switching it leaves a game in progress alone.
    final settings = ref.read(sudokuSettingsProvider);
    _start(settings.size, settings.difficulty);

    return SudokuGameState.loading();
  }

  void newGame() {
    final settings = ref.read(sudokuSettingsProvider);
    state = SudokuGameState.loading();
    _start(settings.size, settings.difficulty);
  }

  /// A board of a different size is a different board, so it starts a new one.
  void changeSize(SudokuSize size) {
    if (size == ref.read(sudokuSettingsProvider).size) return;
    ref.read(sudokuSettingsProvider.notifier).setSize(size);
    newGame();
  }

  /// So is one dug out to a different depth: a puzzle cannot be made harder
  /// once its clues are on the board.
  void changeDifficulty(SudokuDifficulty difficulty) {
    if (difficulty == ref.read(sudokuSettingsProvider).difficulty) return;
    ref.read(sudokuSettingsProvider.notifier).setDifficulty(difficulty);
    newGame();
  }

  void setNotesMode(bool enabled) =>
      ref.read(sudokuSettingsProvider.notifier).setNotesMode(enabled);

  void toggleNotesMode() =>
      setNotesMode(!ref.read(sudokuSettingsProvider).notesMode);

  void select(int index) {
    if (state.puzzle.isEmpty) return;
    if (index < 0 || index >= state.cells.length) return;
    if (state.selected == index) return;
    state = state.copyWith(selected: index);
  }

  void clearSelection() {
    if (state.selected == null) return;
    state = state.copyWith(clearSelection: true);
  }

  /// Moves the selection by a step, starting at the top left when nothing is
  /// picked out yet.
  void moveSelection({int rows = 0, int columns = 0}) {
    if (state.puzzle.isEmpty) return;

    final current = state.selected;
    if (current == null) {
      select(0);
      return;
    }

    final geometry = state.geometry;
    final last = state.length - 1;
    select(
      geometry.indexOf(
        (geometry.rowOf(current) + rows).clamp(0, last),
        (geometry.columnOf(current) + columns).clamp(0, last),
      ),
    );
  }

  /// What a value key does: the answer, or a pencil mark while notes mode is on.
  void enter(int value) {
    if (ref.read(sudokuSettingsProvider).notesMode) {
      toggleNote(value);
    } else {
      place(value);
    }
  }

  /// Writes [value] into the selected cell. Entering the value that is already
  /// there takes it back out, so one key both writes and clears.
  void place(int value) {
    final index = state.selected;
    if (!state.isPlaying || index == null) return;
    if (value < 1 || value > state.length) return;

    final cell = state.cells[index];
    if (!cell.isEditable) return;

    final next = cell.value == value ? 0 : value;
    final cells = [...state.cells];
    cells[index] = cell.copyWith(
      value: next,
      notes: const {},
      mark: SudokuMark.none,
    );
    if (next != 0) _pruneNotes(cells, index, next);

    _commit(cells);
  }

  /// Adds [value] to the selected cell's pencil marks, or takes it away again.
  void toggleNote(int value) {
    final index = state.selected;
    if (!state.isPlaying || index == null) return;
    if (value < 1 || value > state.length) return;

    final cell = state.cells[index];
    // A cell holding an answer has no room for pencil marks.
    if (!cell.isEditable || !cell.isEmpty) return;

    final notes = {...cell.notes};
    if (!notes.remove(value)) notes.add(value);

    final cells = [...state.cells];
    cells[index] = cell.copyWith(notes: notes);
    state = state.copyWith(cells: cells);
  }

  /// Empties the selected cell — its answer, or its pencil marks when there is
  /// no answer in it.
  void erase() {
    final index = state.selected;
    if (!state.isPlaying || index == null) return;

    final cell = state.cells[index];
    if (!cell.isEditable) return;
    if (cell.isEmpty && cell.notes.isEmpty) return;

    final cells = [...state.cells];
    cells[index] = cell.copyWith(
      value: 0,
      notes: const {},
      mark: SudokuMark.none,
    );
    state = state.copyWith(cells: cells);
  }

  /// Marks the selected cell right or wrong.
  SudokuCheckResult checkSelected() {
    final index = state.selected;
    if (!state.canCheckSelected || index == null) {
      return const SudokuCheckResult.none();
    }
    return _mark([index]);
  }

  /// Marks everything the player has filled in.
  SudokuCheckResult checkAll() {
    if (!state.canCheckAll) return const SudokuCheckResult.none();
    return _mark(Iterable<int>.generate(state.cells.length));
  }

  /// Takes the "right" marks back off once the player has had a moment to see
  /// them, which keeps a checked board from turning into a wall of green. The
  /// "wrong" ones stay until the cell they are about changes.
  void clearCorrectMarks() {
    if (!state.cells.any((cell) => cell.mark == SudokuMark.correct)) return;

    state = state.copyWith(
      cells: [
        for (final cell in state.cells)
          cell.mark == SudokuMark.correct
              ? cell.copyWith(mark: SudokuMark.none)
              : cell,
      ],
    );
  }

  /// Fills the selected cell in with its answer and locks it.
  void revealSelected() {
    final index = state.selected;
    if (!state.canRevealSelected || index == null) return;

    final value = state.puzzle.solution[index];
    final cells = [...state.cells];
    cells[index] = cells[index].copyWith(
      value: value,
      notes: const {},
      isRevealed: true,
      mark: SudokuMark.none,
    );
    _pruneNotes(cells, index, value);

    _commit(cells, hintsUsed: state.hintsUsed + 1);
  }

  /// Ends the round and fills the board in.
  ///
  /// Cells the player had already got right stay theirs; only the empty and the
  /// wrong ones are given away.
  void giveUp() {
    if (!state.canGiveUp) return;

    final cells = <SudokuCell>[];
    for (var index = 0; index < state.cells.length; index++) {
      final cell = state.cells[index];
      final answer = state.puzzle.solution[index];

      if (cell.isGiven || cell.value == answer) {
        cells.add(cell.copyWith(mark: SudokuMark.none));
      } else {
        cells.add(SudokuCell(value: answer, isRevealed: true));
      }
    }

    state = state.copyWith(cells: cells, phase: SudokuPhase.revealed);
  }

  /// Stores [cells] and ends the round when that filled the board in correctly.
  void _commit(List<SudokuCell> cells, {int? hintsUsed}) {
    final next = state.copyWith(cells: cells, hintsUsed: hintsUsed);
    state = next.isComplete ? next.copyWith(phase: SudokuPhase.solved) : next;
  }

  /// Takes [value] out of the pencil marks of every cell that can no longer
  /// hold it, which is what a player would otherwise do by hand.
  void _pruneNotes(List<SudokuCell> cells, int index, int value) {
    for (final peer in state.geometry.peersOf(index)) {
      final cell = cells[peer];
      if (!cell.notes.contains(value)) continue;
      cells[peer] = cell.copyWith(notes: {...cell.notes}..remove(value));
    }
  }

  SudokuCheckResult _mark(Iterable<int> indexes) {
    final cells = [...state.cells];
    var checked = 0;
    var wrong = 0;

    for (final index in indexes) {
      final cell = cells[index];
      if (!cell.isEditable || cell.isEmpty) continue;

      final correct = cell.value == state.puzzle.solution[index];
      cells[index] = cell.copyWith(
        mark: correct ? SudokuMark.correct : SudokuMark.wrong,
      );
      checked++;
      if (!correct) wrong++;
    }

    state = state.copyWith(cells: cells);
    return SudokuCheckResult(checked: checked, wrong: wrong);
  }

  Future<void> _start(SudokuSize size, SudokuDifficulty difficulty) async {
    final token = ++_loadToken;
    // Captured while it is guaranteed to be valid: after an await this tells us
    // whether the provider was disposed or rebuilt in the meantime.
    final ref = this.ref;
    final factory = ref.read(sudokuPuzzleFactoryProvider);

    // Hand the frame back first. Dealing a board is a few hundred milliseconds
    // of solid work on the largest size, and this is what lets the spinner be
    // on screen before it starts rather than after it has finished.
    await SchedulerBinding.instance.endOfFrame;
    if (token != _loadToken || !ref.mounted) return;

    try {
      final puzzle = factory.create(size: size, difficulty: difficulty);
      if (token != _loadToken || !ref.mounted) return;

      state = SudokuGameState(
        phase: SudokuPhase.playing,
        puzzle: puzzle,
        cells: [
          for (final value in puzzle.givens)
            SudokuCell(value: value, isGiven: value != 0),
        ],
        selected: null,
        hintsUsed: 0,
        round: ++_round,
      );
    } catch (_) {
      if (token != _loadToken || !ref.mounted) return;
      state = SudokuGameState.loading().copyWith(phase: SudokuPhase.failed);
    }
  }
}

final sudokuGameProvider = NotifierProvider<SudokuController, SudokuGameState>(
  SudokuController.new,
);
