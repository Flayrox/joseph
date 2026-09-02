#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FILL="$ROOT_DIR/Resources/logo_fill.jpg"
OUTLINE="$ROOT_DIR/Resources/logo_outline.png"
ICONSET_DIR="$ROOT_DIR/build/joseph.iconset"
APPSET="$ROOT_DIR/Resources/Assets.xcassets/AppIcon.appiconset"

# 1. Shrink the artwork. 1024px is enough for any macOS icon slot; the menu-bar
#    outline logo never needs more than 512px (it is shown at 18-72pt).
sips -Z 1024 -s format jpeg -s formatOptions 80 "$FILL" --out "$FILL" >/dev/null
sips -Z 512 -s format png "$OUTLINE" --out "$OUTLINE" >/dev/null

# 2. Regenerate the appicon PNG set from the compressed fill logo.
rm -rf "$APPSET"
mkdir -p "$APPSET"
cat > "$APPSET/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "icon-16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon-32.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon-32-1x.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon-64.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon-128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon-256.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon-256-1x.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon-512.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon-512-1x.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon-1024.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

mksize() {
  local px="$1" out="$2"
  sips -Z "$px" -s format png "$FILL" --out "$out" >/dev/null
}
mksize 16  "$APPSET/icon-16.png"
mksize 32  "$APPSET/icon-32.png"
mksize 32  "$APPSET/icon-32-1x.png"
mksize 64  "$APPSET/icon-64.png"
mksize 128 "$APPSET/icon-128.png"
mksize 256 "$APPSET/icon-256.png"
mksize 256 "$APPSET/icon-256-1x.png"
mksize 512 "$APPSET/icon-512.png"
mksize 512 "$APPSET/icon-512-1x.png"
mksize 1024 "$APPSET/icon-1024.png"

# Quantize the icon PNGs (photographic JPEG->PNG conversions inflate badly).
if command -v pngquant >/dev/null 2>&1; then
  pngquant --force --speed 1 --quality 60-90 "$APPSET"/icon-*.png --ext .png 2>/dev/null || true
fi

# 3. Build a compact legacy .icns from the compressed artwork (no 1024px slot:
#    modern macOS reads the asset catalog; the icns is only a fallback).
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
make_icon() {
  local px="$1" out="$2"
  sips -Z "$px" -s format png "$FILL" --out "$ICONSET_DIR/$out" >/dev/null
}
make_icon 16  icon_16x16.png
make_icon 32  icon_16x16@2x.png
make_icon 32  icon_32x32.png
make_icon 64  icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
if command -v pngquant >/dev/null 2>&1; then
  pngquant --force --speed 1 --quality 60-90 "$ICONSET_DIR"/icon_*.png --ext .png 2>/dev/null || true
fi
iconutil -c icns "$ICONSET_DIR" -o "$ROOT_DIR/Resources/joseph.icns"
rm -rf "$ICONSET_DIR"