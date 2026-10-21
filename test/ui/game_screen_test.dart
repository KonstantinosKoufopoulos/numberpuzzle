import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numberpuzzle/ads/ad_service.dart';
import 'package:numberpuzzle/classic/classic.dart';
import 'package:numberpuzzle/engine/board.dart';
import 'package:numberpuzzle/engine/game.dart';
import 'package:numberpuzzle/engine/cell.dart';
import 'package:numberpuzzle/engine/goals.dart';
import 'package:numberpuzzle/engine/hint.dart';
import 'package:numberpuzzle/engine/level.dart';
import 'package:numberpuzzle/game/game_result.dart';
import 'package:numberpuzzle/l10n/app_localizations.dart';
import 'package:numberpuzzle/levels/board_source.dart';
import 'package:numberpuzzle/storage/game_save_store.dart';
import 'package:numberpuzzle/ui/game/board_game_screen.dart';
import 'package:numberpuzzle/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Boards implements LevelBoardSource {
  _Boards(this.board);
  final Board? board;
  int calls = 0;
  @override
  Future<Board> boardFor(Level level) async {
    calls++;
    if (board == null) throw BoardLoadException(level.id, StateError('x'));
    return board!;
  }
}

class _Harness {
  GameResult? result;
  bool popped = false;
}

const _clear = Duration(milliseconds: 220);

Level _level(List<Goal> goals, {int id = 5, int add = 5}) =>
    Level(id: id, columns: 3, rows: 2, seed: 1, goals: goals, addNumbersLimit: add);

Future<_Harness> _pump(
  WidgetTester tester, {
  required Level level,
  Board? board,
  Map<String, int> boosters = const {'hammer': 0, 'swap': 0, 'hint': 0},
  Future<bool> Function()? rewarded,
  Hint hint = const Hint.none(),
  _Boards? boards,
  Future<void> Function(String id)? onSpent,
  bool classic = false,
  bool daily = false,
}) async {
  final h = _Harness();
  final args = GameArgs(
    level: level,
    ads: AdService.disabled(),
    boosters: boosters,
    onRequestRewarded: rewarded,
    onBoosterSpent: onSpent,
    isClassic: classic,
    isDaily: daily,
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: lightTheme,
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('el'), Locale('en')],
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              h.result = await Navigator.of(context).push<GameResult>(
                MaterialPageRoute(
                  builder: (_) => BoardGameScreen(
                    args: args,
                    boards: boards ?? _Boards(board),
                    hints: (b, p, a) async => hint,
                    clearDuration: _clear,
                  ),
                ),
              );
              h.popped = true;
            },
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
  return h;
}

Finder _cell(int i) => find.byKey(Key('cell-$i'));
String _chip(WidgetTester t, int i) =>
    t.widget<Text>(find.descendant(of: find.byKey(Key('goal-chip-$i')), matching: find.byType(Text))).data!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({GameSaveStore.tutorialKey: true}));

  testWidgets('tap pair clears with line + HUD updates', (tester) async {
    await _pump(
      tester,
      level: _level(const [Goal(GoalType.pairsTen, 2)]),
      board: Board.fromRows([
        [1, 9, 5],
        [2, 3, 8],
      ]),
    );
    expect(_chip(tester, 0), 'Pairs of 10 0/2');
    await tester.tap(_cell(0));
    await tester.pump();
    await tester.tap(_cell(1));
    await tester.pump();
    expect(find.byKey(const Key('pair-line')), findsOneWidget);
    await tester.pump(_clear);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pair-line')), findsNothing);
    expect(_chip(tester, 0), 'Pairs of 10 1/2');
    // Row 0 still has the 5, so cells 0 and 1 are now empty.
    expect(find.descendant(of: _cell(0), matching: find.text('1')), findsNothing);
  });

  testWidgets('invalid pair shakes both cells and keeps the board', (tester) async {
    await _pump(
      tester,
      level: _level(const [Goal(GoalType.pairsTen, 2)]),
      board: Board.fromRows([
        [1, 9, 5],
        [2, 3, 8],
      ]),
    );
    await tester.tap(_cell(0));
    await tester.pump();
    await tester.tap(_cell(2));
    await tester.pump();
    expect(find.byKey(const ValueKey('shake-1')), findsNWidgets(2));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shake-1')), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('hammer on stone shows ✕ and is not consumed; on a number it is', (tester) async {
    await _pump(
      tester,
      level: _level(const [Goal(GoalType.pairsTen, 2)]),
      board: Board.fromRows([
        [1, 0, 9],
        [2, 3, 8],
      ]),
      boosters: const {'hammer': 1, 'swap': 0, 'hint': 0},
    );
    Finder badge(String t) =>
        find.descendant(of: find.byKey(const Key('booster-hammer-badge')), matching: find.text(t));
    expect(badge('1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('booster-hammer')));
    await tester.pump();
    await tester.tap(_cell(1));
    await tester.pump();
    expect(find.byKey(const Key('blocked-x')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(badge('1'), findsOneWidget);
    await tester.tap(_cell(3));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsNothing);
    expect(
      find.descendant(of: find.byKey(const Key('booster-hammer-badge')), matching: find.byIcon(Icons.play_arrow)),
      findsOneWidget,
    );
  });

  testWidgets('booster at 0 shows rewarded placeholder text', (tester) async {
    await _pump(
      tester,
      level: _level(const [Goal(GoalType.pairsTen, 2)]),
      board: Board.fromRows([
        [1, 9, 5],
        [2, 3, 8],
      ]),
    );
    await tester.tap(find.byKey(const Key('booster-swap')));
    await tester.pump();
    expect(find.text('No ad available right now'), findsOneWidget);
  });

  testWidgets('win pops GameResult.win; hint counts as a booster (2★)', (tester) async {
    final h = await _pump(
      tester,
      level: _level(const [Goal(GoalType.pairsTen, 1)]),
      board: Board.fromRows([
        [1, 9, 5],
        [2, 3, 4],
      ]),
      boosters: const {'hammer': 0, 'swap': 0, 'hint': 2},
      hint: const Hint.pair(0, 1),
    );
    await tester.tap(find.byKey(const Key('booster-hint')));
    await tester.pumpAndSettle();
    await tester.tap(_cell(0));
    await tester.pump();
    await tester.tap(_cell(1));
    await tester.pump(_clear);
    await tester.pumpAndSettle();
    expect(h.popped, isTrue);
    expect(h.result!.won, isTrue);
    expect(h.result!.boostersUsed, 1);
    expect(h.result!.starsEarned, 2);
    expect(h.result!.boostersSpent, {'hint': 1});
    expect(await GameSaveStore().load(_level(const [Goal(GoalType.pairsTen, 1)])), isNull);
  });

  testWidgets('add numbers + undo do not cost stars (3★)', (tester) async {
    final h = await _pump(
      tester,
      level: _level(const [Goal(GoalType.pairsSame, 1)]),
      board: Board.fromRows([
        [1, 2, 4],
      ]),
    );
    await tester.tap(find.byKey(const Key('add-numbers')));
    await tester.pumpAndSettle();
    expect(find.text('4/5 left'), findsOneWidget);
    await tester.tap(find.byKey(const Key('booster-undo')));
    await tester.pumpAndSettle();
    expect(find.text('5/5 left'), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-numbers')));
    await tester.pumpAndSettle();
    // 1 2 4 / 1 2 4: 4 (idx 2) and 1 (idx 3) are not a pair; 1 (0) and 1 (3) are.
    await tester.tap(_cell(0));
    await tester.pump();
    await tester.tap(_cell(3));
    await tester.pump(_clear);
    await tester.pumpAndSettle();
    expect(h.result!.starsEarned, 3);
    expect(h.result!.boostersUsed, 0);
  });

  testWidgets('lose overlay: no ad text, rewarded +1 continues the same board', (tester) async {
    var answer = false;
    final h = await _pump(
      tester,
      level: _level(const [Goal(GoalType.pairsTen, 1)], add: 0),
      board: Board.fromRows([
        [1, 2, 4],
        [3, 0, 5],
      ]),
      rewarded: () async => answer,
    );
    expect(find.byKey(const Key('lose-overlay')), findsOneWidget);
    await tester.tap(find.byKey(const Key('lose-reward')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lose-no-ad')), findsOneWidget);
    expect(h.popped, isFalse);

    answer = true;
    await tester.pump(kNoAdMessageDuration); // button re-enabled
    await tester.tap(find.byKey(const Key('lose-reward')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lose-overlay')), findsNothing);
    expect(find.text('1/1 left'), findsOneWidget);
    for (final d in ['1', '2', '4', '3', '5']) {
      expect(find.descendant(of: find.byKey(const Key('board')), matching: find.text(d)), findsOneWidget);
    }
    // The granted Add numbers is usable on the same state.
    await tester.tap(find.byKey(const Key('add-numbers')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('board')), matching: find.text('1')), findsNWidgets(2));
  });

  for (final retry in [true, false]) {
    testWidgets('lose overlay ${retry ? 'Retry' : 'Map'} pops GameResult.lose(retry: $retry)', (tester) async {
      final h = await _pump(
        tester,
        level: _level(const [Goal(GoalType.pairsTen, 1)], add: 0),
        board: Board.fromRows([
          [1, 2, 4],
          [3, 0, 5],
        ]),
      );
      await tester.tap(find.byKey(Key(retry ? 'lose-retry' : 'lose-map')));
      await tester.pumpAndSettle();
      expect(h.result!.won, isFalse);
      expect(h.result!.retry, retry);
      expect(h.result!.starsEarned, 0);
    });
  }

  testWidgets('lose overlay: no-ad disables the reward button, then re-enables after a few seconds', (tester) async {
    await _pump(
      tester,
      level: _level(const [Goal(GoalType.pairsTen, 1)], add: 0),
      board: Board.fromRows([
        [1, 2, 4],
        [3, 0, 5],
      ]),
      rewarded: () async => false,
    );
    ButtonStyleButton reward() => tester.widget<ButtonStyleButton>(find.byKey(const Key('lose-reward')));
    expect(reward().onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('lose-reward')));
    await tester.pump();
    expect(find.byKey(const Key('lose-no-ad')), findsOneWidget);
    expect(find.text('No ad available right now'), findsOneWidget);
    expect(reward().onPressed, isNull);
    await tester.pump(kNoAdMessageDuration);
    expect(find.byKey(const Key('lose-no-ad')), findsNothing);
    expect(reward().onPressed, isNotNull);
  });

  for (final granted in [false, true]) {
    testWidgets(
      'lose overlay: +1 shows a spinner and is non-tappable during the close grace wait (granted: $granted)',
      (tester) async {
        final pending = Completer<bool>();
        var calls = 0;
        await _pump(
          tester,
          level: _level(const [Goal(GoalType.pairsTen, 1)], add: 0),
          board: Board.fromRows([
            [1, 2, 4],
            [3, 0, 5],
          ]),
          rewarded: () {
            calls++;
            return pending.future;
          },
        );
        ButtonStyleButton reward() => tester.widget<ButtonStyleButton>(find.byKey(const Key('lose-reward')));
        expect(find.byKey(const Key('lose-reward-spinner')), findsNothing);
        await tester.tap(find.byKey(const Key('lose-reward')));
        await tester.pump();
        expect(find.byKey(const Key('lose-reward-spinner')), findsOneWidget);
        expect(reward().onPressed, isNull);
        await tester.tap(find.byKey(const Key('lose-reward')), warnIfMissed: false);
        await tester.pump();
        expect(calls, 1);
        pending.complete(granted);
        await tester.pump();
        expect(find.byKey(const Key('lose-reward-spinner')), findsNothing);
        if (granted) {
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('lose-overlay')), findsNothing);
          expect(find.text('1/1 left'), findsOneWidget);
        } else {
          expect(find.byKey(const Key('lose-no-ad')), findsOneWidget);
          await tester.pump(kNoAdMessageDuration);
          expect(reward().onPressed, isNotNull);
        }
      },
    );
  }

  // Reviewer case: '+1' stayed disabled after a no-ad result. Every failure
  // mode of a non-null callback must re-enable the button after 3 s.
  final failures = <String, Future<bool> Function()>{
    'returns false': () async => false,
    'throws synchronously': () => throw StateError('sdk'),
    'async error': () => Future<bool>.error(StateError('sdk')),
    'never completes': () => Completer<bool>().future,
  };
  failures.forEach((name, cb) {
    testWidgets('lose overlay +1 re-enables 3 s after a no-ad result ($name)', (tester) async {
      await _pump(
        tester,
        level: _level(const [Goal(GoalType.pairsTen, 1)], add: 0),
        board: Board.fromRows([
          [1, 2, 4],
          [3, 0, 5],
        ]),
        rewarded: cb,
      );
      ButtonStyleButton reward() => tester.widget<ButtonStyleButton>(find.byKey(const Key('lose-reward')));
      expect(find.text('+1 Add numbers ▶'), findsOneWidget);
      await tester.tap(find.byKey(const Key('lose-reward')));
      await tester.pump();
      if (name == 'never completes') {
        expect(reward().onPressed, isNull, reason: 'busy while the ad is up');
        await tester.pump(kRewardedTimeout);
      }
      expect(find.byKey(const Key('lose-no-ad')), findsOneWidget);
      expect(reward().onPressed, isNull);
      await tester.pump(kNoAdMessageDuration);
      expect(find.text('+1 Add numbers ▶'), findsOneWidget);
      expect(reward().onPressed, isNotNull);
      // And it works again (second failure → disabled → re-enabled).
      await tester.tap(find.byKey(const Key('lose-reward')));
      await tester.pump();
      if (name == 'never completes') await tester.pump(kRewardedTimeout);
      expect(reward().onPressed, isNull);
      await tester.pump(kNoAdMessageDuration);
      expect(reward().onPressed, isNotNull);
    });
  });

  testWidgets('lose overlay: null callback stays disabled with the no-ad label', (tester) async {
    await _pump(
      tester,
      level: _level(const [Goal(GoalType.pairsTen, 1)], add: 0),
      board: Board.fromRows([
        [1, 2, 4],
        [3, 0, 5],
      ]),
    );
    expect(find.byKey(const Key('lose-no-ad')), findsOneWidget);
    await tester.pump(kNoAdMessageDuration * 2);
    expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('lose-reward'))).onPressed, isNull);
  });

  testWidgets('lose overlay hierarchy: title, unmet goals, filled Retry, outlined reward, text Map', (tester) async {
    await _pump(
      tester,
      level: _level(const [Goal(GoalType.pairsTen, 1), Goal(GoalType.star, 5)], add: 0),
      board: Board(3, const [
        Cell(value: 1, item: CellItem.star),
        Cell.n(2),
        Cell.n(4),
        Cell.n(3),
        Cell(obstacle: Obstacle.stone()),
        Cell.n(5),
      ]),
    );
    expect(find.text('No pairs left'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('lose-goal-1')), matching: find.text('★ 0/5')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('lose-retry')), matching: find.text('Retry')), findsOneWidget);
    expect(tester.widget(find.byKey(const Key('lose-retry'))), isA<FilledButton>());
    expect(tester.widget(find.byKey(const Key('lose-reward'))), isA<OutlinedButton>());
    expect(tester.widget(find.byKey(const Key('lose-map'))), isA<TextButton>());
    // No callback => disabled with the no-ad label.
    expect(find.byKey(const Key('lose-no-ad')), findsOneWidget);
  });

  testWidgets('lose overlay: barrier tap does not close; Android back = Map', (tester) async {
    final h = await _pump(
      tester,
      level: _level(const [Goal(GoalType.pairsTen, 1)], add: 0),
      board: Board.fromRows([
        [1, 2, 4],
        [3, 0, 5],
      ]),
    );
    await tester.tapAt(const Offset(5, 300));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lose-overlay')), findsOneWidget);
    expect(h.popped, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(h.popped, isTrue);
    expect(h.result!.won, isFalse);
    expect(h.result!.retry, isFalse);
  });

  testWidgets('booster ▶ no-ad snackbar hides on the next board tap and on its own', (tester) async {
    await _pump(
      tester,
      level: _level(const [Goal(GoalType.pairsTen, 2)]),
      board: Board.fromRows([
        [1, 9, 5],
        [2, 3, 8],
      ]),
    );
    await tester.tap(find.byKey(const Key('booster-swap')));
    await tester.pump();
    expect(find.text('No ad available right now'), findsOneWidget);
    await tester.tap(_cell(0));
    await tester.pumpAndSettle();
    expect(find.text('No ad available right now'), findsNothing);
    await tester.tap(find.byKey(const Key('booster-hammer')));
    await tester.pump();
    expect(find.text('No ad available right now'), findsOneWidget);
    await tester.pumpAndSettle(); // entrance animation, then the timer starts
    await tester.pump(kNoAdMessageDuration);
    await tester.pumpAndSettle();
    expect(find.text('No ad available right now'), findsNothing);
  });

  testWidgets('spent boosters are reported immediately and not re-subtracted on resume', (tester) async {
    final spentCalls = <String>[];
    final level = _level(const [Goal(GoalType.pairsTen, 2)]);
    await _pump(
      tester,
      level: level,
      board: Board.fromRows([
        [1, 9, 5],
        [2, 3, 8],
      ]),
      boosters: const {'hammer': 2, 'swap': 0, 'hint': 0},
      onSpent: (id) async => spentCalls.add(id),
    );
    await tester.tap(find.byKey(const Key('booster-hammer')));
    await tester.pump();
    await tester.tap(_cell(2));
    await tester.pumpAndSettle();
    expect(spentCalls, ['hammer']);
    Finder badge(String t) =>
        find.descendant(of: find.byKey(const Key('booster-hammer-badge')), matching: find.text(t));
    expect(badge('1'), findsOneWidget);
    // Resume with the shell's already-deducted inventory (1): still shows 1.
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, level: level, boards: _Boards(null), boosters: const {'hammer': 1, 'swap': 0, 'hint': 0});
    expect(badge('1'), findsOneWidget);
  });

  testWidgets('save/resume restores the in-level state without regenerating', (tester) async {
    final level = _level(const [Goal(GoalType.pairsTen, 2)]);
    await _pump(
      tester,
      level: level,
      board: Board.fromRows([
        [1, 9, 5],
        [2, 3, 8],
      ]),
    );
    await tester.tap(_cell(0));
    await tester.pump();
    await tester.tap(_cell(1));
    await tester.pump(_clear);
    await tester.pumpAndSettle();
    final saved = await GameSaveStore().load(level);
    expect(saved!.state.goalDone, [1]);

    final boards = _Boards(null); // would fail if asked
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, level: level, boards: boards);
    expect(boards.calls, 0);
    expect(_chip(tester, 0), 'Pairs of 10 1/2');
    expect(find.text('9'), findsNothing);
  });

  testWidgets('board load error shows a friendly message', (tester) async {
    await _pump(tester, level: _level(const [Goal(GoalType.pairsTen, 1)]), boards: _Boards(null));
    expect(find.byKey(const Key('board-error')), findsOneWidget);
    expect(find.text("We couldn't prepare this level. Please try again."), findsOneWidget);
  });

  testWidgets('level 1 shows a skippable tutorial, persisted', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pump(
      tester,
      level: _level(const [Goal(GoalType.pairsSame, 3)], id: 1),
      board: Board.fromRows([
        [3, 7, 5],
        [2, 6, 8],
      ]),
    );
    expect(find.byKey(const Key('tutorial')), findsOneWidget);
    expect(find.text('Tap 3 and 7: they add up to 10.'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tutorial-skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tutorial')), findsNothing);
    expect(await GameSaveStore().tutorialDone(), isTrue);
  });

  testWidgets('layers render: star, grass, stone, ice hp, slime', (tester) async {
    await _pump(
      tester,
      level: _level(const [Goal(GoalType.star, 1)]),
      board: Board(3, const [
        Cell(value: 1, item: CellItem.star),
        Cell(value: 9, grass: true),
        Cell(obstacle: Obstacle.stone()),
        Cell(value: 4, obstacle: Obstacle.ice(2)),
        Cell(obstacle: Obstacle.slime()),
        Cell(value: 6, obstacle: Obstacle.ice(1)),
      ]),
    );
    expect(find.text('★'), findsOneWidget);
    expect(_chip(tester, 0), '★ 0/1');
    expect(tester.takeException(), isNull);
  });

  group('classic', () {
    Future<void> saveClassic(List<List<int?>> rows, {int used = 0, int score = 0}) async {
      final b = Board.fromRows(rows);
      final st = GameState.restore(
        board: b,
        goals: const [],
        done: const [],
        addNumbersLimit: 5,
        addNumbersUsed: used,
        boostersUsed: 0,
        endless: true,
        score: score,
      );
      await GameSaveStore.classic().save(SavedGame(levelId: kClassicLevelId, initialBoard: b, state: st));
    }

    testWidgets('fresh game: 9 columns, score HUD, only undo, no goal chips; never wins', (tester) async {
      final boards = _Boards(null); // classic never uses the level board source
      await _pump(tester, level: classicLevel(42), boards: boards, classic: true);
      expect(boards.calls, 0);
      expect(find.text('Classic'), findsOneWidget);
      expect(find.text('Score 0'), findsOneWidget);
      expect(find.byKey(const Key('goal-chip-0')), findsNothing);
      expect(find.byKey(const Key('booster-hammer')), findsNothing);
      expect(find.byKey(const Key('booster-hint')), findsNothing);
      expect(find.byKey(const Key('booster-undo')), findsOneWidget);
      expect(find.byKey(const Key('cell-35')), findsOneWidget);
      expect(find.byKey(const Key('add-left')), findsOneWidget);
    });

    testWidgets('pairs score; clearing the board deals a new one (+bonus); resumes from its own slot', (tester) async {
      await saveClassic([
        [1, 9, null],
        [null, 5, 5],
      ], score: 30);
      await _pump(tester, level: classicLevel(1), classic: true);
      expect(find.text('Score 30'), findsOneWidget);
      await tester.tap(_cell(0));
      await tester.tap(_cell(1));
      await tester.pump(_clear);
      await tester.pumpAndSettle();
      expect(find.text('Score ${30 + kPairPoints + kRowPoints}'), findsOneWidget);
      await tester.tap(find.byKey(const Key('booster-undo')));
      await tester.pumpAndSettle();
      expect(find.text('Score 30'), findsOneWidget, reason: 'undo restores the score');
      await tester.tap(_cell(0));
      await tester.tap(_cell(1));
      await tester.pump(_clear);
      await tester.pumpAndSettle();
      await tester.tap(_cell(1)); // row 0 was removed
      await tester.tap(_cell(2));
      await tester.pump(_clear);
      await tester.pumpAndSettle();
      final s = 30 + 2 * kPairPoints + 2 * kRowPoints + kStageClearBonus;
      expect(find.text('Score $s'), findsOneWidget);
      expect(find.byKey(const Key('lose-overlay')), findsNothing);
      expect(find.byKey(const Key('cell-35')), findsOneWidget, reason: 'new 9×4 board');
      final saved = await GameSaveStore.classic().load(classicLevel(999));
      expect(saved!.state.score, s);
      expect(saved.state.endless, isTrue);
      expect(await GameSaveStore().load(_level(const [])), isNull, reason: 'level slot untouched');
    });

    testWidgets('a cleared board deals a new one with Add numbers refilled to 5/5', (tester) async {
      await saveClassic([
        [1, 9],
      ], used: 4);
      await _pump(tester, level: classicLevel(1), classic: true);
      expect(find.text('1/5 left'), findsOneWidget);
      await tester.tap(_cell(0));
      await tester.tap(_cell(1));
      await tester.pump(_clear);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cell-35')), findsOneWidget, reason: 'new 9×4 board');
      expect(find.text('5/5 left'), findsOneWidget);
    });

    testWidgets('stuck: overlay shows the score; Map pops GameResult.lose with the score', (tester) async {
      await saveClassic(
        [
          [1, 2, 3],
        ],
        used: 5,
        score: 120,
      );
      final h = await _pump(tester, level: classicLevel(1), classic: true);
      expect(find.byKey(const Key('lose-overlay')), findsOneWidget);
      expect(find.text('No more moves'), findsOneWidget);
      expect(find.byKey(const Key('lose-score')), findsOneWidget);
      await tester.tap(find.byKey(const Key('lose-map')));
      await tester.pumpAndSettle();
      expect(h.result!.won, isFalse);
      expect(h.result!.score, 120);
      expect(await GameSaveStore.classic().load(classicLevel(1)), isNull);
    });
  });

  group('save slots', () {
    testWidgets('daily has its own slot: map level in progress survives a daily; daily resumes', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final map = _level(const [Goal(GoalType.pairsSame, 3)]);
      final mapBoard = Board.fromRows([
        [1, 1, 2],
        [3, 4, 9],
      ]);
      final mapState = GameState.forLevel(map, mapBoard).pair(0, 1);
      await GameSaveStore().save(SavedGame(levelId: map.id, initialBoard: mapBoard, state: mapState));
      final daily = _level(const [Goal(GoalType.pairsSame, 3)], id: 20261021);
      await _pump(
        tester,
        level: daily,
        daily: true,
        board: Board.fromRows([
          [5, 5, 2],
          [2, 7, 8],
        ]),
      );
      await tester.tap(_cell(0));
      await tester.tap(_cell(1));
      await tester.pump(_clear);
      await tester.pumpAndSettle();
      final m = await GameSaveStore().load(map);
      expect(m, isNotNull, reason: 'map save intact');
      expect(m!.state.moveCount, 1);
      expect(m.state.board.cells, mapState.board.cells);
      expect(m.initialBoard.cells, mapBoard.cells);
      final d = await GameSaveStore.daily().load(daily);
      expect(d!.state.moveCount, 1);
      // Resume: no board source needed, state restored from the daily slot.
      final boards = _Boards(null);
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, level: daily, daily: true, boards: boards);
      expect(boards.calls, 0);
      expect(find.byKey(const Key('board-error')), findsNothing);
      await tester.tap(_cell(2));
      await tester.tap(_cell(3));
      await tester.pump(_clear);
      await tester.pumpAndSettle();
      expect((await GameSaveStore.daily().load(daily))!.state.moveCount, 2);
      expect((await GameSaveStore().load(map))!.state.moveCount, 1);
    });

    testWidgets('classic resume keeps the saved seed (same next boards)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final b = Board.fromRows([
        [1, 9],
      ]);
      final st = GameState.restore(
        board: b,
        goals: const [],
        done: const [],
        addNumbersLimit: 5,
        addNumbersUsed: 2,
        boostersUsed: 0,
        endless: true,
      );
      await GameSaveStore.classic().save(SavedGame(levelId: kClassicLevelId, initialBoard: b, state: st, seed: 777));
      await _pump(tester, level: classicLevel(123456), classic: true); // new launch = new seed
      await tester.tap(_cell(0));
      await tester.tap(_cell(1));
      await tester.pump(_clear);
      await tester.pumpAndSettle();
      final saved = (await GameSaveStore.classic().load(classicLevel(1)))!;
      expect(saved.seed, 777);
      expect(saved.state.board.cells, classicNextBoard(777, st.pair(0, 1)).cells);
    });
  });
}
