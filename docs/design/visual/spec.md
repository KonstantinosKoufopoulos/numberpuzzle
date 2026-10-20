# Number Puzzle — UX spec (v0.2, Ten Crush style)

**Θέση:** «Το number match που σέβεται τη σκέψη σου». Ήρεμο, καθαρό, χωρίς χρονόμετρο, μεγάλα κελιά.

## Κανόνες & σύστημα
- Πλέγμα 9 στηλών, ψηφία 1–9. Ζευγάρι = ίσα (4-4) ή άθροισμα 10 (3-7), οριζόντια/κάθετα/διαγώνια, πάνω από κενά· το τέλος σειράς συνδέεται με την αρχή της επόμενης. Άδειες σειρές καταρρέουν.
- Χάρτης 30 επιπέδων (Κόσμος 1). Ημερήσιο & Κλασικό ως δευτερεύουσες είσοδοι στην κορυφή του χάρτη.
- Στόχοι: number(τιμή, πλήθος), star, grass, breakIce, slime. HUD: έως 3 chips στόχων.
- Στρώσεις κελιού: star, grass (κάτω από αριθμό), stone (μπλοκάρει γραμμή), ice hp1–2 (ρωγμές = hp1), slime (εξαφανίζεται όταν αδειάσουν και τα 8 γειτονικά κελιά· δεν απλώνεται, δεν αφήνει γρασίδι).
- Boosters: Σφυρί, Αλλαγή, Βοήθεια (μετρητής· στο 0 → εικονίδιο ▶ rewarded). Αναίρεση δωρεάν, απεριόριστη.
- Σφυρί σε πάγο: αφαιρεί όλο τον πάγο (hp1 ή hp2), ο αριθμός μένει. Σε πέτρα: το κελί δείχνει ✕ + ελαφρύ shake, το booster δεν καταναλώνεται.
- Αλλαγή: μετακινεί μόνο αριθμούς· αστέρι/γρασίδι μένουν στη θέση τους.
- Η Αναίρεση δεν επιστρέφει boosters.
- Προσθήκη αριθμών: δωρεάν, έως 5/επίπεδο, badge μετρητή. Πριν: «Υπάρχουν ακόμα N ζευγάρια».
- Αστέρια (**κλειδωμένο**): 3★ = κανένα booster, 2★ = ένα booster, 1★ = δύο ή περισσότερα. Η Προσθήκη αριθμών και η Αναίρεση δεν μετράνε.
- Ήττα: 0 ζευγάρια + 0 Προσθήκες → «Ξαναπαίξε» (κύριο) + προαιρετικό rewarded «+1 Προσθήκη».
- Κάρτες εισαγωγής: ★ L7, Γρασίδι L11, Πέτρα L16, Πάγος L21, Γλίτσα L26. Δώρα: Σφυρί L10, Αλλαγή L20.
- Ads (AdMob): rewarded μόνο με αίτημα χρήστη· interstitial ΜΕΤΑ την οθόνη νίκης (στο «Επόμενο»), cap 1/3 νίκες & ≥180s, ποτέ μέσα σε επίπεδο. **Χωρίς banner.** UMP consent στο πρώτο άνοιγμα.
- Τοπική αποθήκευση/συνέχεια, εξαγωγή/εισαγωγή αρχείου .json.

## Οπτικά
Γραμματοσειρά **Manrope** (SIL OFL, ελέγχθηκε: 75 γλύφοι U+0370–03FF, πλήρη μονοτονικά με τόνους/διαλυτικά), fallback Noto Sans. Κελί 38px + 2 gap (9×40 = 360dp), hit-area ≥44dp με slop 6dp. Tokens: `tokens.json`.

## Κείμενα EL / EN
| key | EL | EN |
|---|---|---|
| tagline | Το number match που σέβεται τη σκέψη σου | The number match that respects your thinking |
| consent.title | Η ιδιωτικότητά σου | Your privacy |
| consent.accept / manage | Συναίνεση / Διαχείριση επιλογών | Consent / Manage options |
| map.daily | Ημερήσιο · Σερί {n} ημέρες | Daily · {n}-day streak |
| map.classic | Κλασικό · Συνέχεια | Classic · Continue |
| map.world | Κόσμος 1 · 30 επίπεδα | World 1 · 30 levels |
| map.play | Παίξε {n} | Play {n} |
| game.level | Επίπεδο {n} | Level {n} |
| game.goals | Στόχοι · χωρίς χρονόμετρο | Goals · no timer |
| goal.number | Σβήσε {c} ζευγάρια με {v} | Clear {c} pairs of {v} |
| goal.star / grass / ice / slime | Μάζεψε {c} ★ / Καθάρισε γρασίδι / Σπάσε {c} πάγους / Καθάρισε γλίτσα | Collect {c} ★ / Clear grass / Break {c} ice / Clear slime |
| booster.hammer / swap / hint / undo | Σφυρί / Αλλαγή / Βοήθεια / Αναίρεση | Hammer / Swap / Hint / Undo |
| add.button | Προσθήκη αριθμών (δωρεάν) · {r}/5 | Add numbers (free) · {r}/5 |
| add.confirm | Υπάρχουν ακόμα {n} ζευγάρια. Προσθήκη αριθμών; | There are still {n} pairs. Add numbers? |
| add.alt | Ψάξε ζευγάρια (Βοήθεια) | Find pairs (Hint) |
| start.cta | Ξεκίνα | Start |
| start.stars | 3★ χωρίς εργαλεία · 2★ με ένα · 1★ με 2+ | 3★ no boosters · 2★ one · 1★ two or more |
| intro.ok | Κατάλαβα | Got it |
| intro.ice | Σβήσε ζευγάρι δίπλα του για να ραγίσει. | Clear a pair next to it to crack it. |
| intro.stone | Η πέτρα μπλοκάρει τη γραμμή. | Stone blocks the line. |
| gift | Δώρο: {booster}! | Gift: {booster}! |
| reward.title | Τελείωσαν οι βοήθειες | Out of hints |
| reward.offer | Δες ένα σύντομο βίντεο για 1 hint | Watch a short video for 1 hint |
| reward.no | Όχι τώρα | Not now |
| stuck.title | Δεν υπάρχουν ζευγάρια | No pairs left |
| lose.title | Τέλος κινήσεων | Out of moves |
| lose.retry | Ξαναπαίξε | Play again |
| lose.reward | Βίντεο: +1 Προσθήκη αριθμών | Video: +1 Add numbers |
| win.title | Μπράβο! | Well done! |
| win.next / map | Επόμενο επίπεδο / Χάρτης | Next level / Map |
| daily.title | Ημερήσιο παζλ | Daily puzzle |
| daily.streak / best | {n} ημέρες σερί / Καλύτερο: {n} | {n}-day streak / Best: {n} |
| daily.play | Παίξε το σημερινό | Play today's |
| settings.* | Ρυθμίσεις · Γλώσσα · Θέμα (Φωτεινό/Σκοτεινό/Σύστημα) · Ήχος · Δόνηση · Εξαγωγή προόδου · Εισαγωγή προόδου · Ιδιωτικότητα & συναίνεση · Οδηγός | Settings · Language · Theme (Light/Dark/System) · Sound · Haptics · Export progress · Import progress · Privacy & consent · Tutorial |
| tut.step | Βήμα {i} από 3 | Step {i} of 3 |
| tut.1 | Πάτησε 3 και 7: αθροίζουν 10. | Tap 3 and 7: they add up to 10. |
| tut.skip | Παράλειψη | Skip |
| intro.star | Επίπεδο 7 · Νέο: Αστέρι — Καθάρισε τη σειρά του αστεριού για να το μαζέψεις. | Level 7 · New: Star — Clear the star's row to collect it. |
| gift.hammer | Δώρο: Σφυρί ×2 — Σβήνει έναν αριθμό ή το slime, ή σπάει όλο τον πάγο. Δεν δουλεύει σε πέτρα. / Πάρε το Σφυρί | Gift: Hammer ×2 — Clears a number or slime, or breaks all the ice. Doesn't work on stone. / Take the Hammer |
| intro.grass | Επίπεδο 11 · Νέο: Γρασίδι — Σβήσε το ζευγάρι πάνω στο γρασίδι για να το καθαρίσεις. | Level 11 · New: Grass — Clear the pair on the grass to clear it. |
| intro.stone | Επίπεδο 16 · Νέο: Πέτρα — Η πέτρα μπλοκάρει τη γραμμή. | Level 16 · New: Stone — Stone blocks the line. |
| intro.ice | Επίπεδο 21 · Νέο: Πάγος — Σβήσε ζευγάρι δίπλα του για να ραγίσει. | Level 21 · New: Ice — Clear a pair next to it to crack it. |
| gift.swap | Δώρο: Αλλαγή ×2 — Άλλαξε θέση σε δύο γειτονικούς αριθμούς για νέο ζευγάρι. / Πάρε την Αλλαγή | Gift: Swap ×2 — Swap two neighbouring numbers to make a new pair. / Take the Swap |
| intro.slime | Επίπεδο 26 · Νέο: Γλίτσα — Η γλίτσα εξαφανίζεται όταν αδειάσουν και τα 8 γειτονικά της κελιά. Δεν απλώνεται ποτέ. | Level 26 · New: Slime — Slime disappears once all 8 neighbouring cells are cleared. It never spreads. |
| booster.starNote | Χρήση εργαλείου μειώνει τα αστέρια (−1★). | Using a booster costs a star (−1★). |
