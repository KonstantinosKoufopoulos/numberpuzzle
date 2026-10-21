import 'package:flutter_test/flutter_test.dart';
import 'package:numberpuzzle/classic/classic.dart';
import 'package:numberpuzzle/engine/board.dart';
import 'package:numberpuzzle/engine/game.dart';
import 'package:numberpuzzle/engine/rules.dart' as rules;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('classic board: 9×4 digits, deterministic, has pairs', () {
    final a = classicBoard(7), b = classicBoard(7);
    expect(a.columns, 9);
    expect(a.length, 36);
    expect(a.cells.map((c) => c.value), b.cells.map((c) => c.value));
    expect(a.cells.every((c) => c.value != null && c.value! >= 1 && c.value! <= 9), isTrue);
    expect(rules.allValidPairs(a).length, greaterThanOrEqualTo(kClassicMinPairs));
    expect(classicBoard(8).cells.map((c) => c.value), isNot(a.cells.map((c) => c.value)));
  });

  test('endless state: no goals is never a win; score per pair/row; undo restores', () {
    var s = GameState.start(
      Board.fromRows([
        [1, 9, 4],
        [6, 2, 3],
      ]),
      const [],
      endless: true,
    );
    expect(s.status, GameStatus.playing);
    s = s.pair(0, 1);
    expect(s.score, kPairPoints);
    expect(s.isWon, isFalse);
    s = s.pair(2, 3);
    expect(s.score, 2 * kPairPoints + kRowPoints);
    expect(s.undo().score, kPairPoints);
    // Non-endless with no goals is still an immediate win (unchanged).
    expect(
      GameState.start(
        Board.fromRows([
          [1, 2],
        ]),
        const [],
      ).isWon,
      isTrue,
    );
  });

  test('nextStage refills Add numbers, adds the bonus, is not undoable', () {
    final s = GameState.start(
      Board.fromRows([
        [1, 9],
      ]),
      const [],
      endless: true,
    ).pair(0, 1);
    expect(s.board.isCleared, isTrue);
    final n = s.nextStage(classicBoard(1));
    expect(n.score, s.score + kStageClearBonus);
    expect(n.addNumbersLeft, n.addNumbersLimit);
    expect(n.canUndo, isFalse);
    expect(n.endless, isTrue);
  });

  test('best score keeps the max', () async {
    SharedPreferences.setMockInitialValues({});
    final st = ClassicStore();
    expect(await st.record(120), 120);
    expect(await st.record(80), 120);
    expect(await st.best(), 120);
  });
}
