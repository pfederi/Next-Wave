#!/bin/bash
# Frames raw iPhone screenshots into the real iPhone 17 Pro device bezel
# (same look as frameme), output sized 1350x2760 to match next-wave1..N.png.
set -e
cd "$(dirname "$0")"
SRC_DIR="${1:-raw}"
OUT_DIR="${2:-framed}"
BEZEL="${BEZEL:-/Users/federi/Library/CloudStorage/Dropbox/Apps/Bezels/iPhone 17 Pro - Deep Blue - Portrait.png}"
mkdir -p "$OUT_DIR"
[ -f "$BEZEL" ] || { echo "bezel not found: $BEZEL"; exit 1; }

# Detect the screen cutout: the transparent region not connected to the border.
GEO=$(magick "$BEZEL" -alpha extract -negate -bordercolor white -border 1 \
  -fill black -floodfill +0+0 white -shave 1x1 -trim -format "%w %h %O" info:)
HW=$(echo "$GEO" | awk '{print $1}')
HH=$(echo "$GEO" | awk '{print $2}')
OFF=$(echo "$GEO" | awk '{print $3}')
echo "bezel $(magick identify -format '%wx%h' "$BEZEL"), screen ${HW}x${HH}${OFF}"

i=0
for f in "$SRC_DIR"/*.png; do
  i=$((i+1))
  magick "$f" -resize ${HW}x${HH}\! /tmp/_scr.png
  magick "$BEZEL" /tmp/_scr.png -geometry "$OFF" -compose DstOver -composite \
    "$OUT_DIR/next-wave${i}.png"
  echo "framed -> $OUT_DIR/next-wave${i}.png"
done
