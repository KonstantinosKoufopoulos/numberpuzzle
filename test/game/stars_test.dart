import 'package:flutter_test/flutter_test.dart';
import 'package:numberpuzzle/engine/scoring.dart';
import 'package:numberpuzzle/game/game_result.dart';

void main() {
  test('starsForWin: 0→3, 1→2, 2+→1', () {
    expect(starsForWin(boostersUsed: 0), 3);
    expect(starsForWin(boostersUsed: 1), 2);
    expect(starsForWin(boostersUsed: 2), 1);
    expect(starsForWin(boostersUsed: 7), 1);
    expect(starsForWin(boostersUsed: -1), 3);
  });

  test('GameResult.win derives stars; lose is 0 stars', () {
    expect(GameResult.win(levelId: 4, boostersUsed: 0).starsEarned, 3);
    expect(GameResult.win(levelId: 4, boostersUsed: 1).starsEarned, 2);
    expect(GameResult.win(levelId: 4, boostersUsed: 3).starsEarned, 1);
    final l = GameResult.lose(levelId: 4, boostersUsed: 2);
    expect(l.won, isFalse);
    expect(l.starsEarned, 0);
  });
}
