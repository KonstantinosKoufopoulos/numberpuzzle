# Number Puzzle

Offline number-match puzzle for Android (Ten Crush style): pair equal numbers
or numbers summing to 10, collect stars, grass, break ice, clear slime.
MVP: 30 levels on a map, 1–3 stars per level.

Package id: `gr.kaekhub.numberpuzzle`

## Stack
* Flutter (stable 3.35) / Dart, Android only
* `lib/engine/` – pure Dart rules, board, levels, goals (no Flutter imports)
* `lib/ads/` – AdMob wrapper, pure-Dart `AdPolicy`, AdMob ids
* `lib/storage/` – progress in shared_preferences (JSON)
* `lib/ui/` – home, level map, game (placeholder), light/dark theme from design tokens
* `lib/l10n/` – ARB files `el`, `en` (gen-l10n)
* Levels: `assets/levels/levels.json`, schema in [docs/level-schema.md](docs/level-schema.md)

## Dependencies & license policy
Only free, permissive (MIT/BSD/Apache) dependencies; no GPL.

| Package | License |
|---|---|
| google_mobile_ads (incl. UMP consent) | Apache-2.0 (plugin). The Google Mobile Ads SDK itself is closed-source but free to use. |
| shared_preferences | BSD-3-Clause |
| intl, flutter_localizations | BSD-3-Clause |
| file_picker | MIT |
| flutter_lints, test (dev) | BSD-3-Clause |

Font Manrope (SIL OFL 1.1) is planned (TODO, not bundled yet).

## Ads policy
* Debug/profile/tests and plain release use **only Google test ids**
  (`lib/ads/ad_ids.dart`, App ID via `manifestPlaceholders` in
  `android/app/build.gradle.kts`). No banners.
* UMP consent at startup.
* Interstitial: never in levels 1–3, max one per 3 levels and ≥180 s apart,
  never in Daily, only after the win screen is dismissed – never mid-level,
  never on Add numbers / undo.
* Rewarded: only on user tap; reward granted only in `onUserEarnedReward`.
* `--dart-define=ADS=false` disables the SDK entirely.
* Real AdMob ids ONLY in a release built with `--dart-define=ADS_REAL=true`;
  every other build (debug, profile, plain release) uses Google test ids.
  Playtest: `flutter build apk --release --split-per-abi`.
  Play: `flutter build appbundle --release --dart-define=ADS_REAL=true`.

## Build
```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

## Release signing plan
* Upload keystore lives **outside the repo** (e.g. `~/keys/numberpuzzle-upload.jks`).
* `android/key.properties` (gitignored) holds `storeFile`, `storePassword`,
  `keyAlias`, `keyPassword`; `build.gradle.kts` uses it when present,
  otherwise release falls back to debug signing.
* Play App Signing enabled; build with `flutter build appbundle --release`.

## Milestones
M0 scaffold (this) · M1 generator/solver/hint/boosters (Nionios) · M2 storage
export/import, daily · M3 board UI, map, ads UI.
