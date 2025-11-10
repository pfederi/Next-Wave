#!/bin/bash

# Frame Screenshots Script for Next Wave
# Automatically detects device type and uses the correct bezel
# Usage: ./scripts/frame_screenshots.sh

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Paths
SCREENSHOTS_DIR="Screenshots/en-US"
BEZEL_DIR="/Users/federi/Library/CloudStorage/Dropbox/Apps/Bezels"
FRAMEME_PATH="/tmp/frameme"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}NextWave - Automatic Screenshot Framing Tool${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if frameme exists
if [ ! -f "$FRAMEME_PATH" ]; then
    echo -e "${RED}❌ Error: frameme not found at $FRAMEME_PATH${NC}"
    echo -e "${RED}   Please install frameme first${NC}"
    exit 1
fi

# Check if screenshots directory exists
if [ ! -d "$SCREENSHOTS_DIR" ]; then
    echo -e "${RED}❌ Error: Screenshots directory not found: $SCREENSHOTS_DIR${NC}"
    exit 1
fi

# Function to detect device type based on screenshot dimensions
detect_device() {
    local width=$1
    local height=$2
    local bezel=""
    local device_name=""
    
    # iPhone 17 Pro (Portrait: 1290x2796)
    if [ "$width" -eq 1290 ] && [ "$height" -eq 2796 ]; then
        bezel="$BEZEL_DIR/iPhone 17 Pro - Deep Blue - Portrait.png"
        device_name="iPhone 17 Pro"
    # iPad Air 13-inch (Portrait: 2048x2732)
    elif [ "$width" -eq 2048 ] && [ "$height" -eq 2732 ]; then
        bezel="$BEZEL_DIR/iPad Air 13\" - M2 - Space Gray - Portrait.png"
        device_name="iPad Air 13-inch"
    # Apple Watch Ultra 3 (416x496)
    elif [ "$width" -eq 416 ] && [ "$height" -eq 496 ]; then
        bezel="$BEZEL_DIR/AW Ultra 3 - Black + Ocean Band Black.png"
        device_name="Apple Watch Ultra 3"
    else
        device_name="Unknown (${width}x${height})"
    fi
    
    echo "$bezel|$device_name"
}

# Count screenshots to frame
SCREENSHOT_COUNT=$(find "$SCREENSHOTS_DIR" -name "*.png" ! -name "*-framed.png" -type f | wc -l | tr -d ' ')

if [ "$SCREENSHOT_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}No screenshots found to frame in $SCREENSHOTS_DIR${NC}"
    exit 0
fi

echo -e "${GREEN}✓ Found $SCREENSHOT_COUNT screenshot(s) to frame${NC}"
echo ""

# Frame each screenshot
FRAMED_COUNT=0
SKIPPED_COUNT=0

for screenshot in "$SCREENSHOTS_DIR"/*.png; do
    # Skip if already framed
    if [[ "$screenshot" == *"-framed.png" ]]; then
        continue
    fi
    
    [ -f "$screenshot" ] || continue
    
    filename=$(basename "$screenshot")
    
    # Get dimensions
    dimensions=$(sips -g pixelWidth -g pixelHeight "$screenshot" 2>/dev/null | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w,h}')
    width=$(echo "$dimensions" | awk '{print $1}')
    height=$(echo "$dimensions" | awk '{print $2}')
    
    # Detect device and bezel
    detection=$(detect_device "$width" "$height")
    bezel_path=$(echo "$detection" | cut -d'|' -f1)
    device_name=$(echo "$detection" | cut -d'|' -f2)
    
    echo -e "${BLUE}→ Framing: $filename${NC}"
    echo -e "${BLUE}  Device: $device_name${NC}"
    
    # Check if bezel exists
    if [ -z "$bezel_path" ] || [ ! -f "$bezel_path" ]; then
        echo -e "${YELLOW}  ⚠ No matching bezel found - skipping${NC}"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        echo ""
        continue
    fi
    
    # Frame the screenshot
    "$FRAMEME_PATH" "$bezel_path" "$screenshot" > /dev/null 2>&1
    sleep 0.5
    
    # Check if framed version was created (frameme creates with _framed.png)
    frameme_output="${screenshot%.png}_framed.png"
    if [ -f "$frameme_output" ]; then
        # Delete original
        rm -f "$screenshot"
        
        # Rename to our naming convention (dash instead of underscore)
        final_path="${screenshot%.png}-framed.png"
        mv "$frameme_output" "$final_path"
        
        echo -e "${GREEN}  ✓ Framed successfully: $(basename "$final_path")${NC}"
        FRAMED_COUNT=$((FRAMED_COUNT + 1))
    else
        echo -e "${RED}  ✗ Failed to frame${NC}"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    fi
    echo ""
done

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Done!${NC}"
echo -e "${GREEN}  Framed: $FRAMED_COUNT screenshot(s)${NC}"
if [ "$SKIPPED_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}  Skipped: $SKIPPED_COUNT screenshot(s)${NC}"
fi
echo -e "${GREEN}  Saved to: $SCREENSHOTS_DIR/*-framed.png${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

