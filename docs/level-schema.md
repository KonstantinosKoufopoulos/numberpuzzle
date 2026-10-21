# Level data schema (v1)

File: `assets/levels/levels.json` – parsed by `lib/engine/level.dart`
(`LevelPack.fromJson` + `validate()`), tested in `test/engine/level_test.dart`.

```json
{ "schemaVersion": 1, "levels": [ { ...level... } ] }
```

| Field | Type | Req. | Meaning |
|---|---|---|---|
| `id` | int | ✓ | 1..N, contiguous, in order |
| `columns` | int 4–9 | ✓ | board width |
| `rows` | int 3–12 | ✓ | starting rows |
| `seed` | int | – | generator seed (default `id*7919`) |
| `tier` | int 1–5 | – | difficulty tier (default 1) |
| `goals` | list | ✓ | see goal types |
| `layers` | object | – | `stars`, `grass`, `stone`, `ice{count,hpMin,hpMax}`, `slime` |
| `digitWeights` | 9 numbers | – | relative weights for digits 1..9 (uniform if absent) |
| `addNumbersLimit` | int | – | default **5** |
| `gift` | `hammer`\|`swap` | – | booster granted on first win |
| `introduces` | `stars`\|`grass`\|`stone`\|`ice`\|`slime` | – | shows first-time explainer card |
| `note` | string | – | designer note |

`layers.stars/grass/slime` default to the sum of the matching goal counts.

### Goal types
| type | fields | completes when |
|---|---|---|
| `number` | `value` 1–9, `count` | `count` cells with digit `value` cleared |
| `star` | `count` | stars collected (number on a star cleared) |
| `grass` | `count` | grass cells cleared |
| `breakIce` | `count` | ice blocks broken (`count ≤ layers.ice.count`) |
| `slime` | `count` | slime blobs removed |
| `pairsSame` | `count` | pairs of equal numbers (tutorial L1) |
| `pairsTen` | `count` | pairs of different numbers summing to 10 (tutorial L2) |

### Layers / rules
* **star, grass**: on a number; collected when that number is cleared.
* **stone**: permanent, no number, blocks lines like a number.
* **ice** (hp 1–2): covers a number; not selectable; −1 hp for every cleared
  cell among its 8 neighbours; selectable at 0 hp.
* **slime**: no number, blocks lines; removed when all 8 neighbours are empty
  (off-board counts as empty). Never spreads grass.
* Moves: pair, addNumbers, hammer(cell), swap(a,b), undo. Rows that become
  fully empty are removed.

### Map stars (single function `starsForWin`)
3 = no boosters; 2 = one booster; 1 = two or more. Add numbers and undo never count.

### Validation
Number goals need `value`; counts > 0; layer counts ≥ goal needs; ice hp
`1 ≤ hpMin ≤ hpMax ≤ 2`; stone+slime ≤ cells/4; all obstacles ≤ cells/2;
unknown `gift`/`introduces`/goal type rejected.

### Generator constraints (M1)
* Stones never in corners and never fill a whole row.
* Slime never adjacent to stone.
* Each ice placed next to at least one free valid pair.
* Stars and grass only on cells the solver clears in its winning line.
* Solver proves goals reachable **without boosters or ads** using at most
  `solverAddLimit = 3` Add numbers (stricter than the in-game 5).
* If unsolvable: reseed (`seed + attempt`) and retry.

### Example table row → JSON
| id | size | goals | stone | ice | introduces | gift | tier |
|---|---|---|---|---|---|---|---|
| 24 | 8×7 | ★6 + 3 breakIce | 2 | 3 × hp2 | – | – | 4 |

```json
{"id":24,"columns":8,"rows":7,"seed":190056,"tier":4,
 "goals":[{"type":"star","count":6},{"type":"breakIce","count":3}],
 "layers":{"stars":6,"stone":2,"ice":{"count":3,"hpMin":2,"hpMax":2}},
 "addNumbersLimit":5}
```

### M1 engine decisions
* `GameState` (lib/engine/game.dart) is immutable; undo restores the previous
  snapshot (board, goal progress, Add numbers used). `boostersUsed` is never
  rolled back so undo cannot restore a 3-star rating.
* Hammer: number → cleared (collects star/grass, damages adjacent ice);
  ice-covered number → whole ice removed (counts as broken), number stays;
  slime → removed; stone/empty → not allowed. Hammer clears don't count as
  pairs for `pairsSame`/`pairsTen`.
* Swap: exchanges digits of two selectable numbers; star/grass stay put.
* Goal `number` counts every cleared cell with that digit, including copies
  appended by Add numbers.
* Generator also keeps slime away from other slime and ice and out of
  corners (so it can always be uncovered). Seeds actually used per level are
  in `docs/generated-seeds.md`.
* `minPairs` (generator option, default 0 = off): boards whose goals can be
  met in fewer pairs are rejected. Checked with `shortWinCheck`, a
  depth-limited DFS with a memo on board key (not an exhaustive proof) and a
  fixed node budget (`minPairsNodeBudget`, default 20000; deterministic and
  machine-independent); exhausting it rejects the board and reseeds. Generator/CI only, never on device.
* Star/grass placement is always "late": the board is first solved without
  stars/grass (goal: clear extra cells), then stars/grass go only on cells
  cleared at pair index >= max(3, pairs/2) of that line, spread apart
  (max-min Chebyshev distance, stars first), and the final board is
  re-verified (no boosters, <= 3 Add numbers). There is NO fallback: if no
  seed works, generation throws `StateError` naming the level.
* Star spacing: no two stars on 8-neighbour cells (Chebyshev distance
  >= 2, `kMinStarDistance`); enforced at placement (attempt reseeds if not
  enough spaced cells) and asserted in CI over all 30 levels.
* First-pair rule: no star/grass cell is part of any valid pair on the
  starting board (depth 1, no Add numbers); asserted in CI.
* Goal-minPairs (star/grass goals only): the minimum number of pairs needed
  to collect ALL star+grass goals, checked without Add numbers via
  `shortWinCheck` (fixed 10,000 nodes per depth), must be >= target:
  L7 5, L8 5, L15 4, L25 4, L22 7, else 4. Not met within budget -> best
  board with goal-minPairs >= 3 is kept and flagged `BEST-EFFORT` in
  `docs/level-metrics.md` (currently: **level 22**, 6 of 7).
* `requireGreedyWinLevels` (default {1-6, 15, 25}, revertible flag): the
  greedy player must win without boosters within the level's 5 Add numbers.
  Level 13 (grass 10 + number 10) is intentionally excluded: no seed within
  50 seeds / 3M nodes passes the greedy check; to be checked in playtest by
  Takaros.
* Level 14 was reduced to star 6 + grass 6 (from grass 12) so it satisfies
  these rules; all 30 levels must generate (CI asserts no errors).
* Per-level deterministic cap: `maxReseeds` (50 per placement mode) and
  `levelNodeBudget` (3,000,000 solver/check nodes summed over attempts).
* `greedyPairsToWin` (solver.dart) is a cheap difficulty metric; see
  `docs/level-metrics.md` (`dart run tool/level_metrics.dart`).

## Pre-baked boards (`assets/levels/boards.json`, schema v1)

Generated by `dart run tool/bake_boards.dart` from `levels.json` with the
current `SeededBoardGenerator` rules; loaded on device by
`BoardRepository` (`lib/levels/board_repository.dart`, codec in
`lib/levels/board_codec.dart`). The app never runs the generator.
After any generator/level change: re-bake and commit. CI
(`test/levels/boards_test.dart`) re-bakes and requires a byte-identical file,
and validates every board (counts, first-pair rule, goal-minPairs, greedy-win
levels, solution replay via `verifyLine` + `GameState`, ≤ 3 Add numbers,
0 boosters). The bake fails (exit 1) naming the level if one cannot be generated.

```json
{"schemaVersion":1,"boards":[
{"id":1,"seed":7919,"seedUsed":7919,"width":5,"height":4,
 "cells":[{"n":7},{"n":3,"star":true},{"n":2,"grass":true,"ice":1},{"stone":true},{"slime":true}, ...],
 "goals":[{"type":"pairsSame","count":4}],
 "solutionLength":4,"solution":[[0,1],"add",[12,16]],
 "metrics":{"attempts":1,"pairs":4,"addNumbers":0,"greedyPairs":4,
            "goalMinPairs":null,"goalMinPairsTarget":null,"goalMinPairsMet":null}}
]}
```

* `cells`: row-major, `width*height` entries. `n` digit; `star`/`grass` layers;
  `ice` = hp; `stone`/`slime` number-less obstacles.
* `solution`: `[a,b]` pair (indices on the board at that moment), `"add"` = Add numbers.
* One board per line, stable key order (deterministic, diff-friendly).
