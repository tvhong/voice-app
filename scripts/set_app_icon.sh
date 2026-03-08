#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_ICON="${1:-$ROOT_DIR/icon.png}"
APPICONSET_DIR="$ROOT_DIR/VoiceApp/VoiceApp/Assets.xcassets/AppIcon.appiconset"

if ! command -v sips >/dev/null 2>&1; then
  echo "Error: 'sips' is required but was not found."
  exit 1
fi

if [[ ! -f "$SOURCE_ICON" ]]; then
  echo "Error: source icon not found at: $SOURCE_ICON"
  echo "Usage: $0 [path/to/icon.png]"
  exit 1
fi

mkdir -p "$APPICONSET_DIR"

create_icon() {
  local pixels="$1"
  local filename="$2"
  sips -z "$pixels" "$pixels" "$SOURCE_ICON" --out "$APPICONSET_DIR/$filename" >/dev/null
}

create_icon 16 "icon_16x16.png"
create_icon 32 "icon_16x16@2x.png"
create_icon 32 "icon_32x32.png"
create_icon 64 "icon_32x32@2x.png"
create_icon 128 "icon_128x128.png"
create_icon 256 "icon_128x128@2x.png"
create_icon 256 "icon_256x256.png"
create_icon 512 "icon_256x256@2x.png"
create_icon 512 "icon_512x512.png"
create_icon 1024 "icon_512x512@2x.png"

cat > "$APPICONSET_DIR/Contents.json" <<'EOF'
{
  "images" : [
    {
      "filename" : "icon_16x16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo "App icon set updated at: $APPICONSET_DIR"
