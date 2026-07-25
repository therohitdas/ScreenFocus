#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_PATH="$PROJECT_DIR/Assets/AppIcon.png"
OUTPUT_PATH="$PROJECT_DIR/Packaging/ScreenFocus.icns"
ICONSET_ROOT="$(mktemp -d)"
ICONSET_PATH="$ICONSET_ROOT/ScreenFocus.iconset"

cleanup() {
    rm -rf "$ICONSET_ROOT"
}
trap cleanup EXIT

if [[ ! -f "$SOURCE_PATH" ]]; then
    print -u2 "Missing icon master: $SOURCE_PATH"
    exit 1
fi

WIDTH="$(sips -g pixelWidth "$SOURCE_PATH" | awk '/pixelWidth/ { print $2 }')"
HEIGHT="$(sips -g pixelHeight "$SOURCE_PATH" | awk '/pixelHeight/ { print $2 }')"
HAS_ALPHA="$(sips -g hasAlpha "$SOURCE_PATH" | awk '/hasAlpha/ { print $2 }')"

if [[ "$WIDTH" != "1024" || "$HEIGHT" != "1024" ]]; then
    print -u2 "The icon master must be exactly 1024 × 1024 pixels."
    exit 1
fi

if [[ "$HAS_ALPHA" != "yes" ]]; then
    print -u2 "The icon master must contain an alpha channel."
    exit 1
fi

mkdir -p "$ICONSET_PATH"

render_icon() {
    local pixels="$1"
    local filename="$2"
    sips -z "$pixels" "$pixels" "$SOURCE_PATH" \
        --out "$ICONSET_PATH/$filename" >/dev/null
}

render_icon 16 icon_16x16.png
render_icon 32 icon_16x16@2x.png
render_icon 32 icon_32x32.png
render_icon 64 icon_32x32@2x.png
render_icon 128 icon_128x128.png
render_icon 256 icon_128x128@2x.png
render_icon 256 icon_256x256.png
render_icon 512 icon_256x256@2x.png
render_icon 512 icon_512x512.png
render_icon 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET_PATH" -o "$OUTPUT_PATH"
print "$OUTPUT_PATH"
