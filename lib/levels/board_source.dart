/// Where starting boards come from.
///
/// The app uses `PrebakedBoardSource` (assets/levels/boards.json) as
/// `BoardGameScreen.defaultBoards`. [GeneratedBoardSource] is kept only for
/// tools and tests.
library;

import 'package:flutter/foundation.dart';

import '../engine/board.dart';
import '../engine/generator.dart';
import '../engine/level.dart';

abstract interface class LevelBoardSource {
  /// Starting board for [level]. Throws [BoardLoadException] on failure.
  Future<Board> boardFor(Level level);
}

/// A board could not be produced (e.g. generator `StateError`).
class BoardLoadException implements Exception {
  const BoardLoadException(this.levelId, this.cause);
  final int levelId;
  final Object cause;

  @override
  String toString() => 'BoardLoadException(level $levelId): $cause';
}

Board _generate(Level level) => const SeededBoardGenerator().generate(level);

/// Generates boards with [SeededBoardGenerator] off the UI thread via
/// [compute]; results are cached per level id for the app session.
class GeneratedBoardSource implements LevelBoardSource {
  GeneratedBoardSource({Future<Board> Function(Level level)? run}) : _run = run ?? ((l) => compute(_generate, l));

  final Future<Board> Function(Level level) _run;
  final Map<int, Board> _cache = {};

  @override
  Future<Board> boardFor(Level level) async {
    final cached = _cache[level.id];
    if (cached != null) return cached;
    try {
      return _cache[level.id] = await _run(level);
    } on StateError catch (e) {
      throw BoardLoadException(level.id, e);
    } on Object catch (e) {
      // Isolate errors may arrive wrapped (e.g. RemoteError).
      throw BoardLoadException(level.id, e);
    }
  }
}
