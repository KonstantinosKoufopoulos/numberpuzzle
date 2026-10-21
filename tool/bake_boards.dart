// Bakes all level boards into assets/levels/boards.json:
//   dart run tool/bake_boards.dart
// Generic: uses whatever rules SeededBoardGenerator currently has, so a rule
// change only needs a re-bake. Fails (exit 1) naming the level if any level
// cannot be generated. CI: test/levels/boards_test.dart re-bakes and compares.
import 'dart:convert';
import 'dart:io';

import 'package:numberpuzzle/engine/generator.dart';
import 'package:numberpuzzle/engine/level.dart';
import 'package:numberpuzzle/engine/moves.dart';
import 'package:numberpuzzle/engine/solver.dart';
import 'package:numberpuzzle/levels/board_codec.dart';

const String levelsPath = 'assets/levels/levels.json';
const String boardsPath = 'assets/levels/boards.json';

LevelPack loadPack([String path = levelsPath]) =>
    LevelPack.fromJson(jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>);

/// Bakes one level (throws [StateError] naming the level on failure).
BakedBoard bakeLevel(Level l, {SeededBoardGenerator gen = const SeededBoardGenerator()}) {
  final GeneratedLevel g;
  try {
    g = gen.generateDetailed(l);
  } on StateError catch (e) {
    throw StateError('bake failed for level ${l.id}: ${e.message}');
  }
  final moves = g.solution.moves;
  return BakedBoard(
    levelId: l.id,
    seed: l.seed,
    seedUsed: g.seedUsed,
    board: g.board,
    goals: l.goals,
    solution: moves,
    metrics: {
      'attempts': g.attempts,
      'pairs': moves.whereType<PairMove>().length,
      'addNumbers': moves.whereType<AddNumbersMove>().length,
      'greedyPairs': greedyPairsToWin(g.board, l.goals, addNumbersLimit: l.addNumbersLimit),
      'goalMinPairs': g.goalMinPairs,
      'goalMinPairsTarget': g.goalMinPairsTarget,
      'goalMinPairsMet': g.goalMinPairsMet,
    },
  );
}

/// Deterministic serialization: one board per line, stable key order.
String encodeBoards(List<BakedBoard> boards) {
  final b = StringBuffer('{"schemaVersion":$kBoardsSchemaVersion,"boards":[\n');
  for (var i = 0; i < boards.length; i++) {
    b.write(jsonEncode(boards[i].toJson()));
    b.write(i == boards.length - 1 ? '\n' : ',\n');
  }
  b.write(']}\n');
  return b.toString();
}

String bakeAll(LevelPack pack) => encodeBoards([for (final l in pack.levels) bakeLevel(l)]);

void main() {
  final sw = Stopwatch()..start();
  try {
    final s = bakeAll(loadPack());
    File(boardsPath).writeAsStringSync(s);
    stdout.writeln('wrote $boardsPath (${s.length} bytes) in ${sw.elapsedMilliseconds} ms');
  } on StateError catch (e) {
    stderr.writeln(e.message);
    exitCode = 1;
  }
}
