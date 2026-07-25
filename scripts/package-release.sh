#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$PROJECT_DIR/dist/ScreenFocus.app"
VERSION="$(plutil -extract CFBundleShortVersionString raw "$PROJECT_DIR/Packaging/Info.plist")"
ARCHIVE_PATH="$PROJECT_DIR/dist/ScreenFocus-$VERSION.zip"
CHECKSUM_PATH="$ARCHIVE_PATH.sha256"

"$PROJECT_DIR/scripts/build-app.sh" >/dev/null

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ARCHIVE_PATH"
shasum -a 256 "$ARCHIVE_PATH" > "$CHECKSUM_PATH"

unzip -t "$ARCHIVE_PATH" >/dev/null
codesign --verify --deep --strict "$APP_PATH"

print "$ARCHIVE_PATH"
print "$CHECKSUM_PATH"
