#!/bin/bash

set -euo pipefail

usage() {
  echo "Usage:"
  echo "  ./build-macos.sh local [vX.Y.Z]"
  echo "  ./build-macos.sh release [vX.Y.Z]"
  echo
  echo "Modes:"
  echo "  local   Build app and create DMG (unsigned)."
  echo "  release Build signed app and signed/notarized PKG only."
  echo
  echo "Required env vars for release mode:"
  echo "  DEV_ID_APP_CERT"
  echo "  DEV_ID_INSTALLER_CERT"
  echo "  NOTARY_PROFILE"
}

get_version_from_pubspec() {
  local raw
  raw="$(awk -F': ' '/^version:/ {print $2; exit}' pubspec.yaml)"
  raw="${raw%%+*}"
  echo "$raw"
}

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: $cmd"
    exit 1
  fi
}

MODE="${1:-local}"
INPUT_VERSION="${2:-$(get_version_from_pubspec)}"
VERSION="${INPUT_VERSION#v}"

if [[ "$MODE" != "local" && "$MODE" != "release" ]]; then
  echo "ERROR: Unknown mode '$MODE'."
  usage
  exit 1
fi

require_command flutter
require_command codesign
require_command productbuild

if [[ "$MODE" == "local" ]]; then
  require_command create-dmg
fi

if [[ "$MODE" == "release" ]]; then
  require_command xcrun
  : "${DEV_ID_APP_CERT:?Set DEV_ID_APP_CERT in your environment.}"
  : "${DEV_ID_INSTALLER_CERT:?Set DEV_ID_INSTALLER_CERT in your environment.}"
  : "${NOTARY_PROFILE:?Set NOTARY_PROFILE in your environment.}"
fi

APP_NAME="FluentGPT"
SOURCE_DIR="build/macos/Build/Products/Release"
APP_PATH="${SOURCE_DIR}/${APP_NAME}.app"
OUTPUT_DIR="installers"
PKG_PATH="${OUTPUT_DIR}/${APP_NAME}-${VERSION}.pkg"
DMG_PATH="${OUTPUT_DIR}/${APP_NAME}-${VERSION}.dmg"
TMP_DIR="$(mktemp -d)"
PLUGINS_SRC="plugins/cpp_build_macos_arm64"
PLUGINS_DST="${APP_PATH}/Contents/MacOS/plugins"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$OUTPUT_DIR"

echo "Building macOS (${MODE}) version ${VERSION}..."
flutter build macos --release --no-tree-shake-icons

if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: App not found at ${APP_PATH}"
  exit 1
fi

# Bundle local server binaries into the built app so all release artifacts include them.
if [[ -d "$PLUGINS_SRC" ]]; then
  echo "Copying local server binaries from ${PLUGINS_SRC} to app bundle..."
  mkdir -p "$PLUGINS_DST"
  rm -rf "${PLUGINS_DST}/cpp_build_macos_arm64"
  cp -R "$PLUGINS_SRC" "$PLUGINS_DST/"
  find "$PLUGINS_DST" -type f -exec chmod +x {} \; || true
  xattr -dr com.apple.quarantine "$APP_PATH" || true
else
  echo "WARNING: ${PLUGINS_SRC} not found. Build artifacts will not include local server binaries."
fi

if [[ "$MODE" == "release" ]]; then
  echo "Signing app with Developer ID Application cert..."
  codesign --force --deep --options runtime --timestamp \
    --sign "$DEV_ID_APP_CERT" \
    "$APP_PATH"

  echo "Verifying app signature..."
  codesign --verify --deep --strict --verbose=2 "$APP_PATH"
  spctl -a -vvv "$APP_PATH" || true

  echo "Building signed PKG..."
  rm -f "$PKG_PATH"
  productbuild \
    --component "$APP_PATH" /Applications \
    --sign "$DEV_ID_INSTALLER_CERT" \
    "$PKG_PATH"

  echo "Submitting PKG for notarization..."
  xcrun notarytool submit "$PKG_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

  echo "Stapling notarization ticket..."
  xcrun stapler staple "$PKG_PATH"
  xcrun stapler validate "$PKG_PATH"

  echo "Validating installer with Gatekeeper..."
  spctl -a -vvv --type install "$PKG_PATH"

  echo "Release PKG created at ${PKG_PATH}"
  exit 0
fi

echo "Creating unsigned DMG for local testing..."
cp -R "$APP_PATH" "$TMP_DIR"
create-dmg \
  --volname "${APP_NAME}" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "${APP_NAME}.app" 200 190 \
  --hide-extension "${APP_NAME}.app" \
  --app-drop-link 600 185 \
  "$DMG_PATH" \
  "$TMP_DIR"

echo "Local DMG created at ${DMG_PATH}"
