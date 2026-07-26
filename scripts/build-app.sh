#!/bin/zsh
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$PROJECT_DIR/dist/ScreenFocus.app"
CONTENTS_PATH="$APP_PATH/Contents"
SIGNING_IDENTITY="${SCREENFOCUS_SIGNING_IDENTITY:-ScreenFocus Local Development}"
BINARY_PATH="$PROJECT_DIR/.build/apple/Products/Release/ScreenFocus"

if ! security find-identity -v -p codesigning |
    grep -F "\"$SIGNING_IDENTITY\"" >/dev/null; then
    print -u2 "Missing the local ScreenFocus signing identity."
    print -u2 "Run: $PROJECT_DIR/scripts/setup-local-signing.sh"
    exit 1
fi

swift build \
    --package-path "$PROJECT_DIR" \
    -c release \
    --arch arm64 \
    --arch x86_64

if [[ "$APP_PATH" != "$PROJECT_DIR/dist/ScreenFocus.app" ]]; then
    print -u2 "Refusing to replace an unexpected app path."
    exit 1
fi

rm -rf "$APP_PATH"
mkdir -p "$CONTENTS_PATH/MacOS" "$CONTENTS_PATH/Resources"
cp "$BINARY_PATH" "$CONTENTS_PATH/MacOS/ScreenFocus"
cp "$PROJECT_DIR/Packaging/Info.plist" "$CONTENTS_PATH/Info.plist"
cp "$PROJECT_DIR/Packaging/ScreenFocus.icns" "$CONTENTS_PATH/Resources/ScreenFocus.icns"
cp "$PROJECT_DIR/LICENSE" "$CONTENTS_PATH/Resources/LICENSE"
cp "$PROJECT_DIR/EULA.md" "$CONTENTS_PATH/Resources/EULA.md"
chmod +x "$CONTENTS_PATH/MacOS/ScreenFocus"

codesign --force --deep --options runtime --sign "$SIGNING_IDENTITY" "$APP_PATH"
print "$APP_PATH"
