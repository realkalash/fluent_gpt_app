#!/bin/bash

# Get version from parameter or use default
VERSION=${1:-"1.0.70"}
# Remove 'v' prefix if present
VERSION=${VERSION#v}

echo "Building macOS version $VERSION..."

flutter build macos --release --no-tree-shake-icons

# Set variables
APP_NAME="FluentGPT"
DMG_NAME="FluentGPT-${VERSION}.dmg"
SOURCE_DIR="build/macos/Build/Products/Release"
APP_PATH="${SOURCE_DIR}/${APP_NAME}.app"
OUTPUT_DIR="installers"
TMP_DIR=$(mktemp -d)

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Copy only the .app file to a temporary directory
cp -R "$APP_PATH" "$TMP_DIR"
# Copy everything in 'external_files' to the .app file
# cp -r external_files/* "$TMP_DIR/${APP_NAME}.app/Contents/MacOS"

# Create DMG
create-dmg \
  --volname "${APP_NAME}" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "${APP_NAME}.app" 200 190 \
  --hide-extension "${APP_NAME}.app" \
  --app-drop-link 600 185 \
  "${OUTPUT_DIR}/${DMG_NAME}" \
  "$TMP_DIR"

# Clean up temporary directory
rm -rf "$TMP_DIR"

echo "DMG created at ${OUTPUT_DIR}/${DMG_NAME}"
