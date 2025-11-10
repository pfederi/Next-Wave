#!/bin/bash

# Screenshot Capture & Frame Script for Next Wave
# Usage: ./scripts/capture_screenshots.sh

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Paths
SCREENSHOTS_DIR="Screenshots/en-US"
FRAMEME_PATH="/tmp/frameme"
BEZEL_DIR="/Users/federi/Library/CloudStorage/Dropbox/Apps/Bezels"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}NextWave - Screenshot Capture Tool${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Device selection
echo -e "${YELLOW}Select device:${NC}"
echo "1) iPhone 17 Pro"
echo "2) iPad Air 13-inch (M3)"
echo "3) Apple Watch Ultra 3 (49mm)"
echo ""
read -p "Enter choice [1-3]: " device_choice

case $device_choice in
    1)
        DEVICE_NAME="iPhone 17 Pro"
        BEZEL_NAME="iPhone 17 Pro - Deep Blue - Portrait.png"
        BUILD_SCHEME="NextWave"
        APP_BUNDLE_ID="com.federi.Next-Wave"
        PLATFORM="iOS Simulator"
        ;;
    2)
        DEVICE_NAME="iPad Air 13-inch (M3)"
        BEZEL_NAME="iPad Air 13\" - M2 - Space Gray - Portrait.png"
        BUILD_SCHEME="NextWave"
        APP_BUNDLE_ID="com.federi.Next-Wave"
        PLATFORM="iOS Simulator"
        ;;
    3)
        DEVICE_NAME="Apple Watch Ultra 3 (49mm)"
        BEZEL_NAME="AW Ultra 3 - Black + Ocean Band Black.png"
        BUILD_SCHEME="Next Wave Watch Watch App"
        APP_BUNDLE_ID="com.federi.Next-Wave.watchkitapp"
        PLATFORM="watchOS Simulator"
        ;;
    *)
        echo -e "${RED}❌ Invalid choice${NC}"
        exit 1
        ;;
esac

BEZEL_PATH="$BEZEL_DIR/$BEZEL_NAME"

echo ""
echo -e "${GREEN}✓ Selected: $DEVICE_NAME${NC}"

# For Watch, create/use a paired simulator setup
if [[ "$PLATFORM" == "watchOS Simulator" ]]; then
    echo ""
    echo -e "${BLUE}→ Setting up paired Watch + iPhone simulators...${NC}"
    
    # Check if we have a paired Watch simulator
    PAIRED_WATCH_NAME="Apple Watch Ultra 3 - NextWave Paired"
    PAIRED_IPHONE_NAME="iPhone 17 Pro - NextWave Paired"
    
    # Look for existing paired simulators
    EXISTING_PAIRED_WATCH=$(xcrun simctl list devices | grep "$PAIRED_WATCH_NAME" | grep -v "unavailable" | head -1)
    
    if [ -z "$EXISTING_PAIRED_WATCH" ]; then
        echo -e "${YELLOW}→ Creating new paired simulator setup...${NC}"
        
        # Create iPhone first
        PAIRED_IPHONE_UDID=$(xcrun simctl create "$PAIRED_IPHONE_NAME" "iPhone 17 Pro" "iOS26.1" 2>/dev/null)
        
        if [ -z "$PAIRED_IPHONE_UDID" ]; then
            # Already exists, find it
            PAIRED_IPHONE_UDID=$(xcrun simctl list devices | grep "$PAIRED_IPHONE_NAME" | grep -v "unavailable" | head -1 | grep -oE '\([A-F0-9-]+\)' | tr -d '()')
        fi
        
        # Create paired Watch
        PAIRED_WATCH_UDID=$(xcrun simctl create "$PAIRED_WATCH_NAME" "Apple Watch Ultra 3 (49mm)" "watchOS26.1" "$PAIRED_IPHONE_UDID" 2>/dev/null)
        
        if [ -z "$PAIRED_WATCH_UDID" ]; then
            # Already exists, find it
            PAIRED_WATCH_UDID=$(xcrun simctl list devices | grep "$PAIRED_WATCH_NAME" | grep -v "unavailable" | head -1 | grep -oE '\([A-F0-9-]+\)' | tr -d '()')
        fi
        
        echo -e "${GREEN}✓ Created paired simulator setup${NC}"
    else
        echo -e "${GREEN}✓ Found existing paired simulator setup${NC}"
        
        # Get UUIDs of paired simulators
        PAIRED_WATCH_UDID=$(xcrun simctl list devices | grep "$PAIRED_WATCH_NAME" | grep -v "unavailable" | head -1 | grep -oE '\([A-F0-9-]+\)' | tr -d '()')
        PAIRED_IPHONE_UDID=$(xcrun simctl list devices | grep "$PAIRED_IPHONE_NAME" | grep -v "unavailable" | head -1 | grep -oE '\([A-F0-9-]+\)' | tr -d '()')
    fi
    
    # Use the paired Watch simulator
    DEVICE_NAME="$PAIRED_WATCH_NAME"
    SIMULATOR_UDID="$PAIRED_WATCH_UDID"
    
    # Store iPhone UDID for later use
    COMPANION_IPHONE_UDID="$PAIRED_IPHONE_UDID"
    
    echo -e "${GREEN}✓ Using paired simulators:${NC}"
    echo -e "${GREEN}  iPhone: $PAIRED_IPHONE_NAME${NC}"
    echo -e "${GREEN}  Watch: $PAIRED_WATCH_NAME${NC}"
fi

# Get simulator UDID first (needed for build to avoid ambiguity)
# Skip if already set by paired Watch setup
if [ -z "$SIMULATOR_UDID" ]; then
    echo ""
    echo -e "${BLUE}→ Looking for simulator...${NC}"
    SIMULATOR_UDID=$(xcrun simctl list devices | grep "$DEVICE_NAME" | grep -v "unavailable" | grep "26.1" | head -1 | grep -oE '\([A-F0-9-]+\)' | tr -d '()')

    if [ -z "$SIMULATOR_UDID" ]; then
        # Fallback: try without OS filter
        SIMULATOR_UDID=$(xcrun simctl list devices | grep "$DEVICE_NAME" | grep -v "unavailable" | head -1 | grep -oE '\([A-F0-9-]+\)' | tr -d '()')
    fi

    if [ -z "$SIMULATOR_UDID" ]; then
        echo -e "${RED}❌ Simulator not found: $DEVICE_NAME${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Found simulator: $SIMULATOR_UDID${NC}"
fi

# Build the app for the selected device using UDID to avoid ambiguity
echo ""
echo -e "${BLUE}→ Building Next Wave app for $DEVICE_NAME...${NC}"
echo -e "${YELLOW}   This may take a moment...${NC}"
xcodebuild -scheme "$BUILD_SCHEME" \
    -destination "platform=$PLATFORM,id=$SIMULATOR_UDID" \
    -configuration Debug \
    build \
    > /tmp/nextwave_build.log 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ App built successfully${NC}"
    
    # Find the built app path - different for Watch vs iOS
    if [[ "$BUILD_SCHEME" == *"Watch"* ]]; then
        # For Watch app
        APP_PATH=$(grep -o "/Users/[^[:space:]]*/Next Wave Watch Watch App.app" /tmp/nextwave_build.log | head -1)
        if [ -z "$APP_PATH" ]; then
            # Fallback for Watch
            APP_PATH="/Users/federi/Library/Developer/Xcode/DerivedData/NextWave-gvffoynotxakbxhamhmyptaigmvh/Build/Products/Debug-watchsimulator/Next Wave Watch Watch App.app"
        fi
    else
        # For iOS app
        APP_PATH=$(grep -o "/Users/[^[:space:]]*/Next Wave.app" /tmp/nextwave_build.log | head -1)
        if [ -z "$APP_PATH" ]; then
            # Fallback for iOS
            APP_PATH="/Users/federi/Library/Developer/Xcode/DerivedData/NextWave-gvffoynotxakbxhamhmyptaigmvh/Build/Products/Debug-iphonesimulator/Next Wave.app"
        fi
    fi
    
    echo -e "${BLUE}→ Installing app on simulator...${NC}"
    # We'll install it after booting the simulator
else
    echo -e "${RED}❌ Build failed. Check /tmp/nextwave_build.log for details${NC}"
    tail -n 20 /tmp/nextwave_build.log
    exit 1
fi

# Check if frameme exists (optional - screenshots work fine without frames for App Store)
FRAMEME_AVAILABLE=false
if [ -f "$FRAMEME_PATH" ]; then
    FRAMEME_AVAILABLE=true
    echo -e "${GREEN}✓ frameme found - screenshots will be framed${NC}"
    
    # Check if bezel exists
    if [ ! -f "$BEZEL_PATH" ]; then
        echo -e "${YELLOW}⚠️  Warning: Bezel not found at:${NC}"
        echo -e "${YELLOW}   $BEZEL_PATH${NC}"
        echo -e "${YELLOW}   Screenshots will be saved without frames${NC}"
        FRAMEME_AVAILABLE=false
    fi
else
    echo -e "${YELLOW}⚠️  frameme not found - screenshots will be saved without frames${NC}"
    echo -e "${YELLOW}   (This is perfectly fine for App Store submissions)${NC}"
fi

# Create screenshots directory if it doesn't exist
mkdir -p "$SCREENSHOTS_DIR"

# Boot simulator (UDID was already found earlier for build)
echo ""
echo -e "${BLUE}→ Booting simulator...${NC}"
xcrun simctl boot "$SIMULATOR_UDID" 2>/dev/null || true
open -a Simulator

echo -e "${GREEN}✓ Simulator is starting${NC}"
sleep 3

# Wait for simulator to be ready
echo ""
echo -e "${BLUE}→ Waiting for simulator to be ready...${NC}"
while [ "$(xcrun simctl bootstatus "$SIMULATOR_UDID" 2>&1 | grep -c 'Device already booted')" -eq 0 ]; do
    sleep 1
done
echo -e "${GREEN}✓ Simulator is ready${NC}"

# Install the app on the simulator
echo ""
echo -e "${BLUE}→ Installing Next Wave app on simulator...${NC}"
if [ -d "$APP_PATH" ]; then
    xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
    echo -e "${GREEN}✓ App installed${NC}"
else
    echo -e "${RED}❌ Could not find app at: $APP_PATH${NC}"
    exit 1
fi

# If Watch with paired iPhone: also build, start and configure iPhone app
if [[ "$PLATFORM" == "watchOS Simulator" ]] && [ -n "$COMPANION_IPHONE_UDID" ]; then
    echo ""
    echo -e "${BLUE}→ Setting up iPhone companion app...${NC}"
    
    # Build iPhone app if needed
    if [ ! -d "$IOS_APP_PATH" ]; then
        echo -e "${BLUE}→ Building iPhone app...${NC}"
        xcodebuild -scheme "NextWave" \
            -destination "platform=iOS Simulator,id=$COMPANION_IPHONE_UDID" \
            -configuration Debug \
            build \
            > /tmp/nextwave_ios_build.log 2>&1
        
        if [ $? -eq 0 ]; then
            IOS_APP_PATH=$(grep -o "/Users/[^[:space:]]*/Next Wave.app" /tmp/nextwave_ios_build.log | head -1)
            if [ -z "$IOS_APP_PATH" ]; then
                IOS_APP_PATH="/Users/federi/Library/Developer/Xcode/DerivedData/NextWave-gvffoynotxakbxhamhmyptaigmvh/Build/Products/Debug-iphonesimulator/Next Wave.app"
            fi
            echo -e "${GREEN}✓ iPhone app built${NC}"
        fi
    fi
    
    # Boot iPhone simulator
    xcrun simctl boot "$COMPANION_IPHONE_UDID" 2>/dev/null || true
    sleep 2
    
    # Wait for iPhone to be ready
    while [ "$(xcrun simctl bootstatus "$COMPANION_IPHONE_UDID" 2>&1 | grep -c 'Device already booted')" -eq 0 ]; do
        sleep 1
    done
    
    # Install and launch iPhone app
    if [ -d "$IOS_APP_PATH" ]; then
        xcrun simctl install "$COMPANION_IPHONE_UDID" "$IOS_APP_PATH"
        xcrun simctl location "$COMPANION_IPHONE_UDID" set 47.365662,8.541005
        xcrun simctl launch "$COMPANION_IPHONE_UDID" "com.federi.Next-Wave" 2>/dev/null
        echo -e "${GREEN}✓ iPhone companion app started${NC}"
    fi
fi

# Set location to Zürich Bürkliplatz (nearest station with data)
echo ""
echo -e "${BLUE}→ Setting location to Zürich Bürkliplatz...${NC}"
xcrun simctl location "$SIMULATOR_UDID" set 47.365662,8.541005
echo -e "${GREEN}✓ Location set${NC}"

# Launch Next Wave app
echo ""
echo -e "${BLUE}→ Opening Next Wave app...${NC}"
xcrun simctl launch "$SIMULATOR_UDID" "$APP_BUNDLE_ID" 2>/dev/null || echo -e "${YELLOW}⚠️  Could not launch app automatically. Please open it manually.${NC}"
sleep 2
echo -e "${GREEN}✓ App opened${NC}"

# If Watch with paired iPhone: give user time to configure settings
if [[ "$PLATFORM" == "watchOS Simulator" ]] && [ -n "$COMPANION_IPHONE_UDID" ]; then
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}⌚ Watch + iPhone Setup${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Both simulators are now running and paired!${NC}"
    echo ""
    echo -e "${GREEN}To configure settings before taking screenshots:${NC}"
    echo -e "${GREEN}1. On iPhone simulator: Open Next Wave → Go to Settings${NC}"
    echo -e "${GREEN}2. Change your desired settings (favorites, notifications, etc.)${NC}"
    echo -e "${GREEN}3. Wait 3-5 seconds for Watch Connectivity to sync${NC}"
    echo ""
    read -p "Press ENTER when ready to take Watch screenshots..."
    
    # Restart Watch app to ensure settings are loaded
    echo ""
    echo -e "${BLUE}→ Restarting Watch app to apply settings...${NC}"
    xcrun simctl terminate "$SIMULATOR_UDID" "$APP_BUNDLE_ID" 2>/dev/null
    sleep 1
    xcrun simctl launch "$SIMULATOR_UDID" "$APP_BUNDLE_ID" 2>/dev/null
    sleep 2
    echo -e "${GREEN}✓ Watch app restarted - settings should be synced${NC}"
fi

# Get Desktop screenshots path (where Simulator saves screenshots)
DESKTOP_PATH="$HOME/Desktop"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Ready to capture screenshots!${NC}"
echo ""
echo -e "${YELLOW}Instructions:${NC}"
echo "1. Next Wave app is now running in the simulator"
echo "2. Navigate to the screens you want to capture"
echo "3. Press ${YELLOW}Cmd+S${NC} to take screenshots"
echo "4. Screenshots will be automatically moved and framed"
echo ""
echo -e "${YELLOW}When done, press ENTER to finish...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Record current time for comparison
START_TIME=$(date +%s)

# Monitor for new screenshots in background - TWO separate processes:
# 1. Move screenshots from Desktop to Screenshots folder immediately
# 2. Frame screenshots in the Screenshots folder

PROCESSED_COUNT=0
MOVED_FILES=()
FRAMED_FILES=()

# Process 1: Move screenshots from Desktop ASAP
{
    while true; do
        find "$DESKTOP_PATH" -name "Simulator Screenshot*.png" -type f 2>/dev/null | while read -r screenshot; do
            # Skip if already moved
            if [[ " ${MOVED_FILES[@]} " =~ " ${screenshot} " ]]; then
                continue
            fi
            
            # Get file creation time
            FILE_TIME=$(stat -f %B "$screenshot" 2>/dev/null)
            
            # Skip if file was created before we started
            if [ "$FILE_TIME" -lt "$START_TIME" ]; then
                continue
            fi
            
            # Mark as moved
            MOVED_FILES+=("$screenshot")
            
            echo ""
            echo -e "${GREEN}→ New screenshot detected: $(basename "$screenshot")${NC}"
            
            # Generate a nice filename
            TIMESTAMP=$(date +%s)
            NEW_NAME="screenshot-${DEVICE_NAME// /-}-$TIMESTAMP.png"
            DEST_PATH="$SCREENSHOTS_DIR/$NEW_NAME"
            
            # Move to screenshots directory immediately
            if mv "$screenshot" "$DEST_PATH" 2>/dev/null; then
                echo -e "${GREEN}  ✓ Moved to: $NEW_NAME${NC}"
                PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
            else
                echo -e "${RED}  ✗ Failed to move screenshot${NC}"
            fi
        done
        
        sleep 0.2  # Check every 200ms for fast response
    done
} &
MOVE_PID=$!

# Process 2: Frame screenshots in the Screenshots folder
if [ "$FRAMEME_AVAILABLE" = true ]; then
    {
        sleep 2  # Give the move process a head start
        
        while true; do
            # Find screenshots that don't have "-framed" in the name and aren't already processed
            find "$SCREENSHOTS_DIR" -name "screenshot-*.png" ! -name "*-framed.png" -type f 2>/dev/null | while read -r screenshot; do
                # Check if framed version already exists
                framed_path="${screenshot%.png}-framed.png"
                if [ -f "$framed_path" ]; then
                    # Framed version exists, delete original
                    rm -f "$screenshot"
                    continue
                fi
                
                # Get file creation time
                FILE_TIME=$(stat -f %B "$screenshot" 2>/dev/null)
                
                # Skip if file was created before we started
                if [ "$FILE_TIME" -lt "$START_TIME" ]; then
                    continue
                fi
                
                echo -e "${BLUE}  → Framing $(basename "$screenshot")...${NC}"
                
                # Run frameme - it will create screenshot-name_framed.png
                "$FRAMEME_PATH" "$BEZEL_PATH" "$screenshot" > /dev/null 2>&1
                
                # Wait a moment for file to be written
                sleep 1
                
                # Check if frameme created the _framed version (with underscore)
                frameme_output="${screenshot%.png}_framed.png"
                if [ -f "$frameme_output" ]; then
                    # Rename to our naming convention (dash instead of underscore)
                    mv "$frameme_output" "$framed_path"
                    
                    # Delete original unframed screenshot
                    rm -f "$screenshot"
                    
                    echo -e "${GREEN}  ✓ Framed successfully: $(basename "$framed_path")${NC}"
                else
                    echo -e "${YELLOW}  ⚠ Framing produced no output${NC}"
                fi
            done
            
            sleep 0.5  # Check every 500ms
        done
    } &
    FRAME_PID=$!
fi

# Wait for user to press ENTER
read -r

# Kill both monitoring processes
kill $MOVE_PID 2>/dev/null
if [ -n "$FRAME_PID" ]; then
    kill $FRAME_PID 2>/dev/null
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Done!${NC}"
echo -e "${GREEN}  Processed: $PROCESSED_COUNT screenshot(s)${NC}"
echo -e "${GREEN}  Saved to: $SCREENSHOTS_DIR/${NC}"
echo ""
echo -e "${YELLOW}Framed screenshots are saved as: screenshot-*-framed.png${NC}"
echo -e "${YELLOW}Original unframed screenshots were automatically deleted.${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

