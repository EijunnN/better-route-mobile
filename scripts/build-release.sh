#!/usr/bin/env bash
#
# Release build for the BetterRoute driver app.
#
# The app fails closed at startup (ApiConfig.assertValid) if the production
# URLs are missing or are not TLS, so a release build MUST inject them. They
# are read from dart_define.json — copy the template and fill in your values:
#
#   cp dart_define.example.json dart_define.json
#   # then set API_BASE_URL (https://...) and WS_URL (wss://...)
#
# Usage: scripts/build-release.sh [apk|appbundle|ios]   (default: appbundle)
set -euo pipefail
cd "$(dirname "$0")/.."

TARGET="${1:-appbundle}"
CONFIG="dart_define.json"

if [ ! -f "$CONFIG" ]; then
  echo "✗ $CONFIG not found." >&2
  echo "  Run:  cp dart_define.example.json $CONFIG   then set your https/wss URLs." >&2
  exit 1
fi

echo "▶ flutter build $TARGET --release --dart-define-from-file=$CONFIG"
flutter build "$TARGET" --release --dart-define-from-file="$CONFIG"
