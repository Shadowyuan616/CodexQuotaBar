#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/.build"
ICONSET="$ROOT/Resources/AppIcon.iconset"
ICNS="$ROOT/Resources/AppIcon.icns"
MASTER="$ROOT/docs/images/app-icon-1024.png"

mkdir -p "$BUILD_DIR/module-cache" "$ICONSET" "$(dirname "$MASTER")"

swift \
  -module-cache-path "$BUILD_DIR/module-cache" \
  "$ROOT/scripts/generate-app-icon.swift" \
  --output-dir "$ICONSET" \
  --master "$MASTER" \
  --icns "$ICNS"

echo "$ICNS"
