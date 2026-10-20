// Per-level difficulty metrics: `dart run tool/level_metrics.dart`.
// Writes docs/level-metrics.md.
import 'dart:convert';
import 'dart:io';

import 'package:numberpuzzle/engine/generator.dart';
import 'package:numberpuzzle/engine/level.dart';
import 'package:numberpuzzle/engine/solver.dart';

void main() {
  final pack = LevelPack.fromJson(
    jsonDecode(File('assets/levels/levels.json').readAsStringSync()) as Map<String, dynamic>,
  );
  final out = StringBuffer()
    ..writeln('# Level metrics (levels 4–30)')
    ..writeln()
    ..writeln('* shortest win: smallest k with `shortWinCheck` = winnableWithin')
    ..writeln(
      '  (iterative deepening, 200000 nodes per depth, ≤ 3 Add numbers; `>k (budget at k+1)` = no win with ≤ k pairs proven, budget exhausted at k+1).',
    )
    ..writeln('* greedy: `greedyPairsToWin` (≤ level addNumbersLimit = 5 Add numbers).')
    ..writeln()
    ..writeln('* goal-minPairs: proven min pairs (no Add numbers) to collect all star+grass goals / target;')
    ..writeln('  `BEST-EFFORT` = target not reached within budget, best board kept (>= 3).')
    ..writeln()
    ..writeln('| id | seed used | attempts | late placement | shortest win | greedy pairs | goal-minPairs |')
    ..writeln('|---|---|---|---|---|---|---|');
  for (final l in pack.levels.where((l) => l.id >= 4)) {
    final GeneratedLevel g;
    try {
      g = const SeededBoardGenerator().generateDetailed(l);
    } on StateError catch (e) {
      out.writeln('| ${l.id} | FAILED | – | – | – | – | ${e.message} |');
      continue;
    }
    var shortest = 'budget';
    for (var k = 1; k <= 60; k++) {
      final r = shortWinCheck(g.board, l.goals, k, nodeBudget: 200000);
      if (r == ShortWinCheck.winnableWithin) {
        shortest = '$k';
        break;
      }
      if (r == ShortWinCheck.timedOut) {
        shortest = k > 1 ? '>${k - 1} (budget at $k)' : 'budget';
        break;
      }
    }
    final greedy = greedyPairsToWin(g.board, l.goals, addNumbersLimit: l.addNumbersLimit);
    out.writeln(
      '| ${l.id} | ${g.seedUsed} | ${g.attempts} | ${g.latePlacement ? 'yes' : 'FALLBACK'} '
      '| $shortest | ${greedy ?? 'stuck'} '
      '| ${g.goalMinPairsMet == null ? '–' : '${g.goalMinPairs} / ${g.goalMinPairsTarget} ${g.goalMinPairsMet! ? 'met' : 'BEST-EFFORT'}'} |',
    );
  }
  File('docs/level-metrics.md').writeAsStringSync(out.toString());
  stdout.write(out);
}
