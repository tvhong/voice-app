#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_ICON="${1:-$ROOT_DIR/icon.svg}"
APPICONSET_DIR="$ROOT_DIR/VoiceApp/VoiceApp/Assets.xcassets/AppIcon.appiconset"

if ! command -v sips >/dev/null 2>&1; then
  echo "Error: 'sips' is required but was not found."
  exit 1
fi

if [[ ! -f "$SOURCE_ICON" ]]; then
  echo "Error: source icon not found at: $SOURCE_ICON"
  echo "Usage: $0 [path/to/icon.svg]"
  exit 1
fi

mkdir -p "$APPICONSET_DIR"

sips -s format png -z 1024 1024 "$SOURCE_ICON" --out "$APPICONSET_DIR/AppIcon.png" >/dev/null

echo "App icon updated at: $APPICONSET_DIR/AppIcon.png"
