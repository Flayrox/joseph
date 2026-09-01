#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-1.0.0}"
BUILD_DIR="$ROOT_DIR/build"
APP_PATH="$BUILD_DIR/Release/joseph.app"
DMG_PATH="$BUILD_DIR/joseph-${VERSION}.dmg"
STAGING_DIR="$BUILD_DIR/dmg-staging"

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"
bash "$ROOT_DIR/scripts/create-app-icon.sh"
xcodegen generate
xcodebuild archive \
  -project joseph.xcodeproj \
  -scheme joseph \
  -configuration Release \
  -archivePath "$BUILD_DIR/joseph.xcarchive" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  SKIP_INSTALL=NO

rm -rf "$APP_PATH"
mkdir -p "$(dirname "$APP_PATH")"
cp -R "$BUILD_DIR/joseph.xcarchive/Products/Applications/joseph.app" "$APP_PATH"
if [ ! -f "$APP_PATH/Contents/Resources/joseph.icns" ]; then
  echo "ERROR: generated app has no joseph.icns at bundle resource root" >&2
  exit 1
fi
file "$APP_PATH/Contents/Resources/joseph.icns"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create -volname joseph -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"
printf '%s\n' "$DMG_PATH"
