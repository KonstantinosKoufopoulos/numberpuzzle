import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numberpuzzle/levels/board_repository.dart';

class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(Uint8List.fromList(File(key).readAsBytesSync()));
}

void main() {
  test('BoardRepository loads all 30 boards', () async {
    final repo = BoardRepository(bundle: _FileBundle());
    final all = await repo.loadAll();
    expect(all, hasLength(30));
    final b = await repo.board(14);
    expect(b.levelId, 14);
    expect(b.board.length, b.width * b.height);
    expect(() => repo.board(99), throwsArgumentError);
  });
}
