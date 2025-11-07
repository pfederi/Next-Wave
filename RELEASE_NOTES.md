# NextWave App - Release History

## [Unreleased]

### Added
- **Fastlane Snapshot Integration**: Automated screenshot generation for App Store submissions (development tool)
  - Supports iPhone 17 Pro Max, iPhone 17 Pro, iPhone 16e, and iPad Pro 13-inch (M4)
  - Automated status bar customization (9:41 AM, full battery)
  - Optional device frame generation with Frameit
  - Configuration in `fastlane/Snapfile` and `fastlane/Fastfile`
  - UI Tests extended for screenshot capture at key app screens
  - Commands: `fastlane screenshots`, `fastlane add_frames`, `fastlane generate_all_screenshots`

---

## Version 3.4.4 (November 2025)

### Added
- **Clear Ship Data Cache**: New settings option to manually clear ship deployment data cache
  - Force reload of ship assignments from Vercel API
  - Accessible in Settings > Data Management
  - Helpful for troubleshooting or forcing immediate updates
  - Confirmation dialog to prevent accidental clearing
- **Albis-Class Filter Settings**: New toggle to enable/disable the Albis-Class filter feature
  - Located in Settings > Display Options
  - Enabled by default
  - When enabled, flip device 180° in departure view to filter for best waves on Zürichsee
  - Shows only Albis-Class ships (MS Albis, EMS Uetliberg, EMS Pfannenstiel)
  - Includes helpful description in settings

### Changed
- **Ship Data Display**: Changed "Loading..." to "No data" when ship information is unavailable
  - More accurate representation after background loading completes
- **URLSession Cache**: Improved cache handling for vessel data API
  - Changed cache policy to always fetch fresh data
  - Clear Ship Data Cache now also clears URLSession cache
  - Fixes issue where old ship deployment data was being displayed

---

## Version 3.4.3 (November 2025)

### Improvements
- **Wetsuit thickness**: Updated winter wetsuit recommendation from 6/5/4mm to 6/5mm for better clarity and accuracy

---

## Version 3.4.2 (November 2025)

### Daylight Phase Icons
- **Time-of-day indicators**: New icon system showing current daylight phase for each departure
- **Sun icon**: Displayed during full daylight hours
- **Twilight icon**: Shown during civil twilight (dawn and dusk)
- **Moon icon**: Displayed during nighttime hours
- **Smart positioning**: Icons appear next to departure time for instant recognition
- **Session planning**: Quickly identify which departures occur during optimal daylight conditions
- **Consistent experience**: Icons integrated throughout the app (departure list, favorites, search)

---

## Version 3.4.1 (November 2025)

### Water Level Icon Improvement
- **Dynamic water level icons**: Icons now show direction based on whether water is higher or lower than average
- **Arrow up (↑)**: Displayed when water level is above average (e.g., +15 cm)
- **Arrow down (↓)**: Displayed when water level is below average (e.g., -5 cm)
- **Visual clarity**: Instantly see if water level is high or low without reading the number
- **Consistent across app**: Updated in departure list, favorite stations, and nearest station tiles

---

## Version 3.4 (November 2025)

### Smart Wetsuit Thickness Recommendations
- **Intelligent calculator**: Get personalized wetsuit thickness recommendations based on water temperature and wind chill
- **30°C rule**: If air + water temperature < 30°C, the app recommends one size thicker for optimal comfort
- **Temperature ranges**: From 0.5-2mm shorties to 6/5mm winter wetsuits
- **Wind chill integration**: Uses "feels like" temperature for more accurate recommendations
- **Visual display**: Shows thickness in millimeters (e.g., 3/2mm, 4/3mm) with intuitive icon

### Interactive Weather Legend
- **Tap to learn**: Tap on any weather line to see detailed explanations of all weather data
- **Comprehensive information**: Learn what each weather icon and value means
- **Weather conditions guide**: Understand different weather conditions (clear, cloudy, rainy, etc.)
- **Professional design**: Clean, organized modal with easy-to-read information
- **Always accessible**: Available on every departure with weather data

### Enhanced Weather Display
- **Improved layout**: Weather data now spans full width for better readability
- **Consistent ordering**: Air Temp | Water Temp | Wind | Wetsuit | Water Level
- **Better spacing**: Increased vertical spacing for improved visual hierarchy
- **Clear separators**: Pipe separators (|) between data points for easy scanning
- **Icon consistency**: Each data point has its own descriptive icon
- **Today-only water level**: Water level difference only shown for current day departures

### Share Wave Feature
- **Share with friends**: Share wave details via WhatsApp, Messages, or Mail
- **Fun intro messages**: 5 randomized intro texts like "🥳 Let's share the next wave for a party wave!"
- **Complete information**: Includes station, date, time, route, ship name, and all weather data
- **Weather details**: Air temperature, water temperature, wind, wetsuit recommendation, and water level
- **One-click sharing**: Direct integration with WhatsApp, Messages, and Mail apps
- **Smart formatting**: Proper emoji support and formatting for each platform
- **App promotion**: Includes link to NextWave on App Store
- **Future waves only**: Share button only visible for upcoming departures

---

## Version 3.3.1 (October 2025)

### Bug Fixes
- **Ship names loading**: Fixed issue where ship names weren't loading for all 3 days
- **Scroll behavior**: Improved scroll behavior in departures list
- **Date change handling**: Better handling of date changes and scroll position

---

## Version 3.3 (October 2025)

### Ship Data Loading Optimization
- **Puppeteer-based scraping**: Advanced web scraping using headless Chrome to handle dynamic AJAX content
- **Multi-day data fetching**: Correctly loads ship assignments for today and next 2 days
- **Intelligent caching system**: Three-layer caching strategy (API cache, URLSession cache, in-memory cache)
- **Zero loading flicker**: Ship names appear instantly from cache without "Loading..." indicators
- **Single UI update**: All data (weather + ship names) loaded in background before single smooth UI update
- **Performance**: 24-hour client-side cache eliminates redundant API calls

### Water Level Display
- **Real-time data**: Current water level for all major Swiss lakes
- **Difference from average**: Shows how much the current water level differs from the average (e.g., "+7 cm" or "-5 cm")
- **Meteonews integration**: Water level data sourced from meteonews.ch
- **Daily updates**: Automatic refresh once per day
- **Visual integration**: Displayed with chart icon alongside weather data
- **Foiler-friendly**: Helps foilers assess water conditions and depth

### UI Improvements
- **Prevent UI flicker**: View updates only once with all data loaded
- **Better caching**: Avoid redundant API calls with improved caching strategy
- **Enhanced debugging**: Better error handling and logging

---

## Version 3.0 (September 2025)

### Water Temperature Display
- **Real-time data**: Current water temperature for all major Swiss lakes
- **Meteonews integration**: Data sourced from meteonews.ch
- **Daily updates**: Automatic refresh once per day
- **Smart caching**: 24-hour cache to minimize API calls
- **Visual integration**: Displayed alongside weather data with consistent UI
- **Coverage**: Available for 30+ Swiss lakes

### Best Surf Sessions Analytics
- **Quality-first scoring**: Sessions prioritize large ships (3-wave ships) over quantity
- **Smart scoring system**: 
  - 3-wave ships: 10 points
  - 2-wave ships: 5 points
  - 1-wave ships: 2 points
- **Frequency bonus**: Additional scoring for higher wave frequency
- **Daylight optimization**: 
  - Sessions in complete darkness automatically excluded
  - Twilight sessions receive reduced scores (80% penalty)
  - Best sessions during full daylight hours
- **Session parameters**: 
  - Maximum duration: 2 hours
  - Minimum duration: 1 hour
  - Maximum gap between waves: 1 hour

---

## Version 3.2 (September 2025)

### Widget Enhancements
- **Multi-day logic**: Intelligent widget functionality with better multi-day support
- **Improved UX**: Enhanced user experience for widgets
- **Auto-refresh**: Widgets automatically update departure data when app launches
- **Data synchronization**: Better sync between app, widgets, and watch
- **Settings improvements**: Enhanced widget settings UI

---

## Version 3.1 (September 2025)

### Dependency Updates
- **Security fixes**: Updated dependencies to fix security vulnerabilities
  - path-to-regexp: ^8.0.0 (fixes high severity CVE)
  - undici: ^7.0.0 (fixes moderate severity CVE)
  - esbuild: ^0.24.2
- **Vercel updates**: Updated @vercel/node from 3.2.0 to 4.0.0
- **Build improvements**: Updated vercel from 37.0.0 to 48.0.0

### UI Improvements
- **Enhanced departure view**: Improved ship icon handling and debugging
- **Better error handling**: More robust error handling throughout the app

---

## Version 2.9.1 (August 2025)

### Watch App Improvements
- **Location refresh**: Implement location refresh on app appearance
- **Nearest station detection**: Improved logic for finding nearest station
- **UI updates**: Better reflection of station availability
- **Responsive location**: More responsive distance filter for location updates
- **watchOS compatibility**: Adjusted deployment target to 11.0

---

## Version 2.9 (August 2025)

### Apple Watch App & Widgets
- **Watch app**: Full-featured Apple Watch app with complications and widgets
- **Two usage modes**: Favorite stations OR automatic nearest station
- **Complications**: Support for all watch faces
- **Real-time sync**: WatchConnectivity for data synchronization
- **Widget support**: Home screen and lock screen widgets for both iPhone and Watch
- **Smart fallback**: Automatically falls back to favorites if nearest station has no departures

---

## Version 2.8.5 (July 2025)

### Time Zone Fixes
- **Zurich time zone**: Fixed time zone handling for sunrise and sunset times
- **DST handling**: Proper handling of daylight saving time changes
- **Calendar adjustments**: Enhanced AppDateFormatter with better calendar handling
- **Consistent time display**: All times now properly displayed in Swiss time zone

### Station Updates
- **New stations**: Added additional ferry stations across Swiss lakes
- **Configuration improvements**: Better station data structure
- **Settings UI**: Enhanced settings view layout

---

## Version 2.8.4 (July 2025)

### Date & Time Improvements
- **Improved date handling**: Refactored AppDateFormatter for better date handling
- **Time zone consistency**: All date/time operations now use Zurich time zone
- **Wave time slot formatting**: Enhanced time string formatting

---

## Version 2.8 (July 2025)

### App Rebranding
- **Name change**: Rebranded from "Next Wave" to "NextWave" (one word)
- **Consistent branding**: Updated all references throughout the app
- **Configuration updates**: Updated bundle identifiers and project settings

### Weather Improvements
- **Weather data in favorites**: Added weather information to favorite station tiles
- **API improvements**: Enhanced weather API integration
- **Bug fixes**: Fixed various weather data display issues

---

## Version 2.7.1 (June 2025)

### Bug Fixes & Improvements
- **Date behavior**: Fixed consistent date behavior when selecting stations
- **No waves messages**: Added more variety to "no waves" messages
- **Duplicate messages**: Fixed issue where same message could appear twice
- **Drag & drop**: Improved drag & drop functionality for favorites
- **Edit mode**: Dedicated EditableFavouritesListView with long press gesture

---

## Version 2.7 (June 2025)

### Favorite Stations
- **Up to 5 favorites**: Store up to 5 frequently used stations
- **Drag & drop reordering**: Easily reorder your favorite stations
- **Quick access**: Fast access to your most-used stations
- **Persistent storage**: Favorites saved across app launches

### Nearest Station Feature
- **Auto-detection**: Automatically find the nearest ferry station
- **Location-based**: Uses CoreLocation for precise positioning
- **Toggle option**: Can be enabled/disabled in settings
- **Widget support**: Works with both iPhone and Watch widgets

### iPad Support
- **All orientations**: Support for all device orientations on iPad
- **Optimized layout**: UI optimized for larger screens

---

## Version 2.6 (May 2025)

### Sunrise & Sunset Integration
- **Sun times**: Display sunrise and sunset times for each day
- **Twilight phases**: Show civil twilight begin and end times
- **Daylight duration**: Calculate total daylight hours
- **Visual gradients**: Beautiful gradient visualization of daylight phases
- **Session planning**: Plan your sessions based on available daylight

### Wave Analytics Enhancements
- **Auto-scroll to current time**: Wave timeline automatically scrolls to current time
- **Line chart updates**: Improved wave frequency visualization
- **Better time slots**: Enhanced time slot calculations for wave analysis

---

## Version 2.5 (May 2025)

### Schedule Period Management
- **Automatic detection**: App automatically detects summer and winter schedule periods
- **Smart notifications**: Get notified about upcoming schedule changes
- **30-day advance notice**: Countdown messages appear when schedule transitions are within 31 days
- **Season-specific messages**: Different witty messages for summer, winter, spring, and autumn transitions
- **All Swiss lakes**: Works for all 15+ major Swiss lakes with boat services
- **Schedule footer**: Display countdown messages in departure list footer

---

## Version 2.4 (May 2025)

### Ship Data Display Extension
- **3-day ship forecast**: Extended ship name display from 1 day to 3 days
- **Date format fix**: Corrected date format for ZSG API (DD.MM.YYYY)
- **Better logging**: Added detailed logging for ship data fetching
- **Cache improvements**: Force cache update if less than 3 days of data available

---

## Version 2.3 (May 2025)

### Ship Names & Wave Ratings
- **Real-time ship identification**: Displays actual ship name for each departure on Lake Zurich
- **Wave rating icons**: Visual indicators showing expected wave quality (1-3 waves)
- **Automatic updates**: Ship assignments fetched daily from ZSG
- **Smart caching**: Efficient caching system to minimize API calls
- **Web scraping**: Custom API for scraping ZSG ship deployment data

---

## Version 2.2 (April 2025)

### Map Integration
- **OpenStreetMap**: Detailed water navigation maps
- **Shipping routes**: Overlay showing ferry routes
- **Station clustering**: Better overview with clustered stations
- **Offline caching**: Automatic map caching for offline use
- **Light & dark mode**: Optimized for both themes
- **Location tracking**: Show your position on the map
- **Failsafe**: Fallback to Apple Maps if needed

---

## Version 2.1 (March 2025)

### Notification Improvements
- **Better notification management**: Improved handling of notification lifecycle
- **Notification cleanup**: Notifications properly removed after being played
- **Background notifications**: Enhanced background notification delivery
- **Notification text**: Improved notification text formatting with route direction

### Bug Fixes
- **Timer fixes**: Fixed timer-related bugs
- **Date change at midnight**: Fixed issue where date wasn't updated at midnight
- **Browser link crash**: Fixed crash when swiping back from browser
- **Scroll behavior**: Improved scroll-to-time functionality

---

## Version 2.0 (March 2025)

### Major UI Overhaul
- **Light & Dark Mode**: Full support for both color schemes
- **Device flip gesture**: Flip device 180° to toggle between light and dark mode
- **Modern design**: Clean, intuitive interface with improved navigation
- **Theme switch**: Smooth transitions between themes

### Notifications & Settings
- **Custom notification times**: Choose 3, 5, 10, or 15 minutes before waves
- **Sound settings**: Select from multiple notification sounds
- **Notification management**: Better handling of notification lifecycle
- **Background notifications**: Notifications work even when app is closed

### Safety Features
- **Safety rules modal**: Comprehensive wakethieving safety guidelines
- **First launch display**: Safety rules shown automatically on first app launch
- **Easy access**: Safety rules accessible anytime via orange shield icon
- **Community integration**: Direct link to Swiss Pumpfoilers Code of Conduct

### Weather Integration
- **OpenWeather API**: Real-time weather data for all stations
- **Temperature display**: Current temperature with min/max values
- **Wind information**: Wind speed in knots with direction
- **Pressure trends**: Atmospheric pressure with 6-hour trend tracking
- **Weather icons**: Visual condition indicators with SF Symbols
- **Per-departure weather**: Individual weather data for each departure time

### Performance Improvements
- **Auto-refresh**: Automatic data refresh at optimal intervals
- **Better caching**: Improved caching strategy for faster loading
- **Background loading**: Data loaded in background for smoother experience
- **Error handling**: Enhanced error handling and user feedback

---

## Version 1.0 (February 2025)

### Initial Release
- **Real-time schedules**: Live boat departure times for Swiss lakes
- **Station selection**: Browse and select from all Swiss ferry stations
- **Departure list**: Clear overview of upcoming departures
- **Route information**: Route numbers and destination stations
- **Date navigation**: Browse departures for different days
- **Basic notifications**: Get notified before wave arrivals
- **Swiss lakes coverage**: Support for major Swiss lakes (Zürichsee, Vierwaldstättersee, etc.)

---

## Links

- **Download NextWave**: [App Store](https://apps.apple.com/ch/app/nextwave/id6739363035)
- **GitHub Repository**: [github.com/pfederi/Next-Wave](https://github.com/pfederi/Next-Wave)
- **Community**: [Pumpfoiling Community](https://pumpfoiling.community)
