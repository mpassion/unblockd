#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 3 ]]; then
  echo "Usage: $0 <version x.y.z> [output-cask-path] [sha256-or-sha256-file]"
  exit 1
fi

VERSION="$1"
OUTPUT_PATH="${2:-}"
SHA_INPUT="${3:-}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: version must match x.y.z"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ZIP_PATH="$ROOT_DIR/dist/Unblockd-${VERSION}.zip"
SHA_FILE_DEFAULT="$ZIP_PATH.sha256"

resolve_sha256() {
  local input="$1"

  if [[ -n "$input" ]]; then
    if [[ -f "$input" ]]; then
      tr -d '[:space:]' < "$input"
      return
    fi

    echo "$input"
    return
  fi

  if [[ -f "$SHA_FILE_DEFAULT" ]]; then
    tr -d '[:space:]' < "$SHA_FILE_DEFAULT"
    return
  fi

  if [[ -f "$ZIP_PATH" ]]; then
    shasum -a 256 "$ZIP_PATH" | awk '{print $1}'
    return
  fi

  echo ""
}

SHA256="$(resolve_sha256 "$SHA_INPUT")"

if [[ -z "$SHA256" ]]; then
  echo "Error: no SHA256 source found."
  echo "Provide [sha256-or-sha256-file], or ensure one of these exists:"
  echo " - $SHA_FILE_DEFAULT"
  echo " - $ZIP_PATH"
  exit 1
fi

if [[ ! "$SHA256" =~ ^[a-fA-F0-9]{64}$ ]]; then
  echo "Error: invalid SHA256 value: '$SHA256'"
  exit 1
fi

if [[ -z "$OUTPUT_PATH" ]]; then
  OUTPUT_PATH="$ROOT_DIR/dist/homebrew/unblockd.rb"
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"

cat > "$OUTPUT_PATH" <<CASK
cask "unblockd" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/mpassion/unblockd/releases/download/v#{version}/Unblockd-#{version}.zip"
  name "Unblockd"
  desc "Menu bar pull request monitor for Bitbucket, GitHub, and GitLab"
  homepage "https://github.com/mpassion/unblockd"

  app "Unblockd.app"
end
CASK

echo "Generated cask: $OUTPUT_PATH"
echo "SHA256 source: ${SHA_INPUT:-auto}"
