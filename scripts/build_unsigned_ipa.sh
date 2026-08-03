#!/usr/bin/env bash
# Build an unsigned StatMaxxer IPA on macOS (Xcode + Flutter required).
#
# Usage (from repo root):
#   ./scripts/build_unsigned_ipa.sh
#   ./scripts/build_unsigned_ipa.sh 42   # optional build number
#
# Output: build/ios/ipa/StatMaxxer-unsigned-<n>.ipa
#
# Note: Unsigned IPAs cannot be installed on a normal iPhone until re-signed
# (Xcode, Codemagic ios-release, Sideloadly, etc.).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: iOS builds require macOS + Xcode. This host is $(uname -s)."
  echo "Use Codemagic workflow 'ios-unsigned' instead."
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "ERROR: flutter not found on PATH"
  exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "ERROR: Xcode / xcodebuild not available"
  exit 1
fi

BUILD_NUMBER="${1:-$(date +%Y%m%d%H%M)}"
BUILD_NAME="1.0.${BUILD_NUMBER}"

echo "==> flutter pub get"
flutter pub get

echo "==> pod install"
(
  cd ios
  pod install
)

echo "==> flutter build ios --release --no-codesign ($BUILD_NAME+$BUILD_NUMBER)"
flutter build ios --release --no-codesign \
  --build-name="$BUILD_NAME" \
  --build-number="$BUILD_NUMBER"

APP_PATH="build/ios/iphoneos/Runner.app"
if [[ ! -d "$APP_PATH" ]]; then
  APP_PATH="$(find build/ios -type d -name 'Runner.app' | head -1 || true)"
fi
if [[ -z "${APP_PATH:-}" || ! -d "$APP_PATH" ]]; then
  echo "ERROR: Runner.app not found under build/ios"
  exit 1
fi

IPA_DIR="$ROOT/build/ios/ipa"
rm -rf "$IPA_DIR"
mkdir -p "$IPA_DIR/Payload"
cp -R "$APP_PATH" "$IPA_DIR/Payload/Runner.app"

IPA_NAME="StatMaxxer-unsigned-${BUILD_NUMBER}.ipa"
(
  cd "$IPA_DIR"
  zip -qry "$IPA_NAME" Payload
)

echo
echo "Created: $IPA_DIR/$IPA_NAME"
ls -lh "$IPA_DIR/$IPA_NAME"
