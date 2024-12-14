# Next Wave

Next Wave is an iOS app that helps wake surfers and foilers catch their perfect wave on Lake Zurich by providing real-time boat schedules and smart notifications.

![App Screenshot](screenshot.png)

## Features

- 🌊 Real-time boat schedule tracking
- 🔔 Smart notifications 5 minutes before waves
- 📍 Easy spot selection around Lake Zurich
- 🎯 Precise wave timing and direction information
- 🔊 Custom boat horn notifications
- 🎨 Clean, intuitive interface

## Technical Details

- Swift and SwiftUI
- Minimum iOS Version: 17.0
- Supports iPhone in portrait mode
- Uses UserNotifications for local notifications
- Includes custom sound assets
- Schedule data stored in JSON format

## Installation

1. Clone the repository
2. Open `Next Wave.xcodeproj` in Xcode
3. Build and run the project

## Data Structure

The app uses a JSON schedule file with the following structure:

json
{
"dates": "01.04.2024–31.10.2024",
"routes": "Zürichsee",
"routeNumber": "123",
"frequency": "daily",
"stops": {
"location": {
"departures": ["12:00"],
"arrivals": ["12:30"]
}
}
}

The data is stored in an Excel file and is first exported as a CSV file and converted into a JSON. I use the service https://csvjson.com/csv2json with the settings Transpose and Array as output.
The Excel file is located in the Data folder.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contact

Join our community: [Pumpfoiling Community](https://pumpfoiling.community)

## Safety Notice

Always maintain a safe distance from boats and follow local water safety regulations. Never surf directly behind vessels.

## Acknowledgments

- Thanks to all beta testers
- Special thanks to the Lake Zurich boat operators
