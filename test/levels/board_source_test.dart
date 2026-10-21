import 'package:flutter_test/flutter_test.dart';
import 'package:numberpuzzle/engine/board.dart';
import 'package:numberpuzzle/engine/goals.dart';
import 'package:numberpuzzle/engine/level.dart';
import 'package:numberpuzzle/levels/board_source.dart';

const _level = Level(id: 3, columns: 2, rows: 3, seed: 1, goals: [Goal(GoalType.pairsTen, 1)]);

void main() {
  test('generator StateError becomes BoardLoadException', () async {
    final src = GeneratedBoardSource(run: (_) async => throw StateError('no board'));
    await expectLater(src.boardFor(_level), throwsA(isA<BoardLoadException>()));
  });

  test('boards are cached per level', () async {
    var calls = 0;
    final src = GeneratedBoardSource(
      run: (_) async {
        calls++;
        return Board.fromRows([
          [1, 9],
        ]);
      },
    );
    await src.boardFor(_level);
    await src.boardFor(_level);
    expect(calls, 1);
  });

  test('default source generates level 1 in a background isolate', () async {
    final board = await GeneratedBoardSource().boardFor(_realLevel1);
    expect(board.columns, 5);
  });
}

final _realLevel1 = Level.fromJson({
  'id': 1,
  'columns': 5,
  'rows': 4,
  'goals': [
    {'type': 'pairsSame', 'count': 4},
  ],
});
