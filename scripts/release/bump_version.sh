#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <version x.y.z> [build-number]"
  exit 1
fi

VERSION="$1"
BUILD_NUMBER="${2:-}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: version must match x.y.z (e.g. 0.9.0 or 1.0.0)"
  exit 1
fi

if [[ -n "$BUILD_NUMBER" && ! "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: build-number must be a positive integer"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INFO_PLIST="$ROOT_DIR/Sources/Unblockd/Info.plist"

if [[ ! -f "$INFO_PLIST" ]]; then
  echo "Error: Info.plist not found at $INFO_PLIST"
  exit 1
fi

if [[ -z "$BUILD_NUMBER" ]]; then
  CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST" 2>/dev/null || echo "0")
  if [[ "$CURRENT_BUILD" =~ ^[0-9]+$ ]]; then
    BUILD_NUMBER="$((CURRENT_BUILD + 1))"
  else
    BUILD_NUMBER="1"
  fi
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$INFO_PLIST"

echo "Updated version: $VERSION ($BUILD_NUMBER)"
echo "File: $INFO_PLIST"
