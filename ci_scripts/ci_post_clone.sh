#!/bin/sh

# ci_post_clone.sh
# This script runs after Xcode Cloud clones the repository

set -e

echo "Creating Config.swift with environment variables..."

# Check if environment variable is set
if [ -z "$OPENWEATHER_API_KEY" ]; then
    echo "Error: OPENWEATHER_API_KEY environment variable is not set"
    exit 1
fi

# Create the directory if it doesn't exist
mkdir -p "Next Wave"

# Create Config.swift from environment variables
cat > "Next Wave/Config.swift" << 'EOF'
//
//  Config.swift
//  Next Wave
//
//  Created by Xcode Cloud
//

import Foundation

struct Config {
    static let openWeatherApiKey = "PLACEHOLDER_API_KEY"
}
EOF

# Replace placeholder with actual API key
sed -i '' "s/PLACEHOLDER_API_KEY/$OPENWEATHER_API_KEY/g" "Next Wave/Config.swift"

echo "Config.swift created successfully"
echo "API Key: ${OPENWEATHER_API_KEY:0:10}..." # Show only first 10 chars for verification

