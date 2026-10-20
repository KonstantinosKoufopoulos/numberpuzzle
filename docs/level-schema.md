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
