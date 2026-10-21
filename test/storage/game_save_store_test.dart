import 'package:flutter_test/flutter_test.dart';
import 'package:numberpuzzle/engine/board.dart';
import 'package:numberpuzzle/engine/cell.dart';
import 'package:numberpuzzle/engine/game.dart';
import 'package:numberpuzzle/engine/goals.dart';
import 'package:numberpuzzle/engine/level.dart';
import 'package:numberpuzzle/storage/board_codec.dart';
import 'package:numberpuzzle/storage/game_save_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _level = Level(id: 4, columns: 3, rows: 2, seed: 1, goals: [Goal(GoalType.pairsTen, 2)]);

Board _board() => Board(3, const [
  Cell(value: 1, item: CellItem.star),
  Cell(value: 9, grass: true),
  Cell(obstacle: Obstacle.stone()),
  Cell(value: 4, obstacle: Obstacle.ice(2)),
  Cell(obstacle: Obstacle.slime()),
  Cell.empty(),
]);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('board codec round-trips every layer', () {
    final b = _board();
    expect(boardFromJson(boardToJson(b)).cells, b.cells);
    expect(boardFromJson(boardToJson(b)).columns, 3);
  });

  test('save / load / clear in-level state', () async {
    final store = GameSaveStore();
    expect(await store.load(_level), isNull);
    final s = GameState.forLevel(_level, _board()).pair(0, 1);
    await store.save(SavedGame(levelId: 4, initialBoard: _board(), state: s, spent: const {'hint': 1}));
    final r = (await store.load(_level))!;
    expect(r.state.board.cells, s.board.cells);
    expect(r.state.goalDone, [1]);
    expect(r.state.moveCount, 1);
    expect(r.spent, {'hint': 1});
    expect(r.initialBoard.cells, _board().cells);
    const other = Level(id: 5, columns: 3, rows: 2, seed: 1, goals: [Goal(GoalType.pairsTen, 2)]);
    expect(await store.load(other), isNull);
    await store.clear();
    expect(await store.load(_level), isNull);
  });

  test('extra Add numbers survive the round trip', () async {
    final store = GameSaveStore();
    final s = GameState.forLevel(_level, _board()).withExtraAddNumbers(1);
    await store.save(SavedGame(levelId: 4, initialBoard: _board(), state: s));
    expect((await store.load(_level))!.state.addNumbersLimit, kDefaultAddNumbersLimit + 1);
  });

  test('malformed save is ignored', () async {
    SharedPreferences.setMockInitialValues({GameSaveStore.key: '{"v":1,"levelId":4'});
    expect(await GameSaveStore().load(_level), isNull);
  });

  test('tutorial flag persists', () async {
    final store = GameSaveStore();
    expect(await store.tutorialDone(), isFalse);
    await store.setTutorialDone();
    expect(await GameSaveStore().tutorialDone(), isTrue);
  });
}
