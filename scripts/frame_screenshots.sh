#!/bin/bash

# Frame Screenshots Script for Next Wave
# Composites raw screenshots into real device bezels using ImageMagick
# (no external "frameme" needed). Auto-detects the device by screenshot size.
# Usage: ./scripts/frame_screenshots.sh [SCREENSHOTS_DIR]

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

SCREENSHOTS_DIR="${1:-Screenshots/en-US}"
BEZEL_DIR="/Users/federi/Library/CloudStorage/Dropbox/Apps/Bezels"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}NextWave - Screenshot Framing (ImageMagick + real bezels)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

if ! command -v magick >/dev/null 2>&1; then
    echo -e "${RED}❌ ImageMagick not found. Install it: brew install imagemagick${NC}"; exit 1
fi
if [ ! -d "$SCREENSHOTS_DIR" ]; then
    echo -e "${RED}❌ Screenshots directory not found: $SCREENSHOTS_DIR${NC}"; exit 1
fi

# Map screenshot dimensions → bezel file + device name
detect_bezel() {
    case "${1}x${2}" in
        1206x2622) echo "iPhone 17 Pro - Deep Blue - Portrait.png|iPhone 17 Pro" ;;
        1290x2796) echo "iPhone 17 Pro - Deep Blue - Portrait.png|iPhone 17 Pro (Max)" ;;
        2048x2732) echo "iPad Air 13\" - M2 - Space Gray - Portrait.png|iPad Air 13-inch" ;;
        2064x2752) echo "iPad Air 13\" - M2 - Space Gray - Portrait.png|iPad Air 13-inch" ;;
        416x496)   echo "AW Ultra 3 - Black + Ocean Band Black.png|Apple Watch Ultra 3" ;;
        *)         echo "|Unknown (${1}x${2})" ;;
    esac
}

# Detect the screen cutout of a bezel (transparent region not touching the border).
hole_geometry() {
    magick "$1" -alpha extract -negate -bordercolor white -border 1 \
        -fill black -floodfill +0+0 white -shave 1x1 -trim -format "%w %h %O" info:
}

FRAMED=0; SKIPPED=0
for shot in "$SCREENSHOTS_DIR"/*.png; do
    [ -f "$shot" ] || continue
    [[ "$shot" == *"-framed.png" ]] && continue
    name=$(basename "$shot")

    W=$(magick identify -format '%w' "$shot"); H=$(magick identify -format '%h' "$shot")
    det=$(detect_bezel "$W" "$H")
    bezel="$BEZEL_DIR/$(echo "$det" | cut -d'|' -f1)"
    device=$(echo "$det" | cut -d'|' -f2)

    echo -e "${BLUE}→ $name  (${device}, ${W}x${H})${NC}"
    if [ ! -f "$bezel" ]; then
        echo -e "${YELLOW}  ⚠ no matching bezel — skipping${NC}"; SKIPPED=$((SKIPPED+1)); continue
    fi

    geo=$(hole_geometry "$bezel")
    hw=$(echo "$geo" | awk '{print $1}'); hh=$(echo "$geo" | awk '{print $2}'); off=$(echo "$geo" | awk '{print $3}')
    out="${shot%.png}-framed.png"

    magick "$shot" -resize ${hw}x${hh}\! /tmp/_fs_scr.png
    magick "$bezel" /tmp/_fs_scr.png -geometry "$off" -compose DstOver -composite "$out"
    echo -e "${GREEN}  ✓ $(basename "$out")${NC}"
    FRAMED=$((FRAMED+1))
done

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Framed: $FRAMED${NC}"
[ "$SKIPPED" -gt 0 ] && echo -e "${YELLOW}  Skipped: $SKIPPED${NC}"
echo -e "${GREEN}  Output: $SCREENSHOTS_DIR/*-framed.png${NC}"
