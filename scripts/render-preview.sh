#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/.build"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT/dist}"
OUTPUT="${PREVIEW_OUTPUT:-$OUTPUT_DIR/codex-quota-popover-preview.png}"
MACOS_DEPLOYMENT_TARGET="${MACOS_DEPLOYMENT_TARGET:-14.0}"
TARGET_ARCH="${TARGET_ARCH:-$(uname -m)}"
mkdir -p "$BUILD_DIR/module-cache" "$OUTPUT_DIR" "$(dirname "$OUTPUT")"

swiftc \
  -D PREVIEW_RENDERER \
  -module-cache-path "$BUILD_DIR/module-cache" \
  -target "$TARGET_ARCH"-apple-macosx"$MACOS_DEPLOYMENT_TARGET" \
  -framework AppKit \
  "$ROOT/Sources/CodexQuotaCore.swift" \
  "$ROOT/Sources/CodexAppServerClient.swift" \
  "$ROOT/Sources/CodexQuotaBarApp.swift" \
  "$ROOT/Tests/CodexQuotaPreviewRenderer.swift" \
  -o "$BUILD_DIR/CodexQuotaPreviewRenderer"

"$BUILD_DIR/CodexQuotaPreviewRenderer" "$OUTPUT"
