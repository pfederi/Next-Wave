#!/bin/bash

# Frame Screenshots Script for Next Wave
# Usage: ./scripts/frame_screenshots.sh

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Paths
SCREENSHOTS_DIR="Screenshots/en-US"
BEZEL_PATH="/Users/federi/Library/CloudStorage/Dropbox/Apps/Bezels/iPhone 17 Pro - Deep Blue - Portrait.png"
FRAMEME_PATH="/tmp/frameme"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}NextWave - Screenshot Framing Tool${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if frameme exists
if [ ! -f "$FRAMEME_PATH" ]; then
    echo -e "${RED}❌ Error: frameme not found at $FRAMEME_PATH${NC}"
    echo -e "${RED}   Please install frameme first${NC}"
    exit 1
fi

# Check if bezel exists
if [ ! -f "$BEZEL_PATH" ]; then
    echo -e "${RED}❌ Error: Device bezel not found at:${NC}"
    echo -e "${RED}   $BEZEL_PATH${NC}"
    exit 1
fi

# Check if screenshots directory exists
if [ ! -d "$SCREENSHOTS_DIR" ]; then
    echo -e "${RED}❌ Error: Screenshots directory not found: $SCREENSHOTS_DIR${NC}"
    exit 1
fi

# Count screenshots
SCREENSHOT_COUNT=$(find "$SCREENSHOTS_DIR" -name "*.png" ! -name "*_framed.png" | wc -l | tr -d ' ')

if [ "$SCREENSHOT_COUNT" -eq 0 ]; then
    echo -e "${RED}❌ No screenshots found in $SCREENSHOTS_DIR${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found $SCREENSHOT_COUNT screenshot(s) to frame${NC}"
echo -e "${GREEN}✓ Using bezel: iPhone 17 Pro - Deep Blue${NC}"
echo ""

# Frame each screenshot
FRAMED_COUNT=0
SKIPPED_COUNT=0

for screenshot in "$SCREENSHOTS_DIR"/*.png; do
    # Skip if already framed
    if [[ "$screenshot" == *"_framed.png" ]]; then
        continue
    fi
    
    filename=$(basename "$screenshot")
    echo -e "${BLUE}→ Framing: $filename${NC}"
    
    # Frame the screenshot
    "$FRAMEME_PATH" "$BEZEL_PATH" "$screenshot"
    
    # Check if framed version was created
    framed_screenshot="${screenshot%.png}_framed.png"
    if [ -f "$framed_screenshot" ]; then
        # Replace original with framed version
        mv "$framed_screenshot" "$screenshot"
        echo -e "${GREEN}  ✓ Framed successfully${NC}"
        FRAMED_COUNT=$((FRAMED_COUNT + 1))
    else
        echo -e "${RED}  ✗ Failed to frame${NC}"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    fi
    echo ""
done

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Done!${NC}"
echo -e "${GREEN}  Framed: $FRAMED_COUNT${NC}"
if [ "$SKIPPED_COUNT" -gt 0 ]; then
    echo -e "${RED}  Failed: $SKIPPED_COUNT${NC}"
fi
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

