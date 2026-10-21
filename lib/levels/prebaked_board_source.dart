import '../engine/board.dart';
import '../engine/level.dart';
import 'board_repository.dart';
import 'board_source.dart';

/// Default app [LevelBoardSource]: serves boards from
/// `assets/levels/boards.json` via [BoardRepository]. Never runs the generator.
class PrebakedBoardSource implements LevelBoardSource {
  PrebakedBoardSource({BoardRepository? repository}) : repository = repository ?? BoardRepository();

  final BoardRepository repository;

  /// Starting board for a map [level] (looked up by `level.id`).
  @override
  Future<Board> boardFor(Level level) => boardForTemplate(level.id);

  /// Board of the map level [templateLevelId]. For modes whose own id is not a
  /// level id (e.g. daily, keyed by date) that reuse a map level as template.
  Future<Board> boardForTemplate(int templateLevelId) async {
    try {
      return (await repository.board(templateLevelId)).board;
    } on Object catch (e) {
      throw BoardLoadException(templateLevelId, e);
    }
  }

  /// Full baked entry (goals, solution, metrics) for [templateLevelId].
  Future<BakedBoard> bakedForTemplate(int templateLevelId) => repository.board(templateLevelId);
}
