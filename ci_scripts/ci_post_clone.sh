#!/bin/sh

# ci_post_clone.sh
# This script runs after Xcode Cloud clones the repository

set -e

echo "Creating Config.swift with environment variables..."

# Create Config.swift from environment variables
cat > "Next Wave/Config.swift" << EOF
//
//  Config.swift
//  Next Wave
//
//  Created by Xcode Cloud
//

import Foundation

struct Config {
    static let openWeatherApiKey = "$OPENWEATHER_API_KEY"
}
EOF

echo "Config.swift created successfully"

