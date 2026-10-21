# M2 seam: shell ↔ game screen

Branch `m2-shell` owns map / level-start / intro+gift cards / win / lose /
progress / ad hooks. Branch `m2-gameplay` owns the board screen. They meet
only through `lib/game/game_result.dart`.

## API (`lib/game/game_result.dart`)

```dart
class GameResult {
  const GameResult({required int levelId, required bool won,
      required int boostersUsed, required int starsEarned,
      Map<String, int> boostersSpent = const {}});
  factory GameResult.win({required int levelId, required int boostersUsed,
      Map<String, int> boostersSpent = const {}}); // stars = starsForWin(boostersUsed)
  factory GameResult.lose({required int levelId, int boostersUsed = 0,
      Map<String, int> boostersSpent = const {}, bool retry = false}); // stars = 0
}

class GameArgs {
  final Level level;                 // level to play (engine/level.dart)
  final AdService ads;               // for in-level rewarded buttons (booster at 0 → ▶)
  final Map<String, int> boosters;   // inventory snapshot: 'hammer','swap','hint'
  final bool isDaily;                // always false in M2
  final Future<bool> Function()? onRequestRewarded; // in-game lose overlay continue
  final Future<void> Function(String boosterId)? onBoosterSpent; // persist -1 at spend time
}

typedef GameScreenBuilder = Widget Function(BuildContext context, GameArgs args);

class GameRoute extends MaterialPageRoute<GameResult> {
  GameRoute({required int levelId, required GameArgs args, required GameScreenBuilder builder});
}
```

## Contract for the game screen

1. Build from `GameArgs`. Do NOT show the level-start sheet, intro or gift
   cards, win or lose screens: the shell does that.
2. When the level ends, `Navigator.pop(context, GameResult.win(...))` or
   `Navigator.pop(context, GameResult.lose(...))`.
   Popping with `null` (back button) = abandoned; nothing is recorded.
3. `boostersUsed` counts hammer/swap/hint uses only. Add numbers and undo
   NEVER count (`starsForWin` in `engine/scoring.dart`: 0→3★, 1→2★, 2+→1★).
4. Call `onBoosterSpent(id)` the moment a booster leaves the inventory; the
   shell persists the decrement immediately (abandoning a level never refunds).
   `boostersSpent` in the result is informational only; the shell does NOT
   deduct it again. Boosters earned in-level from a
   rewarded ad: grant AND spend inside the level (don't add to `boostersSpent`
   unless it came from inventory) – or ask the shell owner for a callback.
5. Never show an interstitial. The shell calls
   `AdService.maybeShowInterstitial` only after the win screen's **Next**.

## Plugging in (one line)

`lib/ui/app.dart`:

```dart
const GameScreenBuilder kDefaultGameScreen = StubGameScreen.builder;
// → const GameScreenBuilder kDefaultGameScreen = BoardGameScreen.builder;
```

(or pass `gameBuilder:` to `NumberPuzzleApp`). `StubGameScreen`
(`test/support/stub_game_screen.dart`, test-only) stays as the debug/test stub: booster ± counter,
"Win (debug)", "Lose (debug)".

## Shell flow (lib/ui/level_map_screen.dart)

map node / Play N → level-start sheet (goals, star rule, Start) → gift card
(first time a `gift` level is reached; +2 boosters; key `gift:<id>`) → intro
card (first time `introduces` is seen; key `intro:<id>`) → `GameRoute` →
- won: save best stars + unlock next → WinScreen → Next ⇒ interstitial hook →
  next level's start sheet; Map ⇒ map.
- lost: no shell lose screen. The game's lose overlay offers «+1 Add
  numbers ▶» / Retry / Map; `GameResult.lose(retry: true)` ⇒ restart (no
  start sheet), `retry: false` ⇒ map.

## Progress (lib/storage/progress_store.dart)

shared_preferences key `progress`, JSON schema `v: 2`:
`{v, stars:{"<id>":1..3}, unlocked, seenIntros:[...], boosters:{id:n}}`.
Legacy `progress_v1` is read and migrated on next save. Parser is tolerant
(bad entries skipped, newer versions read best-effort). Stars never downgrade;
unlocked never decreases. `ProgressController` (ChangeNotifier) wraps it.

## Continue flow (agreed, supersedes `extraAddNumbers`)

- The lose screen is an **overlay inside the game screen** (Nionios), not a shell route.
- `GameArgs` gets `final Future<bool> Function()? onRequestRewarded;` (null = no ad offered, e.g. daily or ads unavailable).
- The overlay's «+1 Add numbers ▶» button calls `onRequestRewarded()`. On `true` (reward callback fired) the game grants **+1 Add numbers on the SAME board** (same cells, same moves, same timer/stars state) and resumes play. On `false` it stays on the overlay.
- `GameResult.lose` is returned **only when the player exits** from the overlay (Retry/Map). Continue never pops the route.
- The +1 doesn't count toward `boostersUsed` / stars (Add numbers never do).
- The shell implements `onRequestRewarded` via `AdService.showRewarded()`. `extraAddNumbers` and the shell lose-screen rewarded button have been removed (done in the m2-gameplay merge).
