// Regenerates docs/generated-seeds.md: `dart run tool/gen_report.dart`.
import 'dart:convert';
import 'dart:io';

import 'package:numberpuzzle/engine/generator.dart';
import 'package:numberpuzzle/engine/level.dart';

void main() {
  final pack = LevelPack.fromJson(
    jsonDecode(File('assets/levels/levels.json').readAsStringSync()) as Map<String, dynamic>,
  );
  final sw = Stopwatch()..start();
  final out = StringBuffer()
    ..writeln('# Generated seeds (M1)')
    ..writeln()
    ..writeln('Produced by `SeededBoardGenerator` (reseed = `seed + attempt`).')
    ..writeln('Regenerate with `dart run tool/gen_report.dart`; checked by')
    ..writeln('`test/engine/generator_test.dart`.')
    ..writeln()
    ..writeln('| id | level seed | seed used | attempts | solution moves |')
    ..writeln('|---|---|---|---|---|');
  for (final l in pack.levels) {
    final g = const SeededBoardGenerator().generateDetailed(l);
    out.writeln('| ${l.id} | ${l.seed} | ${g.seedUsed} | ${g.attempts} | ${g.solution.moves.length} |');
  }
  File('docs/generated-seeds.md').writeAsStringSync(out.toString());
  stdout.writeln('total ${sw.elapsedMilliseconds} ms');
}
