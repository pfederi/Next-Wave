// Example configuration file for local development
// This file will be overwritten by ci_post_clone.sh in Xcode Cloud
// 
// To use this:
// 1. Copy this file to Config.swift: cp "Next Wave/Config.example.swift" "Next Wave/Config.swift"
// 2. Add your actual API key below
// 3. Never commit Config.swift to git (it's in .gitignore)

struct Config {
    // Get your API key from https://openweathermap.org/api
    static let openWeatherApiKey: String = "YOUR_API_KEY_HERE"
} 