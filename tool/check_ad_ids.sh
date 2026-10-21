#!/usr/bin/env bash
# Guards the ADS_REAL dart-define wiring (lib/ads + android/app/build.gradle).
# Builds nothing: greps an already built APK/AAB for the real AdMob publisher id.
#
#   tool/check_ad_ids.sh <app.apk|app.aab>          plain build: FAIL if the real id is present
#   tool/check_ad_ids.sh --real <app.apk|app.aab>   ADS_REAL=true release: FAIL if it is missing
#
# Exit 0 = OK, 1 = check failed, 2 = usage / unreadable file.
set -euo pipefail

REAL_PUB_ID=1774874652706103

expect_real=false
if [[ "${1:-}" == "--real" ]]; then expect_real=true; shift; fi
artifact="${1:-}"
if [[ -z "$artifact" || ! -f "$artifact" ]]; then
  echo "usage: $0 [--real] <path to .apk or .aab>" >&2
  exit 2
fi
command -v unzip >/dev/null || { echo "unzip is required" >&2; exit 2; }

# Every entry (dex, libapp.so, manifest, resources), uncompressed.
if unzip -p "$artifact" 2>/dev/null | grep -aqF "$REAL_PUB_ID"; then found=true; else found=false; fi

if $expect_real; then
  if $found; then echo "OK: real ad id present in $artifact"; exit 0; fi
  echo "FAIL: --real build but the real ad id ($REAL_PUB_ID) is missing from $artifact" >&2
  exit 1
fi
if $found; then
  echo "FAIL: real ad id ($REAL_PUB_ID) found in $artifact; only release + ADS_REAL=true may contain it" >&2
  exit 1
fi
echo "OK: no real ad id in $artifact"
