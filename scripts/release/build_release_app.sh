#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INFO_PLIST="$ROOT_DIR/Sources/Unblockd/Info.plist"
APP_NAME="Unblockd"

VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: invalid version '$VERSION'"
  exit 1
fi

cd "$ROOT_DIR"

swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
BIN_PATH="$BIN_DIR/$APP_NAME"

if [[ ! -f "$BIN_PATH" ]]; then
  echo "Error: binary not found at $BIN_PATH"
  exit 1
fi

RESOURCE_BUNDLE_PATH="${RESOURCE_BUNDLE_PATH:-}"
if [[ -n "$RESOURCE_BUNDLE_PATH" ]]; then
  RESOURCE_BUNDLE="$RESOURCE_BUNDLE_PATH"
  if [[ ! -d "$RESOURCE_BUNDLE" ]]; then
    echo "Error: RESOURCE_BUNDLE_PATH does not exist: $RESOURCE_BUNDLE"
    exit 1
  fi
else
  shopt -s nullglob
  RESOURCE_BUNDLES=("$BIN_DIR"/"${APP_NAME}"_*.bundle)
  shopt -u nullglob

  if [[ ${#RESOURCE_BUNDLES[@]} -eq 0 ]]; then
    echo "Error: resource bundle not found in $BIN_DIR (expected pattern: ${APP_NAME}_*.bundle)"
    exit 1
  fi

  if [[ ${#RESOURCE_BUNDLES[@]} -gt 1 ]]; then
    echo "Error: multiple resource bundles found; set RESOURCE_BUNDLE_PATH explicitly"
    printf ' - %s\n' "${RESOURCE_BUNDLES[@]}"
    exit 1
  fi

  RESOURCE_BUNDLE="${RESOURCE_BUNDLES[0]}"
fi

DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
ZIP_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.zip"
ICON_NAME="AppIcon.icns"
ICON_SOURCE="$ROOT_DIR/Sources/Unblockd/Resources/$ICON_NAME"

rm -rf "$APP_DIR" "$ZIP_PATH" "$ZIP_PATH.sha256"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$INFO_PLIST" "$APP_DIR/Contents/Info.plist"
cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/"
if [[ -f "$ICON_SOURCE" ]]; then
  cp "$ICON_SOURCE" "$APP_DIR/Contents/Resources/$ICON_NAME"
fi
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

set_plist_key() {
  local key="$1"
  local type="$2"
  local value="$3"

  if /usr/libexec/PlistBuddy -c "Print :$key" "$APP_DIR/Contents/Info.plist" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Set :$key $value" "$APP_DIR/Contents/Info.plist"
  else
    /usr/libexec/PlistBuddy -c "Add :$key $type $value" "$APP_DIR/Contents/Info.plist"
  fi
}

set_plist_key "CFBundleExecutable" string "$APP_NAME"
set_plist_key "CFBundleName" string "$APP_NAME"
set_plist_key "CFBundleDisplayName" string "$APP_NAME"
set_plist_key "CFBundlePackageType" string "APPL"
set_plist_key "NSPrincipalClass" string "NSApplication"
set_plist_key "LSMinimumSystemVersion" string "13.0"
if [[ -f "$ICON_SOURCE" ]]; then
  set_plist_key "CFBundleIconFile" string "AppIcon"
fi

ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"
shasum -a 256 "$ZIP_PATH" | awk '{print $1}' > "$ZIP_PATH.sha256"

echo "Built artifact: $ZIP_PATH"
echo "SHA256: $(cat "$ZIP_PATH.sha256")"
