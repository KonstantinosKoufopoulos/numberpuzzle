# Level metrics (levels 4–30)

* shortest win: smallest k with `shortWinCheck` = winnableWithin
  (iterative deepening, 200000 nodes per depth, ≤ 3 Add numbers; `>k (budget at k+1)` = no win with ≤ k pairs proven, budget exhausted at k+1).
* greedy: `greedyPairsToWin` (≤ level addNumbersLimit = 5 Add numbers).

| id | seed used | attempts | late placement | shortest win | greedy pairs |
|---|---|---|---|---|---|
| 4 | 31681 | 6 | yes | 5 | 31 |
| 5 | 39598 | 4 | yes | 4 | stuck |
| 6 | 47523 | 10 | yes | >5 (budget at 6) | stuck |
| 7 | 55433 | 1 | yes | 2 | 2 |
| 8 | 63352 | 1 | yes | 3 | 3 |
| 9 | 71274 | 4 | yes | >3 (budget at 4) | 17 |
| 10 | 79190 | 1 | yes | >4 (budget at 5) | 22 |
| 11 | 87109 | 1 | yes | >4 (budget at 5) | 6 |
| 12 | 95028 | 1 | yes | >4 (budget at 5) | 11 |
| 13 | 102957 | 11 | yes | >5 (budget at 6) | 24 |
| 14 | 110866 | 1 | yes | >6 (budget at 7) | 36 |
| 15 | 118785 | 1 | yes | >3 (budget at 4) | 4 |
| 16 | 126704 | 1 | yes | 6 | stuck |
| 17 | 134623 | 1 | yes | >3 (budget at 4) | 4 |
| 18 | 142545 | 4 | yes | >3 (budget at 4) | 19 |
| 19 | 150468 | 8 | yes | >4 (budget at 5) | 26 |
| 20 | 158388 | 9 | yes | >6 (budget at 7) | 36 |
| 21 | 166301 | 3 | yes | 5 | 33 |
| 22 | 174218 | 1 | yes | 3 | 3 |
| 23 | 182142 | 6 | yes | >4 (budget at 5) | 28 |
| 24 | 190056 | 1 | yes | >3 (budget at 4) | 8 |
| 25 | 197975 | 1 | yes | 4 | 4 |
| 26 | 205894 | 1 | yes | >3 (budget at 4) | 28 |
| 27 | 213814 | 2 | yes | >2 (budget at 3) | 16 |
| 28 | 221733 | 2 | yes | >4 (budget at 5) | 29 |
| 29 | 229653 | 3 | yes | >5 (budget at 6) | 31 |
| 30 | 237570 | 1 | yes | >4 (budget at 5) | stuck |
