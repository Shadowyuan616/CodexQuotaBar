#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/.build"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT/dist}"
MACOS_DEPLOYMENT_TARGET="${MACOS_DEPLOYMENT_TARGET:-14.0}"
TARGET_ARCH="${TARGET_ARCH:-$(uname -m)}"
APP="$OUTPUT_DIR/CodexQuotaBar.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

mkdir -p "$BUILD_DIR/module-cache" "$OUTPUT_DIR"
rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"

swiftc \
  -module-cache-path "$BUILD_DIR/module-cache" \
  -target "$TARGET_ARCH"-apple-macosx"$MACOS_DEPLOYMENT_TARGET" \
  -framework AppKit \
  "$ROOT/Sources/CodexQuotaCore.swift" \
  "$ROOT/Sources/CodexAppServerClient.swift" \
  "$ROOT/Sources/CodexQuotaBarApp.swift" \
  -o "$MACOS/CodexQuotaBar"

cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"
chmod +x "$MACOS/CodexQuotaBar"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP" >/dev/null
fi

echo "$APP"
