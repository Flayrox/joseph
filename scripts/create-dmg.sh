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

ICNS_PATH="$APP_PATH/Contents/Resources/joseph.icns"
CAR_PATH="$APP_PATH/Contents/Resources/Assets.car"
PLIST_PATH="$APP_PATH/Contents/Info.plist"

fail() { echo "ERROR: $1" >&2; exit 1; }

[ -f "$CAR_PATH" ] || fail "Assets.car missing (asset catalog was not compiled)"
ICON_KEYS="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$PLIST_PATH" 2>/dev/null || true)
$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$PLIST_PATH" 2>/dev/null || true)"
[ "$ICON_KEYS" = "AppIcon
AppIcon" ] || fail "Info.plist icon keys must both be AppIcon: got [$ICON_KEYS]"

ASSETUTIL="$(xcrun --find assetutil 2>/dev/null || true)"
if [ -n "$ASSETUTIL" ]; then
  "$ASSETUTIL" --info "$CAR_PATH" | grep -q '"AppIcon"' || fail "Assets.car does not contain the AppIcon set"
fi
if [ -f "$ICNS_PATH" ]; then
  file "$ICNS_PATH"
fi

codesign --force --deep --sign - "$APP_PATH" 2>/dev/null || true
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create -volname joseph -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"
printf '%s\n' "$DMG_PATH"