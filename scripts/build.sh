#!/bin/bash
# Builds a universal (arm64 + x86_64) Lights Bridge.app and a drag-to-Applications dmg in dist/.
# Usage: scripts/build.sh [--arm64-only]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
VERSION="$(tr -d '[:space:]' < VERSION)"
ARM_ONLY=0
[[ "${1:-}" == "--arm64-only" ]] && ARM_ONLY=1

APP="dist/Lights Bridge.app"
rm -rf "dist"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

build_arch() {  # $1 = arm64 | x86_64 ; prints path to the binary
  local triple="$1-apple-macosx11.0"
  swift build -c release --triple "$triple" >&2
  echo "$(swift build -c release --triple "$triple" --show-bin-path)/LightsBridge"
}

ARM_BIN="$(build_arch arm64)"
if [[ $ARM_ONLY -eq 1 ]]; then
  cp "$ARM_BIN" "$APP/Contents/MacOS/LightsBridge"
else
  X86_BIN="$(build_arch x86_64)"
  lipo -create "$ARM_BIN" "$X86_BIN" -output "$APP/Contents/MacOS/LightsBridge"
fi

sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature (no developer account needed; users approve once in System Settings).
codesign --force --deep --sign - "$APP"

# The dmg has a fixed name (no version in it), so .../releases/latest/download/LightsBridge.dmg
# always works. It holds the app plus an Applications shortcut to drag it onto.
DMG="dist/LightsBridge.dmg"
STAGE="dist/dmg-staging"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Lights Bridge.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Lights Bridge" -srcfolder "$STAGE" -format UDZO -ov "$DMG"
rm -rf "$STAGE"

echo "Architectures: $(lipo -archs "$APP/Contents/MacOS/LightsBridge")"
echo "Dmg: $ROOT/$DMG"
