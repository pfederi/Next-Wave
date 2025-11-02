# Next Wave

Next Wave is an iOS app that helps wake surfers and foilers catch their perfect wave on Lake Zurich by providing real-time boat schedules and smart notifications.

<img src="Screenshots/next-wave1.png" alt="Screenshot1" width="200"><img src="Screenshots/next-wave2.png" alt="Screenshot2" width="200"><img src="Screenshots/next-wave3.png" alt="Screenshot3" width="200"><img src="Screenshots/next-wave4.png" alt="Screenshot4" width="200"><img src="Screenshots/next-wave5.png" alt="Screenshot5" width="200"><img src="Screenshots/next-wave6.png" alt="Screenshot6" width="200"><img src="Screenshots/next-wave7.png" alt="Screenshot7" width="200">


<a href="https://apps.apple.com/ch/app/next-wave/id6739363035">
    <img src="https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us?size=250x83&amp;releaseDate=1705363200" alt="Download on the App Store" style="border-radius: 13px; width: 250px; height: 83px;">
</a>

## Table of Contents

- [Features](#features)
- [Map Features](#map-features)
- [Safety Features](#safety-features)
- [Lake Zurich Ship Names](#lake-zurich-ship-names)
- [Weather Integration](#weather-integration)
- [User Interface Features](#user-interface-features)
- [Widget Features](#widget-features)
- [Technologies & Services](#technologies--services)
- [Installation](#installation)
- [Privacy](#privacy)
- [Usage Modes](#usage-modes)
- [How to Add a New Lake or Station](#how-to-add-a-new-lake-or-station)
- [Technical Details](#technical-details)
- [Contributing](#contributing)
- [License](#license)

## Features

- 🌊 Real-time boat schedule tracking
- 🔔 Smart notifications 3,5,10 or 15 minutes before waves
- 📍 Easy spot selection on Swiss lakes
- 🆕 Store up to 5 favorite stations
- 🆕 Smart nearest station detection
- ⌚️ Apple Watch app with complications and widgets
- 🎯 Apple Watch app with two usage modes: Favorite stations OR automatic nearest station
- 🆕 Analytics View with session recommendations, wave timeline, best session detection and wave frequency analysis
- 🆕 Daylight Integration with sunrise, sunset, twilight phase visualization, smart session planning based on daylight and beautiful gradient visualization
- 🎯️ Interactive map with OpenStreetMap integration
- 🎯 Precise wave timing information
- 🔊 Custom sound notifications
- 🎨 Clean, intuitive interface
- 📱 Light & Dark Mode
- 🔄 Device flip gesture to toggle between light and dark mode
- 🛡️ Integrated safety rules and wakethieving guidelines
- 📅 Automatic schedule period detection (summer/winter schedules)
- ⏰ Smart countdown messages for upcoming schedule changes
- 🚢 Real-time ship name display for Lake Zurich (next 3 days)
- 🌤️ Real-time weather information with wind speed, temperature, and pressure trends
- 🌡️ Water temperature display for all Swiss lakes
- 🔍 Albis-Class ship filter (flip device to activate/deactivate)
- 💬 Fun "no waves" messages with variety and personality

## Map Features

- OpenStreetMap integration for detailed water navigation
- Shipping routes overlay for better orientation
- Station clustering for better overview
- Automatic map caching for offline use
- Optimized for both light and dark mode

## Safety Features

- **Integrated Safety Rules**: Built-in wakethieving safety guidelines displayed on first launch
- **Easy Access**: Safety rules accessible anytime via the orange shield icon in settings
- **Comprehensive Guidelines**: Complete safety information including:
  - Safe distance requirements (50-meter rule)
  - Priority vessel identification (day and night)
  - Required safety equipment
  - Emergency procedures
- **Community Integration**: Direct link to Swiss Pumpfoilers Code of Conduct

## Lake Zurich Ship Names

### Real-Time Ship Identification
- **Live Ship Data**: Displays the actual ship name for each departure on Lake Zurich
- **3-Day Forecast**: Shows ship names for departures within the next 3 days
- **Wave Rating Icons**: Visual indicators showing expected wave quality (1-3 waves) based on ship type
- **Automatic Updates**: Ship assignments are fetched daily from ZSG (Zürichsee-Schifffahrtsgesellschaft)
- **Smart Caching**: Efficient caching system to minimize API calls while keeping data fresh

### Ship Information Display
- Ship names appear directly in the departure list alongside route numbers
- Wave quality icons help you identify the best sessions
- Only available for Lake Zurich stations (ZSG network)
- Seamlessly integrated into the existing departure view

## Weather Integration

### Real-Time Weather Information
- **OpenWeather API Integration**: Live weather data for all stations
- **Comprehensive Data**: Temperature, wind speed (in knots), wind direction, and atmospheric pressure
- **Pressure Trends**: Automatic tracking of pressure changes over 6 hours (rising/falling/stable)
- **Wind Information**: Current wind speed, maximum wind speed, and wind gusts
- **Weather Icons**: Visual weather condition indicators with SF Symbols
- **Forecast Data**: Weather predictions for upcoming departures
- **Smart Preloading**: Weather data preloaded for favorite stations at app launch
- **Per-Departure Weather**: Weather information shown for each individual departure time
- **Toggle Option**: Can be enabled/disabled in settings

### Water Temperature Display
- **Real-Time Data**: Current water temperature for all major Swiss lakes
- **Meteonews Integration**: Data sourced from meteonews.ch
- **Daily Updates**: Automatic refresh once per day
- **Smart Caching**: 24-hour cache to minimize API calls
- **Visual Integration**: Displayed alongside weather data with consistent UI
- **Coverage**: Available for 30+ Swiss lakes including Zürichsee, Vierwaldstättersee, Genfersee, Bodensee, and more

### Water Level Display
- **Real-Time Data**: Current water level for all major Swiss lakes
- **Difference from Average**: Shows how much the current water level differs from the average (e.g., "+7 cm" or "-5 cm")
- **Meteonews Integration**: Water level data sourced from meteonews.ch
- **Daily Updates**: Automatic refresh once per day
- **Visual Integration**: Displayed with chart icon alongside weather data
- **Coverage**: Available for lakes where meteonews.ch provides water level data
- **Foiler-Friendly**: Helps foilers assess water conditions and depth

### Weather Display Features
- Weather condition icons (visual indicators)
- Temperature in Celsius with min/max values
- Water temperature for all Swiss lakes
- Wind speed in knots (nautical standard)
- Wind direction with compass points (N, NE, E, SE, S, SW, W, NW)
- Water level difference from average (in cm)
- Atmospheric pressure with trend indicators
- Clean, compact display with separator bars for readability

## User Interface Features

### Device Flip Gesture
- **Dual Function**: Flip your device 180° to toggle between light/dark mode OR activate Albis-Class filter
- **Context-Aware**: In departure view, activates ship filter; elsewhere toggles theme
- **Smooth Recognition**: Intuitive gesture detection using CoreMotion
- **Cooldown Period**: 3-second delay prevents accidental repeated triggers
- **Haptic Feedback**: Different feedback for activation vs. deactivation

### Albis-Class Ship Filter
- **Quick Access**: Activate by flipping your device in the departure list view
- **Filter Ships**: Shows only departures with Albis-Class ships (MS Albis, EMS Uetliberg, EMS Pfannenstiel)
- **Visual Indicator**: Orange banner shows when filter is active
- **Best Waves**: Focus on the ships that create the best wake waves
- **Toggle On/Off**: Flip device again to deactivate and show all departures

### Best Surf Sessions Analytics
- **Quality-First Scoring**: Sessions prioritize large ships (3-wave ships) over quantity
- **Smart Scoring System**: 
  - 3-wave ships (MS Panta Rhei, MS Albis, EMS Uetliberg, EMS Pfannenstiel): 10 points
  - 2-wave ships (MS Wädenswil, MS Limmat, MS Helvetia, MS Linth, DS Stadt Zürich, DS Stadt Rapperswil): 5 points
  - 1-wave ships: 2 points
- **Frequency Bonus**: Additional scoring for higher wave frequency (secondary factor)
- **Daylight Optimization**: 
  - Sessions in complete darkness automatically excluded
  - Twilight sessions receive reduced scores (80% penalty)
  - Best sessions during full daylight hours
- **Session Parameters**: 
  - Maximum duration: 2 hours
  - Minimum duration: 1 hour
  - Maximum gap between waves: 1 hour
- **Result**: Sessions with 4 large ships rated higher than sessions with 10 small ships

### Schedule Period Management
- **Automatic Detection**: App automatically detects summer and winter schedule periods
- **Smart Notifications**: Get notified about upcoming schedule changes with fun, personalized messages
- **30-Day Advance Notice**: Countdown messages appear when schedule transitions are within 31 days
- **Season-Specific Messages**: Different witty messages for summer, winter, spring, and autumn transitions
- **All Swiss Lakes**: Works for all 15+ major Swiss lakes with boat services

### Fun User Experience
- **"No Waves" Messages**: 20+ unique, fun messages when no more departures are available
- **Variety System**: Messages rotate to keep the experience fresh and entertaining
- **Personality**: Surf culture references, Hawaiian vibes, and wakethieving humor
- **No Service Messages**: Friendly messages when stations are temporarily out of service
- **Examples**: "No more waves today – back in the lineup tomorrow!", "Post-pumping high is real – but even the ships need a break!"

## Technologies & Services

### Core Technologies

- **SwiftUI**: Modern declarative UI framework for iOS and watchOS
- **Swift Concurrency**: Async/await patterns for non-blocking operations
- **CoreMotion**: Device motion detection for flip gestures
- **CoreLocation**: Location services for nearest station detection
- **WidgetKit**: Home screen and lock screen widgets
- **WatchConnectivity**: Real-time data sync between iPhone and Apple Watch
- **UserNotifications**: Local notifications for wave alerts
- **MapKit**: Map integration with custom overlays

### External APIs & Services

#### Transport Data
- **[transport.opendata.ch](https://transport.opendata.ch)**: Swiss public transport API
  - Real-time departure data for all Swiss ferry stations
  - Station information and timetables
  - Free, open-source API for Swiss public transport

#### Weather Data
- **[OpenWeather API](https://openweathermap.org)**: Weather forecasts and current conditions
  - Temperature, wind speed, and atmospheric pressure
  - 5-day forecast with 3-hour intervals
  - Weather condition codes and icons

#### Sun Times
- **[Sunrise-Sunset.org API](https://sunrise-sunset.org)**: Sunrise and sunset times
  - Civil twilight begin/end times
  - Daylight duration calculations
  - Free API for sun times worldwide

#### Ship Deployment Data
- **Custom Vercel API** (`/api/ships`): Real-time ship assignments for Lake Zurich
  - Web scraping from [ZSG ship deployment website](https://einsatzderschiffe.zsg.ch)
  - Daily cache updates
  - 3-day forecast of ship-to-route assignments

#### Map Data
- **[OpenStreetMap](https://www.openstreetmap.org)**: Map tiles and geographic data
  - Detailed water navigation maps
  - Shipping routes overlay
  - Ferry terminal locations
  - **[Overpass Turbo](https://overpass-turbo.eu)**: Tool for finding ferry terminal data

### Backend & Deployment

- **[Vercel](https://vercel.com)**: Serverless functions for ship data API
  - TypeScript/Node.js runtime
  - Automatic daily updates
  - Edge caching for performance

#### Node.js Dependencies
- **[@vercel/node](https://www.npmjs.com/package/@vercel/node)**: Vercel serverless function helpers
- **[puppeteer-core](https://www.npmjs.com/package/puppeteer-core)**: Headless browser automation for dynamic content scraping
- **[@sparticuz/chromium](https://www.npmjs.com/package/@sparticuz/chromium)**: Chromium binary optimized for serverless environments
- **[cheerio](https://cheerio.js.org)**: jQuery-like HTML parsing for web scraping
- **[TypeScript](https://www.typescriptlang.org)**: Type-safe JavaScript development

### Data Storage & Development Tools

#### Data Storage
- **UserDefaults**: Local settings and preferences
- **App Groups**: Shared data between app, widgets, and watch
- **JSON Files**: Station data and schedule periods
- **In-Memory Caching**: Weather and ship name caching

#### Development Tools
- **Xcode**: Primary IDE for iOS development
- **Python**: Scripts for ship data analysis and wave calculations
- **Git**: Version control

## Installation

1. Clone the repository
2. Open `Next Wave.xcodeproj` in Xcode
3. Create a `Config.swift` file with your API keys:
   ```swift
   struct Config {
       static let openWeatherApiKey = "YOUR_API_KEY"
   }
   ```
4. Build and run the project

## Privacy

- No tracking or analytics
- No personal data collection
- All data stays on device
- Location data is only used to show nearest station and your position on the map and is never stored or shared
- Location access can be denied without losing core app functionality

## Location Permission

The app requests location access to:
- Show your position on the map
- Enable the location tracking button
- Find the nearest station from all available ferry stations

You can use the app without granting location access. In this case:
- Your position won't be shown on the map
- The location tracking button will be disabled
- The nearest station feature will not work (you can still use favorite stations)

## Usage Modes

Next Wave offers two flexible ways to get departure information:

### 1. Favorite Stations Mode (Default)
- Add up to 5 frequently used stations as favorites
- Get departure times for all your favorite stations
- Perfect for regular commuters with fixed routes

### 2. Nearest Station Mode
- Enable "Use nearest station for Widget" in app settings
- Automatically shows departures for the station closest to your current location
- Calculates nearest station from ALL available ferry stations (not just favorites)
- Perfect for travelers and explorers discovering new spots
- Works even if the nearest station is not in your favorites

### Apple Watch & Widget Support
- **Watch App**: Shows departures for favorites or nearest station
- **Smart Fallback**: If nearest station has no departures, automatically falls back to favorites
- **Helpful Messages**: Clear instructions when no favorites are set or nearest station is disabled

## Widget Features

### iPhone Widgets
- **NextWave Widget**: Shows your next boat departure
  - Available in Small, Medium, Large, and Extra Large sizes
  - Displays station name, departure time, route, and direction
  - Visual indicators for nearest station or favorite station
  - Deep link support to open app at specific station
  
- **NextWave - Next 3 Widget**: Shows your next 3 boat departures
  - Available in Medium and Large sizes
  - Compact list view of upcoming departures
  - Perfect for planning your session timing
  
- **Widget Modes**:
  - Favorite Station Mode: Shows departures from your first favorite
  - Nearest Station Mode: Automatically shows closest station
  - Configurable in app settings

### Apple Watch Widgets
- Complications for all watch faces
- Circular, rectangular, and inline styles
- Real-time departure information on your wrist
- Synchronized with iPhone settings

## Support

For questions or issues, please create an issue in the repository.


## How to add a new lake or station

### Data Structure

The app uses a JSON schedule file with the following structure. Note that coordinates are required for map display:

```
{
    "lakes": [
        {
            "name": "Lake",
            "operators": [
                "Operator"
            ],
            "stations": [
                {
                    "name": "Station Name",
                    "uic_ref": "8503651",
                    "coordinates": {
                        "latitude": 47.218035,
                        "longitude": 8.776638
                    }
                },
                {
                    "name": "Station Name",
                    "uic_ref": "8503682",
                    "coordinates": {
                        "latitude": 47.218035,
                        "longitude": 8.776638
                    }
                }
            ]
        },
    ]
}
```

To find the name and especially the station ID, use the tool https://overpass-turbo.eu/
Search for the lake on the map on the right and make it completely visible. enter the following query in the console on the left:

```
node
  [amenity=ferry_terminal]
  ({{bbox}});
out;
```

All ship stations are displayed. Clicking on the station opens a window where you can find the station ID, the name of the station and the coordinates. uic_name and uic_ref. These values are entered in the JSON file.

You can check whether the station is available in the API via https://transport.opendata.ch/v1/locations?query=[uic_ref].
The link above is for Switzerland. For other countries, you have to find another api to find departure times.

## Technical Details

### Recent Technical Improvements

#### Ship Data Loading Optimization (v3.3)
- **Puppeteer-Based Scraping**: Advanced web scraping using headless Chrome to handle dynamic AJAX content
- **Multi-Day Data Fetching**: Correctly loads ship assignments for today and next 2 days by simulating date picker clicks
- **Intelligent Caching System**: Three-layer caching strategy (API cache, URLSession cache, in-memory cache)
- **Zero Loading Flicker**: Ship names appear instantly from cache without "Loading..." indicators
- **Single UI Update**: All data (weather + ship names) loaded in background before single smooth UI update
- **Performance**: 24-hour client-side cache eliminates redundant API calls, dramatically improving app responsiveness

#### Device Motion Detection
- **CoreMotion Integration**: Uses device motion sensors to detect 180° flip gestures
- **Smart Gesture Recognition**: Detects roll rotation with tolerance for natural device handling
- **Debounce Logic**: 3-second cooldown prevents accidental repeated triggers
- **State Management**: Tracks initial orientation and reset states for reliable detection
- **Theme Toggle**: Seamlessly switches between light and dark mode on device flip

#### Smart Nearest Station Algorithm
- **Advanced Location Processing**: Uses CoreLocation to find the geographically closest ferry station
- **Comprehensive Station Database**: Searches through ALL available stations across multiple Swiss lakes
- **Intelligent Departure Loading**: Automatically fetches departure data for nearest station even if not in favorites
- **Fallback System**: Gracefully falls back to favorite stations if nearest station has no departures
- **Real-time Synchronization**: Coordinates between iOS app, Apple Watch, and widgets via shared data containers

#### Cross-Platform Data Synchronization
- **App Groups**: Seamless data sharing between main app, Watch app, and widgets
- **WatchConnectivity**: Real-time synchronization of favorites and settings between iPhone and Apple Watch
- **Smart Caching**: Optimized caching system to minimize API calls while ensuring fresh data
- **Background Updates**: Intelligent background refresh with adaptive timing based on next departure

### Schedule Period Management
- **JSON-Based Configuration**: Centralized schedule period data for all Swiss lakes
- **Automatic Period Detection**: Real-time detection of active schedule periods based on current date
- **Smart Countdown System**: Calculates days until next schedule change with personalized messages
- **Season-Aware Messaging**: Context-aware messages based on transition type (summer/winter/spring/autumn)
- **Multi-Lake Support**: Handles different schedule periods for 15+ Swiss lakes simultaneously

#### Safety and User Experience
- **First Launch Detection**: UserDefaults-based system to show safety rules on initial app launch
- **Modal Presentation**: SwiftUI-based modal with comprehensive safety information
- **Persistent Access**: Safety rules accessible anytime via settings
- **Community Integration**: Deep links to external safety resources

#### Ship Name Integration
- **VesselAPI Service**: Dedicated Swift service for fetching ship assignments
- **Async/Await Pattern**: Modern Swift concurrency for non-blocking API calls
- **Date-Based Caching**: Cache key format: `YYYY-MM-DD_CourseNumber`
- **Parallel Loading**: Ship names loaded asynchronously after initial departure data
- **UI Updates**: Progressive enhancement - departures show immediately, ship names appear when loaded
- **3-Day Window**: Only fetches ship names for departures within next 72 hours
- **Lake Detection**: Automatically identifies Lake Zurich stations by ID prefix (85036)
- **Wave Icons**: Dynamic icon selection based on ship name and wave rating database

#### Weather API Integration
- **OpenWeather API**: RESTful API integration for weather forecasts
- **Async Data Loading**: Non-blocking weather data fetching using Swift async/await
- **Pressure History Tracking**: 6-hour rolling window for pressure trend calculation
- **Smart Preloading**: Weather data preloaded for all favorite stations at app launch
- **Parallel Requests**: TaskGroup-based concurrent loading for multiple stations
- **Per-Wave Weather**: Individual weather data for each departure time
- **Forecast Matching**: Finds closest forecast time to each departure
- **Unit Conversion**: Automatic conversion from m/s to knots for nautical use
- **Weather Codes**: Comprehensive mapping of OpenWeather condition codes to SF Symbols
- **Error Handling**: Graceful degradation when weather data unavailable

#### Albis-Class Filter System
- **Ship Database**: Hardcoded list of Albis-Class ships (MS Albis, EMS Uetliberg, EMS Pfannenstiel)
- **Real-Time Filtering**: Instant filtering of departure list based on ship names
- **State Management**: Published property for reactive UI updates
- **Haptic Feedback**: UINotificationFeedbackGenerator for activation, UIImpactFeedbackGenerator for deactivation
- **Visual Indicators**: Orange banner with filter status in departure list
- **Gesture Integration**: Connected to device flip gesture in departure view context

### Ship Data and Wave Calculation

The app uses various systems for collecting ship data and calculating wave characteristics:

#### 1. Vessel Data Scraper and Wave Calculation (`scripts/vesseldata.py`)
- Automatically extracts technical data of all ZSG ships
- Collects information like length, width, displacement etc.
- Calculates based on technical data:
  - Maximum wave height (m): `H = 0.04 * D * v² / (L * B)`
  - Wave length (m): `λ = 2π * v² / g`
  - Wave period (s): `T = √(2π * λ / g)`
  - Wave velocity (m/s): `c = λ / T`
  - Wave energy (J/m²): `E = (1/8) * ρ * g * H²`
  - Wave power (W/m): `P = E * c`
  - Impact force (N/m²): `F = ρ * g * H * (c²/2)`

Where:
- D = Displacement [t]
- v = Velocity [m/s]
- L = Length [m]
- B = Beam width [m]
- g = Gravitational acceleration (9.81 m/s²)
- ρ = Water density (1000 kg/m³)
- H = Wave height [m]
- λ = Wave length [m]
- T = Wave period [s]
- c = Wave velocity [m/s]

Additional factors:
- Froude length number: `Fr_L = v / √(g * L)`
- Froude depth number: `Fr_h = v / √(g * h)`
- Reynolds number: `Re = (L * v) / ν`
  - ν = Kinematic viscosity (1.0e-6 m²/s)

The calculations consider:
- Ship length and width
- Displacement
- Speed (18 km/h)
- Water depth (10m default)
- Froude and Reynolds numbers

##### Wave Rating Calculation:

1. **Input Data** for each ship:
   - Technical data from scraper (length, width, displacement)
   - Constant values:
     - Speed: 18 km/h (5 m/s)
     - Water depth: 10m
     - Water density: 1000 kg/m³

2. **Calculation Steps**:
   a) Calculate maximum wave height (H)
   b) Derive wave energy (E) and impact force (F)
   c) Compare with thresholds:
      - Energy: <150 J/m² → 1 wave, 150-250 J/m² → 2 waves, >250 J/m² → 3 waves
      - Force: <45000 N/m² → 1 wave, 45000-55000 N/m² → 2 waves, >55000 N/m² → 3 waves
   d) Final rating is the higher of both values

3. **Example Calculation MS Panta Rhei**:
   - Length: 56.6m, Width: 10.7m, Displacement: 382t
   - Wave height: H = 0.63m
   - Wave energy: E = 488 J/m² → 3 waves
   - Impact force: F = 77347 N/m² → 3 waves
   - Result: 3 waves

4. **Example Calculation MS Bachtel**:
   - Length: 33.3m, Width: 6.3m, Displacement: 64t
   - Wave height: H = 0.31m
   - Wave energy: E = 114 J/m² → 1 wave
   - Impact force: F = 37409 N/m² → 1 wave
   - Result: 1 wave

##### Wave Rating (1-3 waves):
- **Strong waves (3)**: MS Panta Rhei, MS Albis, EMS Uetliberg, EMS Pfannenstiel
  - High wave energy (>250 J/m²)
  - High impact force (>55000 N/m²)
  
- **Medium waves (2)**: MS Wädenswil, MS Limmat, MS Helvetia, MS Linth, DS Stadt Zürich, DS Stadt Rapperswil
  - Medium wave energy (150-250 J/m²)
  - Medium impact force (45000-55000 N/m²)
  
- **Light waves (1)**: MS Bachtel, MS Säntis, and all other ships
  - Low wave energy (<150 J/m²)
  - Low impact force (<45000 N/m²)

Execution: `python3 scripts/vesseldata.py`
Saves data to `schiffsdaten.csv`

#### 2. Vessel API
- **Vercel-based API**: Serverless function for real-time ship deployments
- **Puppeteer Web Scraping**: Uses headless Chrome to handle dynamic AJAX-loaded content
- **Date Picker Automation**: Simulates clicking "Next Day" button to load data for each day
- **3-Day Forecast**: Fetches ship assignments for today and the next 2 days
- **Smart Caching**: Daily cache updates with automatic refresh at midnight (Swiss time)
- **Client-Side Caching**: 24-hour HTTP cache headers for optimal performance
- **Data Structure**: Returns daily deployments with ship-to-course mappings
- **Error Handling**: Graceful fallback if data unavailable for specific days
- **Currently Lake Zurich Only**: ZSG network (station IDs starting with 85036)
- **Endpoint**: `/api/ships`
- **Response Format**:
  ```json
  {
    "dailyDeployments": [
      {
        "date": "2025-10-23",
        "routes": [
          {
            "shipName": "MS Panta Rhei",
            "courseNumber": "1"
          }
        ]
      }
    ],
    "lastUpdated": "2025-10-23T08:00:00.000Z"
  }
  ```
- **Integration**: iOS app queries API and caches results per date and course number
- **Performance**: Minimal API calls through intelligent client-side caching

#### 3. Water Temperature and Water Level API
- **Vercel-based API**: Serverless function for real-time water temperature and water level data
- **Web Scraping**: Automatically scrapes meteonews.ch for Swiss lake data
- **Daily Updates**: Data refreshed once per day at first request
- **Smart Caching**: 24-hour cache to minimize API calls and server load
- **Coverage**: 30+ Swiss lakes including all major lakes
- **Endpoint**: `/api/water-temperature`
- **Response Format**:
  ```json
  {
    "lakes": [
      {
        "name": "Zürichsee",
        "temperature": 14,
        "waterLevel": "405.96 m.ü.M."
      }
    ],
    "lastUpdated": "2025-10-29T08:00:00.000Z",
    "debug": {
      "currentSwissTime": "29.10.2025, 09:00:00",
      "lakesCount": 32
    }
  }
  ```
- **Water Level Processing**: 
  - App calculates difference from historical average levels
  - Displays as "+X cm" or "-X cm" for easy interpretation
  - Reference levels stored in `api/lake-water-levels.json`
  - Helps foilers assess water depth and conditions
- **Integration**: iOS app caches data for 24 hours matching backend update frequency
- **Performance**: Single daily fetch per device, efficient data delivery

# Feature Ideas Welcome

Have an idea for improving Next Wave? We're always open to suggestions from the community! Whether it's new features, usability improvements, or support for additional lakes - we'd love to hear from you. Feel free to open an issue on GitHub to discuss your ideas or contribute directly through a pull request.

Some ideas that have been suggested:
- Link to Foil Mates and vice versa for nearby spots

Note: International support is currently out of scope for this project. Feel free to fork the repository and create a version for your specific country!

## Maintainers

[@pfederi](https://github.com/pfederi).

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
Kanban Board is here: https://github.com/users/pfederi/projects/1

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contact

Join our community: [Pumpfoiling Community](https://pumpfoiling.community)

## Safety Notice

Always maintain a safe distance from boats and follow local water safety regulations. Never surf directly behind vessels.

## Acknowledgments

- Thanks to all beta testers
- Special thanks to Alex for all your good ideas and testing
- Special thanks to Nils Mango for the favorite and nearby station feature requests
- Map data © OpenStreetMap contributors
- Special thanks to the Lake boat operators - We would be delighted if you step on the gas a little more while departing from the dock.
