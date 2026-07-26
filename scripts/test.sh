#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/.build"
MACOS_DEPLOYMENT_TARGET="${MACOS_DEPLOYMENT_TARGET:-14.0}"
TARGET_ARCH="${TARGET_ARCH:-$(uname -m)}"
mkdir -p "$BUILD_DIR"
mkdir -p "$BUILD_DIR/module-cache"

swiftc \
  -module-cache-path "$BUILD_DIR/module-cache" \
  -target "$TARGET_ARCH"-apple-macosx"$MACOS_DEPLOYMENT_TARGET" \
  "$ROOT/Sources/CodexQuotaCore.swift" \
  "$ROOT/Sources/CodexAppServerClient.swift" \
  "$ROOT/Tests/CodexQuotaCoreTests.swift" \
  -o "$BUILD_DIR/CodexQuotaCoreTests"

"$BUILD_DIR/CodexQuotaCoreTests"

swiftc \
  -D PREVIEW_RENDERER \
  -module-cache-path "$BUILD_DIR/module-cache" \
  -target "$TARGET_ARCH"-apple-macosx"$MACOS_DEPLOYMENT_TARGET" \
  -framework AppKit \
  "$ROOT/Sources/CodexQuotaCore.swift" \
  "$ROOT/Sources/CodexAppServerClient.swift" \
  "$ROOT/Sources/CodexQuotaBarApp.swift" \
  "$ROOT/Tests/CodexQuotaUITests.swift" \
  -o "$BUILD_DIR/CodexQuotaUITests"

"$BUILD_DIR/CodexQuotaUITests"

bash "$ROOT/Tests/AppIconAssetTests.sh"
