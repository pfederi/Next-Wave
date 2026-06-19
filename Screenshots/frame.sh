#!/bin/bash
# Frames raw iPhone screenshots into the real iPhone 17 Pro device bezel.
# The screenshot is placed at its NATIVE size, centered, behind the bezel
# (no scaling → no distortion), exactly like frameme. Output matches the
# bezel size (1350x2760).
set -e
cd "$(dirname "$0")"
SRC_DIR="${1:-raw}"
OUT_DIR="${2:-framed}"
BEZEL="${BEZEL:-/Users/federi/Library/CloudStorage/Dropbox/Apps/Bezels/iPhone 17 Pro - Deep Blue - Portrait.png}"
mkdir -p "$OUT_DIR"
[ -f "$BEZEL" ] || { echo "bezel not found: $BEZEL"; exit 1; }
echo "bezel $(magick identify -format '%wx%h' "$BEZEL")"

i=0
for f in "$SRC_DIR"/*.png; do
  i=$((i+1))
  magick "$BEZEL" "$f" -gravity center -compose DstOver -composite "$OUT_DIR/next-wave${i}.png"
  echo "framed -> $OUT_DIR/next-wave${i}.png"
done
