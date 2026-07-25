#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$PROJECT_DIR/dist/ScreenFocus.app"
VERSION="$(plutil -extract CFBundleShortVersionString raw "$PROJECT_DIR/Packaging/Info.plist")"
ARCHIVE_NAME="ScreenFocus-$VERSION.zip"
ARCHIVE_PATH="$PROJECT_DIR/dist/$ARCHIVE_NAME"
CHECKSUM_PATH="$ARCHIVE_PATH.sha256"

"$PROJECT_DIR/scripts/build-app.sh" >/dev/null

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ARCHIVE_PATH"
(
    cd "$PROJECT_DIR/dist"
    shasum -a 256 "$ARCHIVE_NAME" > "$ARCHIVE_NAME.sha256"
)

unzip -t "$ARCHIVE_PATH" >/dev/null
codesign --verify --deep --strict "$APP_PATH"

print "$ARCHIVE_PATH"
print "$CHECKSUM_PATH"
