/// Map star rating (1–3) for a won level. Single source of truth.
///
/// * 3 stars: won without any booster (hammer, swap, hint). Using
///   "Add numbers" and undo does NOT reduce the rating.
/// * 2 stars: exactly one booster used.
/// * 1 star: two or more boosters used.
int starsForWin({required int boostersUsed}) {
  if (boostersUsed <= 0) return 3;
  if (boostersUsed == 1) return 2;
  return 1;
}
