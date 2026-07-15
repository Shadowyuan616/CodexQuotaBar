#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/.build"
MACOS_DEPLOYMENT_TARGET="${MACOS_DEPLOYMENT_TARGET:-14.0}"
TARGET_ARCH="${TARGET_ARCH:-$(uname -m)}"
mkdir -p "$BUILD_DIR/module-cache"

swiftc \
  -module-cache-path "$BUILD_DIR/module-cache" \
  -target "$TARGET_ARCH"-apple-macosx"$MACOS_DEPLOYMENT_TARGET" \
  "$ROOT/Sources/CodexQuotaCore.swift" \
  "$ROOT/Sources/CodexAppServerClient.swift" \
  "$ROOT/Tests/CodexQuotaLiveProbe.swift" \
  -o "$BUILD_DIR/CodexQuotaLiveProbe"

"$BUILD_DIR/CodexQuotaLiveProbe"
