import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'board_codec.dart';

export 'board_codec.dart' show BakedBoard;

/// Loads the pre-baked boards from assets/levels/boards.json (produced by
/// `dart run tool/bake_boards.dart`). The app never runs the generator.
class BoardRepository {
  BoardRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const String assetPath = 'assets/levels/boards.json';
  final AssetBundle _bundle;
  Map<int, BakedBoard>? _cache;

  /// All boards keyed by level id (parsed once, then cached).
  Future<Map<int, BakedBoard>> loadAll() async =>
      _cache ??= parseBoards(jsonDecode(await _bundle.loadString(assetPath)) as Map<String, dynamic>);

  /// Board for [levelId]; throws [ArgumentError] if absent.
  Future<BakedBoard> board(int levelId) async {
    final b = (await loadAll())[levelId];
    if (b == null) throw ArgumentError.value(levelId, 'levelId', 'no pre-baked board');
    return b;
  }
}
