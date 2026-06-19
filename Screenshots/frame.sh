#!/bin/bash
# Frames raw iPhone screenshots (clean ⌘S captures) in a modern dark iPhone bezel
# on a light background, sized to 1350x2760 to match next-wave1..9.png.
set -e
cd "$(dirname "$0")"
SRC_DIR="${1:-raw}"
OUT_DIR="${2:-framed}"
mkdir -p "$OUT_DIR"

R=132            # screen corner radius
B=24             # bezel thickness
CW=1350          # canvas width
CH=2760          # canvas height
BEZEL="#0a0a0c"  # titanium-black bezel
RIM="#3c3d42"    # subtle metallic rim

i=0
for f in "$SRC_DIR"/*.png; do
  i=$((i+1))
  W=$(magick identify -format '%w' "$f")
  H=$(magick identify -format '%h' "$f")
  OR=$((R+B)); FW=$((W+2*B)); FH=$((H+2*B))

  # 1. round the screen corners
  magick "$f" -alpha set \
    \( +clone -alpha transparent -background none \
       -fill white -draw "roundrectangle 0,0,$((W-1)),$((H-1)),$R,$R" \) \
    -compose DstIn -composite /tmp/_screen.png

  # 2. bezel rounded rect, with a thin rim, screen composited centered
  magick -size ${FW}x${FH} xc:none \
    -fill "$BEZEL" -draw "roundrectangle 0,0,$((FW-1)),$((FH-1)),$OR,$OR" \
    -fill none -stroke "$RIM" -strokewidth 3 \
    -draw "roundrectangle 1,1,$((FW-2)),$((FH-2)),$OR,$OR" /tmp/_bezel.png
  magick /tmp/_bezel.png /tmp/_screen.png -geometry +${B}+${B} -compose over -composite /tmp/_device.png

  # 3. drop shadow, then place centered on a light gradient background
  magick /tmp/_device.png \( +clone -background black -shadow 38x28+0+16 \) \
    +swap -background none -layers merge +repage /tmp/_device_sh.png
  magick -size ${CW}x${CH} gradient:'#F5F9FD'-'#E4EEF8' /tmp/_bg.png
  magick /tmp/_bg.png /tmp/_device_sh.png -gravity center -compose over -composite \
    "$OUT_DIR/next-wave${i}.png"
  echo "framed -> $OUT_DIR/next-wave${i}.png"
done
