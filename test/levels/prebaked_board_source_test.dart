import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numberpuzzle/engine/generator.dart';
import 'package:numberpuzzle/engine/level.dart';
import 'package:numberpuzzle/levels/board_repository.dart';
import 'package:numberpuzzle/levels/board_source.dart';
import 'package:numberpuzzle/levels/prebaked_board_source.dart';
import 'package:numberpuzzle/storage/board_codec.dart' as save;
import 'package:numberpuzzle/ui/game/board_game_screen.dart';

import '../../tool/bake_boards.dart' as bake;

class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(Uint8List.fromList(File(key).readAsBytesSync()));
}

void main() {
  final LevelPack pack = bake.loadPack();
  final src = PrebakedBoardSource(repository: BoardRepository(bundle: _FileBundle()));

  test('prebaked source is the app default', () {
    expect(BoardGameScreen.defaultBoards, isA<PrebakedBoardSource>());
  });

  test('prebaked source returns the generator board for every level', () async {
    final gen = GeneratedBoardSource(run: (l) async => const SeededBoardGenerator().generate(l));
    expect(pack.levels, hasLength(30));
    for (final l in pack.levels) {
      final a = await src.boardFor(l), b = await gen.boardFor(l);
      expect(jsonEncode(save.boardToJson(a)), jsonEncode(save.boardToJson(b)), reason: 'level ${l.id}');
      expect(jsonEncode(save.boardToJson(await src.boardForTemplate(l.id))), jsonEncode(save.boardToJson(a)));
    }
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('unknown template id throws BoardLoadException', () async {
    await expectLater(src.boardForTemplate(999), throwsA(isA<BoardLoadException>()));
  });
}
