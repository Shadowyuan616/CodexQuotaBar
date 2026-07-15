#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT/dist}"
APP="$OUTPUT_DIR/CodexQuotaBar.app"
IDENTITY="${DEVELOPER_ID_APPLICATION:-}"

if [[ -z "$IDENTITY" ]]; then
  echo "请设置 DEVELOPER_ID_APPLICATION，例如 Developer ID Application: Name (TEAMID)" >&2
  exit 1
fi

OUTPUT_DIR="$OUTPUT_DIR" bash "$ROOT/scripts/build.sh" >/dev/null

codesign \
  --force \
  --deep \
  --options runtime \
  --timestamp \
  --sign "$IDENTITY" \
  "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  ARCHIVE="$OUTPUT_DIR/CodexQuotaBar-notarization.zip"
  rm -f "$ARCHIVE"
  ditto -c -k --keepParent "$APP" "$ARCHIVE"
  xcrun notarytool submit "$ARCHIVE" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
fi

echo "$APP"
