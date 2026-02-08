#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 || $# -gt 4 ]]; then
  echo "Usage: $0 <version x.y.z> <developer-id-application-identity> <notary-profile> [app-name]"
  exit 1
fi

VERSION="$1"
SIGNING_IDENTITY="$2"
NOTARY_PROFILE="$3"
APP_NAME="${4:-Unblockd}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: version must match x.y.z"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
ZIP_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.zip"
NOTARY_ZIP_PATH="$DIST_DIR/${APP_NAME}-${VERSION}-notary.zip"

if [[ ! -d "$APP_DIR" ]]; then
  echo "Error: app bundle not found: $APP_DIR"
  echo "Run scripts/release/build_release_app.sh $VERSION first."
  exit 1
fi

echo "Signing $APP_DIR"
codesign \
  --force \
  --deep \
  --timestamp \
  --options runtime \
  --sign "$SIGNING_IDENTITY" \
  "$APP_DIR"

codesign --verify --deep --strict --verbose=2 "$APP_DIR"

rm -f "$NOTARY_ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$NOTARY_ZIP_PATH"

echo "Submitting for notarization"
xcrun notarytool submit "$NOTARY_ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "Stapling notarization ticket"
xcrun stapler staple "$APP_DIR"
spctl -a -t exec -vv "$APP_DIR"

rm -f "$ZIP_PATH" "$ZIP_PATH.sha256"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"
shasum -a 256 "$ZIP_PATH" | awk '{print $1}' > "$ZIP_PATH.sha256"

echo "Notarized artifact ready: $ZIP_PATH"
echo "SHA256: $(cat "$ZIP_PATH.sha256")"
