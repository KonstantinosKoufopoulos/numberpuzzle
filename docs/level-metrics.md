# Level metrics (levels 4–30)

* shortest win: smallest k with `shortWinCheck` = winnableWithin
  (iterative deepening, 200000 nodes per depth, ≤ 3 Add numbers; `>k (budget at k+1)` = no win with ≤ k pairs proven, budget exhausted at k+1).
* greedy: `greedyPairsToWin` (≤ level addNumbersLimit = 5 Add numbers).

* goal-minPairs: proven min pairs (no Add numbers) to collect all star+grass goals / target;
  `BEST-EFFORT` = target not reached within budget, best board kept (>= 3).

| id | seed used | attempts | late placement | shortest win | greedy pairs | goal-minPairs |
|---|---|---|---|---|---|---|
| 4 | 31681 | 6 | yes | 5 | 31 | – |
| 5 | 39611 | 17 | yes | 4 | 5 | – |
| 6 | 47560 | 47 | yes | 5 | 21 | – |
| 7 | 55434 | 2 | yes | >3 (budget at 4) | 19 | 5 / 5 met |
| 8 | 63352 | 1 | yes | >3 (budget at 4) | 38 | 5 / 5 met |
| 9 | 71274 | 4 | yes | >3 (budget at 4) | 37 | 4 / 4 met |
| 10 | 79190 | 1 | yes | >4 (budget at 5) | 18 | 4 / 4 met |
| 11 | 87111 | 3 | yes | >5 (budget at 6) | 19 | 4 / 4 met |
| 12 | 95060 | 33 | yes | >5 (budget at 6) | 21 | 4 / 4 met |
| 13 | 102963 | 17 | yes | >6 (budget at 7) | stuck | 4 / 4 met |
| 14 | 110866 | 1 | yes | >4 (budget at 5) | 36 | 4 / 4 met |
| 15 | 118787 | 3 | yes | >3 (budget at 4) | 12 | 4 / 4 met |
| 16 | 126704 | 1 | yes | 6 | stuck | – |
| 17 | 134624 | 2 | yes | >3 (budget at 4) | 25 | 4 / 4 met |
| 18 | 142545 | 4 | yes | >4 (budget at 5) | 21 | 4 / 4 met |
| 19 | 150477 | 17 | yes | >5 (budget at 6) | stuck | 4 / 4 met |
| 20 | 158400 | 21 | yes | >5 (budget at 6) | stuck | 4 / 4 met |
| 21 | 166301 | 3 | yes | 5 | 33 | – |
| 22 | 174241 | 24 | yes | >3 (budget at 4) | 28 | 6 / 7 BEST-EFFORT |
| 23 | 182142 | 6 | yes | >4 (budget at 5) | stuck | 4 / 4 met |
| 24 | 190059 | 4 | yes | >3 (budget at 4) | 30 | 4 / 4 met |
| 25 | 197975 | 1 | yes | >4 (budget at 5) | 10 | 4 / 4 met |
| 26 | 205900 | 7 | yes | >4 (budget at 5) | 46 | 4 / 4 met |
| 27 | 213814 | 2 | yes | >2 (budget at 3) | 16 | – |
| 28 | 221747 | 16 | yes | >4 (budget at 5) | stuck | 4 / 4 met |
| 29 | 229654 | 4 | yes | >5 (budget at 6) | stuck | 4 / 4 met |
| 30 | 237575 | 6 | yes | >5 (budget at 6) | 43 | 4 / 4 met |
