#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$ROOT_DIR/build/joseph.iconset"
mkdir -p "$ICONSET"

make_icon() {
  local size="$1"
  local output="$2"
  sips -s format png -z "$size" "$size" "$ROOT_DIR/Resources/logo_fill.jpg" --out "$ICONSET/$output" >/dev/null
}

make_icon 16 icon_16x16.png
make_icon 32 icon_16x16@2x.png
make_icon 32 icon_32x32.png
make_icon 64 icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
make_icon 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET" -o "$ROOT_DIR/Resources/joseph.icns"
rm -rf "$ICONSET"
