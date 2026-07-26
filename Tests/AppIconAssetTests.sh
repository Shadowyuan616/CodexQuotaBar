#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$ROOT/Resources/AppIcon.iconset"
ICNS="$ROOT/Resources/AppIcon.icns"
MASTER="$ROOT/docs/images/app-icon-1024.png"

required_files=(
  "icon_16x16.png"
  "icon_16x16@2x.png"
  "icon_32x32.png"
  "icon_32x32@2x.png"
  "icon_128x128.png"
  "icon_128x128@2x.png"
  "icon_256x256.png"
  "icon_256x256@2x.png"
  "icon_512x512.png"
  "icon_512x512@2x.png"
)

test -f "$ROOT/scripts/generate-app-icon.swift"
test -f "$ROOT/scripts/generate-app-icon.sh"
test -f "$ICNS"
test -f "$MASTER"

for filename in "${required_files[@]}"; do
  test -f "$ICONSET/$filename"
done

master_width="$(sips -g pixelWidth "$MASTER" 2>/dev/null | awk '/pixelWidth/ { print $2 }')"
master_height="$(sips -g pixelHeight "$MASTER" 2>/dev/null | awk '/pixelHeight/ { print $2 }')"
test "$master_width" = "1024"
test "$master_height" = "1024"

validation_dir="$(mktemp -d "${TMPDIR:-/tmp}/CodexQuotaBar-AppIcon.XXXXXX")"
trap 'rm -rf "$validation_dir"' EXIT
iconutil -c iconset "$ICNS" -o "$validation_dir/AppIcon.iconset"

bundle_output="$ROOT/.build/app-icon-bundle-test"
OUTPUT_DIR="$bundle_output" bash "$ROOT/scripts/build.sh" >/dev/null
bundle="$bundle_output/CodexQuotaBar.app"
test -f "$bundle/Contents/Resources/AppIcon.icns"
bundle_icon_name="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$bundle/Contents/Info.plist")"
test "$bundle_icon_name" = "AppIcon"
codesign --verify --deep --strict "$bundle"

echo "AppIconAssetTests passed"
