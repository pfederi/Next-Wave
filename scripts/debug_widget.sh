#!/bin/bash

echo "🔧 NextWave Widget Debug Script"
echo "================================"

# Navigate to project directory
cd "$(dirname "$0")/.."

echo "📍 Current directory: $(pwd)"

# Clean build cache
echo "🧹 Cleaning build cache..."
rm -rf ~/Library/Developer/Xcode/DerivedData/NextWave-*
xcodebuild clean -project NextWave.xcodeproj -scheme NextWaveWidgetExtension

echo "🔨 Building widget extension..."
xcodebuild build -project NextWave.xcodeproj -scheme NextWaveWidgetExtension -destination 'platform=iOS Simulator,name=iPhone 16'

echo "📱 Checking widget configuration..."
echo "iPhone Widget: NextWaveiPhoneWidget (iOS only)"
echo "Watch Widget: NextWaveWatchWidget (watchOS only)"
echo "App Group: group.com.federi.Next-Wave"

echo "🔍 Checking entitlements..."
if [ -f "NextWaveWidgetExtension.entitlements" ]; then
    echo "✅ Widget entitlements found"
    cat NextWaveWidgetExtension.entitlements
else
    echo "❌ Widget entitlements not found"
fi

echo "📋 Widget debug complete!"
echo "Next steps:"
echo "1. Check Xcode console for 🔍 DEBUG messages"
echo "2. Add widget to home screen and check for errors"
echo "3. Use the debug button in the app to force widget updates" 