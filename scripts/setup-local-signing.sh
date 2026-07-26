#!/bin/zsh
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail

IDENTITY_NAME="ScreenFocus Local Development"
KEYCHAIN_PATH="$(
    security default-keychain -d user |
        sed -E 's/^[[:space:]]*"//; s/"[[:space:]]*$//'
)"

if security find-identity -v -p codesigning |
    grep -F "\"$IDENTITY_NAME\"" >/dev/null; then
    print "The ScreenFocus signing identity is already installed."
    exit 0
fi

# Remove only an earlier invalid ScreenFocus identity created by this script.
security delete-identity -c "$IDENTITY_NAME" "$KEYCHAIN_PATH" >/dev/null 2>&1 || true

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/screenfocus-signing.XXXXXX")"
if [[ "$TEMP_DIR" != *"/screenfocus-signing."* ]]; then
    print -u2 "Refusing to use an unexpected temporary directory."
    exit 1
fi

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

PRIVATE_KEY_PATH="$TEMP_DIR/ScreenFocus.key"
CERTIFICATE_PATH="$TEMP_DIR/ScreenFocus.cer"
ARCHIVE_PATH="$TEMP_DIR/ScreenFocus.p12"
ARCHIVE_PASSWORD="$(openssl rand -hex 24)"

openssl req \
    -new \
    -newkey rsa:2048 \
    -x509 \
    -sha256 \
    -nodes \
    -days 3650 \
    -subj "/CN=$IDENTITY_NAME/O=ScreenFocus Local/OU=Local Development" \
    -addext "basicConstraints=critical,CA:FALSE" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=codeSigning" \
    -addext "subjectKeyIdentifier=hash" \
    -keyout "$PRIVATE_KEY_PATH" \
    -out "$CERTIFICATE_PATH"

openssl pkcs12 \
    -export \
    -legacy \
    -name "$IDENTITY_NAME" \
    -inkey "$PRIVATE_KEY_PATH" \
    -in "$CERTIFICATE_PATH" \
    -out "$ARCHIVE_PATH" \
    -passout "pass:$ARCHIVE_PASSWORD"

security import "$ARCHIVE_PATH" \
    -k "$KEYCHAIN_PATH" \
    -P "$ARCHIVE_PASSWORD" \
    -T /usr/bin/codesign \
    -T /usr/bin/security

security add-trusted-cert \
    -r trustRoot \
    -p codeSign \
    -k "$KEYCHAIN_PATH" \
    "$CERTIFICATE_PATH"

if ! security find-identity -v -p codesigning |
    grep -F "\"$IDENTITY_NAME\"" >/dev/null; then
    print -u2 "The certificate was imported, but macOS did not accept it for code signing."
    exit 1
fi

print "Installed: $IDENTITY_NAME"
