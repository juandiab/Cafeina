#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Cafeina"
PROJECT_NAME="Cafeina.xcodeproj"
SCHEME="Cafeina"
CONFIGURATION="Release"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${TMPDIR:-/private/tmp}/CafeinaDmgBuild"
DERIVED_DATA_DIR="$BUILD_ROOT/DerivedData"
STAGING_DIR="$BUILD_ROOT/dmg-staging"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"

rm -rf "$BUILD_ROOT" "$DIST_DIR"
mkdir -p "$STAGING_DIR" "$DIST_DIR"

xcodebuild \
  -project "$ROOT_DIR/$PROJECT_NAME" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  clean build

codesign --force --deep --sign - "$APP_PATH"

ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "DMG created at: $DMG_PATH"
