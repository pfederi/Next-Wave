# User Stories and Acceptance Criteria: Next Wave

Version 1.0 | Date: November 2025

---

## Table of Contents

1. [Core Features](#1-core-features)
2. [Station Management](#2-station-management)
3. [Departure Information](#3-departure-information)
4. [Weather & Water Conditions](#4-weather--water-conditions)
5. [Notifications](#5-notifications)
6. [Wave Analytics](#6-wave-analytics)
7. [Apple Watch](#7-apple-watch)
8. [Widgets](#8-widgets)
9. [Map Features](#9-map-features)
10. [Settings & Preferences](#10-settings--preferences)
11. [Safety & Information](#11-safety--information)
12. [Sharing Features](#12-sharing-features)

---

## 1. Core Features

### US-001: View Boat Departures
**As a** user  
**I want to** see upcoming boat departures from my selected station  
**So that** I can plan when to go to the water to catch waves

**Acceptance Criteria:**
- [ ] User can select a station from the list
- [ ] Departures are displayed in chronological order
- [ ] Each departure shows: time, route number, destination, and ship name (if available)
- [ ] Departures are loaded within 2 seconds
- [ ] Past departures are not shown
- [ ] If no departures are available, a friendly "no waves" message is displayed
- [ ] User can refresh the departure list by pulling down

**Priority:** High  
**Story Points:** 5

---

### US-002: Select Different Dates
**As a** user  
**I want to** view departures for different dates  
**So that** I can plan my sessions in advance

**Acceptance Criteria:**
- [ ] User can navigate to previous and next days using arrow buttons
- [ ] Current date is highlighted
- [ ] User can jump back to today with one tap
- [ ] Date is displayed in readable format (e.g., "Mon, Nov 5, 2025")
- [ ] Departures automatically reload when date changes
- [ ] Date selection persists when switching between stations

**Priority:** High  
**Story Points:** 3

---

### US-003: Quick App Launch
**As a** user  
**I want to** have the app load quickly  
**So that** I can check departure times without waiting

**Acceptance Criteria:**
- [ ] App launches in less than 2 seconds on modern devices
- [ ] Cached data is displayed immediately while fresh data loads
- [ ] Loading indicator is shown only when necessary
- [ ] App preloads data for favorite stations in background
- [ ] No unnecessary API calls on app start

**Priority:** High  
**Story Points:** 8

---

## 2. Station Management

### US-004: Add Favorite Stations
**As a** user  
**I want to** save my frequently used stations as favorites  
**So that** I can access them quickly without searching

**Acceptance Criteria:**
- [ ] User can add up to 5 stations as favorites
- [ ] Favorites are displayed on the home screen
- [ ] User can add a favorite by tapping the star icon
- [ ] Favorites persist between app sessions
- [ ] User receives feedback when favorite limit is reached
- [ ] Favorites are synced to Apple Watch

**Priority:** High  
**Story Points:** 5

---

### US-005: Remove Favorite Stations
**As a** user  
**I want to** remove stations from my favorites  
**So that** I can keep my list relevant to my current needs

**Acceptance Criteria:**
- [ ] User can remove a favorite by tapping the filled star icon
- [ ] Confirmation is not required (can be undone by re-adding)
- [ ] Removal is reflected immediately in the UI
- [ ] Removal is synced to Apple Watch
- [ ] Widget updates after favorite removal

**Priority:** Medium  
**Story Points:** 2

---

### US-006: Reorder Favorite Stations
**As a** user  
**I want to** reorder my favorite stations  
**So that** my most frequently used station appears first

**Acceptance Criteria:**
- [ ] User can drag and drop favorites to reorder them
- [ ] First favorite is used for widgets by default
- [ ] Order persists between app sessions
- [ ] Order is synced to Apple Watch
- [ ] Visual feedback during drag operation

**Priority:** Medium  
**Story Points:** 3

---

### US-007: Find Nearest Station
**As a** user  
**I want to** see the station closest to my current location  
**So that** I can quickly find waves near me

**Acceptance Criteria:**
- [ ] App requests location permission on first use
- [ ] Nearest station is calculated from all available ferry stations
- [ ] Distance to nearest station is displayed in kilometers
- [ ] Nearest station card is shown prominently on home screen
- [ ] User can tap to view departures for nearest station
- [ ] Works even if nearest station is not in favorites
- [ ] Location updates when user moves significantly

**Priority:** High  
**Story Points:** 8

---

### US-008: Browse All Stations
**As a** user  
**I want to** browse all available stations by lake  
**So that** I can discover new spots

**Acceptance Criteria:**
- [ ] Stations are grouped by lake
- [ ] Lakes are displayed alphabetically
- [ ] User can expand/collapse lake sections
- [ ] Search functionality filters stations by name
- [ ] Station count is shown for each lake
- [ ] Tapping a station shows its departures

**Priority:** Medium  
**Story Points:** 5

---

## 3. Departure Information

### US-009: View Ship Names
**As a** user  
**I want to** see which ship is operating each departure  
**So that** I can choose departures with ships that create better waves

**Acceptance Criteria:**
- [ ] Ship names are displayed for Lake Zurich departures
- [ ] Ship names are shown within 3 days forecast window
- [ ] Wave quality icons (1-3 waves) are displayed based on ship type
- [ ] Ship names load asynchronously without blocking UI
- [ ] Cached ship names are displayed instantly
- [ ] "Loading..." is not shown if cached data exists
- [ ] Ship data updates once per day

**Priority:** High  
**Story Points:** 8

---

### US-010: Filter by Albis-Class Ships
**As a** user  
**I want to** filter departures to show only Albis-Class ships  
**So that** I can focus on the best wave opportunities

**Acceptance Criteria:**
- [ ] User can activate filter by flipping device 180° in departure view
- [ ] Only Albis-Class ships are shown when filter is active (MS Albis, EMS Uetliberg, EMS Pfannenstiel)
- [ ] Orange banner indicates filter is active
- [ ] User can deactivate filter by flipping device again
- [ ] Haptic feedback confirms activation/deactivation
- [ ] Filter state resets when leaving departure view

**Priority:** Medium  
**Story Points:** 5

---

### US-011: View Next Station
**As a** user  
**I want to** see the next stop after my selected station  
**So that** I know where the ship is heading

**Acceptance Criteria:**
- [ ] Next station is displayed for each departure
- [ ] Direction is shown in departure list
- [ ] If no next station exists, final destination is shown
- [ ] Information is accurate based on route data

**Priority:** Low  
**Story Points:** 2

---

### US-012: View Schedule Period Information
**As a** user  
**I want to** know when schedule changes occur (summer/winter)  
**So that** I can plan accordingly

**Acceptance Criteria:**
- [ ] Countdown message appears 31 days before schedule change
- [ ] Message is personalized based on season transition
- [ ] Different messages for summer, winter, spring, autumn transitions
- [ ] Message includes exact number of days until change
- [ ] Message is fun and engaging (not just informative)
- [ ] Works for all Swiss lakes with seasonal schedules

**Priority:** Low  
**Story Points:** 3

---

## 4. Weather & Water Conditions

### US-013: View Current Weather
**As a** user  
**I want to** see current weather conditions at my station  
**So that** I can decide if conditions are suitable for surfing

**Acceptance Criteria:**
- [ ] Weather icon shows current conditions
- [ ] Air temperature is displayed in Celsius
- [ ] Wind speed is shown in knots with direction (N, NE, E, etc.)
- [ ] Weather data is shown for each departure time
- [ ] Weather updates every 6 hours
- [ ] Weather can be toggled on/off in settings

**Priority:** High  
**Story Points:** 8

---

### US-014: View Water Temperature
**As a** user  
**I want to** see the current water temperature  
**So that** I can choose the right wetsuit

**Acceptance Criteria:**
- [ ] Water temperature is displayed in Celsius
- [ ] Temperature is shown with water drop icon
- [ ] Data is available for all major Swiss lakes (30+)
- [ ] Temperature updates once per day
- [ ] Cached data is used when API is unavailable

**Priority:** High  
**Story Points:** 5

---

### US-015: Get Wetsuit Recommendation
**As a** user  
**I want to** receive wetsuit thickness recommendations  
**So that** I can stay comfortable in the water

**Acceptance Criteria:**
- [ ] Recommendation is based on water temperature and wind chill
- [ ] Thickness is shown in millimeters (e.g., 3/2mm, 4/3mm, 5/4mm)
- [ ] Uses Quiksilver wetsuit thickness table as reference
- [ ] Applies 30°C rule (air + water temp < 30°C = thicker suit)
- [ ] Recommendation updates with weather data
- [ ] Displayed with figure icon for clarity

**Priority:** Medium  
**Story Points:** 5

---

### US-016: View Water Level
**As a** user  
**I want to** see current water level compared to average  
**So that** I can assess depth and conditions

**Acceptance Criteria:**
- [ ] Water level difference is shown in centimeters (e.g., "+7 cm" or "-5 cm")
- [ ] Only shown for current day (not future forecasts)
- [ ] Displayed with chart icon
- [ ] Available for lakes with water level data
- [ ] Updates once per day

**Priority:** Low  
**Story Points:** 3

---

### US-017: View Atmospheric Pressure
**As a** user  
**I want to** see atmospheric pressure and trends  
**So that** I can predict weather changes

**Acceptance Criteria:**
- [ ] Current pressure is shown in hPa
- [ ] Pressure trend is indicated (rising/falling/stable)
- [ ] Trend is calculated over 6-hour window
- [ ] Trend arrows show direction of change

**Priority:** Low  
**Story Points:** 3

---

### US-018: Access Weather Legend
**As a** user  
**I want to** understand what all weather data means  
**So that** I can interpret the information correctly

**Acceptance Criteria:**
- [ ] User can tap weather line to open legend modal
- [ ] Legend explains all weather data points
- [ ] Wetsuit recommendation logic is explained
- [ ] Modal can be dismissed easily
- [ ] Information is clear and concise

**Priority:** Low  
**Story Points:** 2

---

### US-019: Display Night/Darkness Indicator ✅
**As a** user  
**I want to** see an icon when a scheduled departure takes place during darkness  
**So that** I can easily recognize trips that occur at night

**Acceptance Criteria:**
- [x] Night icon (moon) is displayed if departure is before sunrise or after sunset
- [x] No icon is displayed during daylight hours
- [x] Local sunrise/sunset times are calculated based on station location
- [x] Data is fetched from Sunrise-Sunset.org API (already integrated)
- [x] Icon is visually clear but subtle, placed in front of weather data
- [x] Twilight icon (moon with stars) is shown during civil twilight period (dusk/dawn state)
- [x] Icon adapts to light/dark mode (uses .primary color)
- [x] Cached sun times are used when API is unavailable

**Priority:** Medium  
**Story Points:** 3  
**Status:** ✅ Implemented

---

## 5. Notifications

### US-020: Schedule Wave Notifications
**As a** user  
**I want to** receive notifications before waves arrive  
**So that** I don't miss my session

**Acceptance Criteria:**
- [ ] User can set notification time (3, 5, 10, or 15 minutes before)
- [ ] Notification includes station name, time, and route
- [ ] Notification plays custom sound (boat horn, etc.)
- [ ] User can schedule multiple notifications
- [ ] Notifications are local (no server required)
- [ ] Notifications work even when app is closed

**Priority:** High  
**Story Points:** 8

---

### US-021: Manage Notification Permissions
**As a** user  
**I want to** control notification permissions  
**So that** I'm not disturbed when I don't want to be

**Acceptance Criteria:**
- [ ] App requests notification permission on first use
- [ ] User can enable/disable notifications in iOS settings
- [ ] App handles permission denial gracefully
- [ ] User is informed if notifications are disabled
- [ ] Link to settings is provided if needed

**Priority:** Medium  
**Story Points:** 3

---

### US-022: Choose Notification Sound
**As a** user  
**I want to** choose from different notification sounds  
**So that** I can personalize my experience

**Acceptance Criteria:**
- [ ] Multiple sound options available (boat horn, ukulele, beep, etc.)
- [ ] User can preview sounds before selecting
- [ ] Selection persists between app sessions
- [ ] Sound plays at appropriate volume
- [ ] Default sound is boat horn

**Priority:** Low  
**Story Points:** 3

---

## 6. Wave Analytics

### US-022: View Wave Timeline
**As a** user  
**I want to** see a visual timeline of all waves for the day  
**So that** I can plan my entire session

**Acceptance Criteria:**
- [ ] Timeline shows all departures for selected date
- [ ] Each wave is represented with time and ship name
- [ ] Wave quality icons indicate expected wave size
- [ ] Timeline scrolls horizontally
- [ ] Current time is highlighted
- [ ] Daylight hours are visually indicated

**Priority:** Medium  
**Story Points:** 5

---

### US-023: View Best Sessions
**As a** user  
**I want to** see recommended surf sessions  
**So that** I can maximize my time on the water

**Acceptance Criteria:**
- [ ] Top 3 sessions are displayed
- [ ] Sessions prioritize large ships (3-wave ships worth 10 points)
- [ ] Sessions are 1-2 hours long with max 1-hour gaps
- [ ] Sessions in darkness are excluded
- [ ] Twilight sessions receive reduced scores (80% penalty)
- [ ] Each session shows: time range, wave count, and quality score
- [ ] Sessions are sorted by quality (not just quantity)

**Priority:** Medium  
**Story Points:** 8

---

### US-024: View Wave Frequency Analysis
**As a** user  
**I want to** see wave frequency statistics  
**So that** I understand the rhythm of the day

**Acceptance Criteria:**
- [ ] Average time between waves is calculated
- [ ] Total number of waves is shown
- [ ] Wave distribution throughout day is visualized
- [ ] Statistics update when date changes
- [ ] Only includes waves during daylight hours

**Priority:** Low  
**Story Points:** 3

---

### US-025: View Daylight Information
**As a** user  
**I want to** see sunrise, sunset, and twilight times  
**So that** I can plan sessions during daylight

**Acceptance Criteria:**
- [ ] Sunrise and sunset times are displayed
- [ ] Civil twilight begin/end times are shown
- [ ] Total daylight duration is calculated
- [ ] Beautiful gradient visualization shows day progression
- [ ] Information updates based on selected date and location

**Priority:** Medium  
**Story Points:** 5

---

## 7. Apple Watch

### US-026: View Departures on Watch
**As a** user  
**I want to** see upcoming departures on my watch  
**So that** I can check wave times without pulling out my phone

**Acceptance Criteria:**
- [ ] Watch app shows next departures for favorite stations
- [ ] Departure times are clearly readable
- [ ] Route and destination are displayed
- [ ] Data syncs automatically from iPhone
- [ ] Watch app works independently when iPhone is not nearby
- [ ] Complications show next departure time

**Priority:** High  
**Story Points:** 13

---

### US-027: Use Nearest Station on Watch
**As a** user  
**I want to** see departures for my nearest station  
**So that** I can find waves wherever I am

**Acceptance Criteria:**
- [ ] Watch can use nearest station mode (configurable in iPhone app)
- [ ] Location permission is requested on watch
- [ ] Nearest station is calculated on watch
- [ ] Falls back to favorites if nearest station has no departures
- [ ] Clear message if no favorites are set

**Priority:** Medium  
**Story Points:** 8

---

### US-028: Watch Complications
**As a** user  
**I want to** add Next Wave complications to my watch face  
**So that** I can see next departure at a glance

**Acceptance Criteria:**
- [ ] Complications available for all watch faces
- [ ] Circular, rectangular, and inline styles supported
- [ ] Shows next departure time
- [ ] Updates automatically
- [ ] Tapping complication opens watch app

**Priority:** Medium  
**Story Points:** 5

---

## 8. Widgets

### US-029: Add Home Screen Widget
**As a** user  
**I want to** add a widget to my home screen  
**So that** I can see my next departure without opening the app

**Acceptance Criteria:**
- [ ] Widget available in small, medium, large, and extra large sizes
- [ ] Shows station name, departure time, route, and direction
- [ ] Updates automatically throughout the day
- [ ] Tapping widget opens app to that station
- [ ] Visual indicator shows if using nearest station or favorite

**Priority:** High  
**Story Points:** 8

---

### US-030: Add Lock Screen Widget
**As a** user  
**I want to** add a widget to my lock screen  
**So that** I can check wave times instantly

**Acceptance Criteria:**
- [ ] Widget available for lock screen
- [ ] Shows next departure time
- [ ] Updates automatically
- [ ] Readable in both light and dark mode
- [ ] Tapping opens app

**Priority:** Medium  
**Story Points:** 5

---

### US-031: Widget Shows Next 3 Departures
**As a** user  
**I want to** see my next 3 departures in a widget  
**So that** I can plan my timing better

**Acceptance Criteria:**
- [ ] Available in medium and large sizes
- [ ] Shows 3 upcoming departures in compact list
- [ ] Each departure shows time and route
- [ ] Updates automatically
- [ ] Tapping opens app

**Priority:** Medium  
**Story Points:** 5

---

### US-032: Configure Widget Mode
**As a** user  
**I want to** choose between favorite station and nearest station for widgets  
**So that** widgets show the most relevant information

**Acceptance Criteria:**
- [ ] Setting available in app settings
- [ ] "Use nearest station for Widget" toggle
- [ ] Widgets update immediately after changing setting
- [ ] Setting syncs to watch
- [ ] Default is favorite station mode

**Priority:** Medium  
**Story Points:** 3

---

## 9. Map Features

### US-033: View Stations on Map
**As a** user  
**I want to** see all ferry stations on a map  
**So that** I can discover new spots and understand geography

**Acceptance Criteria:**
- [ ] Map shows all available ferry stations
- [ ] Stations are marked with pins
- [ ] OpenStreetMap tiles are used
- [ ] Map works in light and dark mode
- [ ] Stations are clustered when zoomed out
- [ ] Tapping a station shows its name

**Priority:** Medium  
**Story Points:** 8

---

### US-034: View Shipping Routes
**As a** user  
**I want to** see shipping routes on the map  
**So that** I can understand boat paths

**Acceptance Criteria:**
- [ ] Shipping routes are overlaid on map
- [ ] Routes are clearly visible in both themes
- [ ] Routes connect relevant stations
- [ ] Map can be zoomed and panned

**Priority:** Low  
**Story Points:** 5

---

### US-035: View My Location on Map
**As a** user  
**I want to** see my current location on the map  
**So that** I can see how far I am from stations

**Acceptance Criteria:**
- [ ] User location is shown with blue dot
- [ ] Location updates as user moves
- [ ] User can center map on their location with button
- [ ] Works only if location permission is granted
- [ ] Button is disabled if permission denied

**Priority:** Medium  
**Story Points:** 5

---

### US-036: Offline Map Support
**As a** user  
**I want to** use maps even without internet  
**So that** I can navigate at the lake

**Acceptance Criteria:**
- [ ] Map tiles are cached automatically
- [ ] Cached tiles remain available offline
- [ ] Cache size is reasonable (< 50 MB)
- [ ] User can clear cache in settings if needed

**Priority:** Low  
**Story Points:** 5

---

## 10. Settings & Preferences

### US-037: Toggle Light/Dark Mode
**As a** user  
**I want to** switch between light and dark mode  
**So that** I can use the app comfortably in different lighting conditions

**Acceptance Criteria:**
- [ ] User can choose: Light, Dark, or System
- [ ] Setting persists between app sessions
- [ ] All screens adapt to selected theme
- [ ] Smooth transition between modes
- [ ] Device flip gesture also toggles theme (outside departure view)

**Priority:** Medium  
**Story Points:** 5

---

### US-038: Flip Device to Toggle Theme
**As a** user  
**I want to** flip my device to toggle dark mode  
**So that** I can quickly adapt to lighting changes

**Acceptance Criteria:**
- [ ] Flipping device 180° toggles between light and dark mode
- [ ] Works everywhere except departure view (where it activates ship filter)
- [ ] Haptic feedback confirms toggle
- [ ] 3-second cooldown prevents accidental repeated triggers
- [ ] Gesture can be disabled in settings

**Priority:** Low  
**Story Points:** 5

---

### US-039: Toggle Weather Display
**As a** user  
**I want to** hide weather information if I don't need it  
**So that** I can simplify the interface

**Acceptance Criteria:**
- [ ] Toggle available in settings
- [ ] Weather data is hidden throughout app when disabled
- [ ] Setting persists between sessions
- [ ] Default is enabled

**Priority:** Low  
**Story Points:** 2

---

### US-040: Toggle Nearest Station
**As a** user  
**I want to** disable nearest station feature  
**So that** I only see my favorites

**Acceptance Criteria:**
- [ ] Toggle available in settings
- [ ] Nearest station card is hidden when disabled
- [ ] Location permission is not requested when disabled
- [ ] Setting syncs to watch and widgets
- [ ] Default is enabled

**Priority:** Low  
**Story Points:** 2

---

## 11. Safety & Information

### US-041: View Safety Rules on First Launch
**As a** user  
**I want to** see safety rules when I first open the app  
**So that** I understand how to wakethieve safely

**Acceptance Criteria:**
- [ ] Safety modal appears automatically on first launch
- [ ] Modal shows comprehensive safety information
- [ ] Includes 50-meter rule, priority vessels, equipment requirements
- [ ] Link to Swiss Pumpfoilers Code of Conduct
- [ ] User can dismiss modal after reading
- [ ] Modal doesn't appear again after first launch

**Priority:** High  
**Story Points:** 3

---

### US-042: Access Safety Rules Anytime
**As a** user  
**I want to** access safety rules at any time  
**So that** I can refresh my knowledge

**Acceptance Criteria:**
- [ ] Orange shield icon in settings opens safety rules
- [ ] Same content as first launch modal
- [ ] Can be accessed from home screen
- [ ] Easy to dismiss

**Priority:** Medium  
**Story Points:** 1

---

### US-043: View App Information
**As a** user  
**I want to** see app version and developer information  
**So that** I know what version I'm using

**Acceptance Criteria:**
- [ ] Settings show app version number
- [ ] Link to GitHub repository
- [ ] Link to App Store page
- [ ] Link to Pumpfoiling Community
- [ ] Developer contact information

**Priority:** Low  
**Story Points:** 2

---

## 12. Sharing Features

### US-044: Share Wave with Friends
**As a** user  
**I want to** share wave details with friends  
**So that** we can meet up for a session

**Acceptance Criteria:**
- [ ] Share button visible for future departures only
- [ ] Share includes: station, date, time, route, ship name
- [ ] Share includes weather data: air temp, water temp, wind, wetsuit recommendation
- [ ] Randomized fun intro messages (5 variations)
- [ ] Direct integration with WhatsApp, Messages, and Mail
- [ ] Includes link to Next Wave on App Store
- [ ] Different formatting for each platform (emojis, line breaks)

**Priority:** Medium  
**Story Points:** 5

---

### US-045: Share via WhatsApp
**As a** user  
**I want to** share directly to WhatsApp  
**So that** I can quickly invite my friends

**Acceptance Criteria:**
- [ ] WhatsApp button opens WhatsApp with pre-filled message
- [ ] Works if WhatsApp is installed
- [ ] Graceful handling if WhatsApp is not installed
- [ ] Message includes all wave details

**Priority:** Medium  
**Story Points:** 2

---

### US-046: Share via Messages
**As a** user  
**I want to** share via iMessage  
**So that** I can reach friends who don't use WhatsApp

**Acceptance Criteria:**
- [ ] Messages button opens native message composer
- [ ] Full text support with emojis
- [ ] User can select recipients
- [ ] Message includes all wave details

**Priority:** Medium  
**Story Points:** 2

---

### US-047: Share via Mail
**As a** user  
**I want to** share via email  
**So that** I can send details to anyone

**Acceptance Criteria:**
- [ ] Mail button opens mail composer
- [ ] Subject line is pre-filled
- [ ] Body includes all wave details
- [ ] Full emoji support
- [ ] Proper URL encoding

**Priority:** Low  
**Story Points:** 2

---

## Epic Summary

### Epic 1: Core Departure Viewing (US-001 to US-003)
**Total Story Points:** 16  
**Priority:** Critical  
**Description:** Basic functionality to view and navigate boat departures

### Epic 2: Station Management (US-004 to US-008)
**Total Story Points:** 23  
**Priority:** High  
**Description:** Favorite stations, nearest station, and station browsing

### Epic 3: Enhanced Departure Info (US-009 to US-012)
**Total Story Points:** 18  
**Priority:** High  
**Description:** Ship names, filtering, and schedule information

### Epic 4: Weather & Conditions (US-013 to US-018)
**Total Story Points:** 26  
**Priority:** High  
**Description:** Weather, water temperature, wetsuit recommendations

### Epic 5: Notifications (US-019 to US-021)
**Total Story Points:** 14  
**Priority:** High  
**Description:** Wave notifications and sound customization

### Epic 6: Analytics (US-022 to US-025)
**Total Story Points:** 21  
**Priority:** Medium  
**Description:** Wave timeline, best sessions, and daylight info

### Epic 7: Apple Watch (US-026 to US-028)
**Total Story Points:** 26  
**Priority:** High  
**Description:** Full Apple Watch companion app

### Epic 8: Widgets (US-029 to US-032)
**Total Story Points:** 21  
**Priority:** High  
**Description:** Home screen and lock screen widgets

### Epic 9: Maps (US-033 to US-036)
**Total Story Points:** 23  
**Priority:** Medium  
**Description:** Interactive map with stations and routes

### Epic 10: Settings (US-037 to US-040)
**Total Story Points:** 14  
**Priority:** Medium  
**Description:** User preferences and customization

### Epic 11: Safety (US-041 to US-043)
**Total Story Points:** 6  
**Priority:** High  
**Description:** Safety information and app info

### Epic 12: Sharing (US-044 to US-047)
**Total Story Points:** 11  
**Priority:** Medium  
**Description:** Share wave details with friends

---

## Total Project Metrics

- **Total User Stories:** 47
- **Total Story Points:** 219
- **Estimated Development Time:** 44 weeks (assuming 5 points per week)
- **High Priority Stories:** 23
- **Medium Priority Stories:** 18
- **Low Priority Stories:** 6

---

## Release Planning

### Release 1.0 (MVP) - Core Features
**Stories:** US-001, US-002, US-003, US-004, US-005, US-007, US-013, US-014, US-019, US-041  
**Story Points:** 51  
**Features:** Basic departure viewing, favorites, nearest station, weather, notifications, safety

### Release 2.0 - Enhanced Experience
**Stories:** US-009, US-010, US-022, US-023, US-029, US-030, US-033, US-037  
**Story Points:** 49  
**Features:** Ship names, filtering, analytics, widgets, maps, themes

### Release 3.0 - Apple Watch & Advanced Features
**Stories:** US-026, US-027, US-028, US-015, US-016, US-024, US-025, US-044  
**Story Points:** 47  
**Features:** Full watch app, wetsuit recommendations, water levels, sharing

### Release 4.0 - Polish & Optimization
**Stories:** All remaining stories  
**Story Points:** 72  
**Features:** Complete feature set, refinements, optimizations

---

## Definition of Done

A user story is considered "Done" when:

1. **Development Complete**
   - All acceptance criteria are met
   - Code is written and reviewed
   - No critical bugs remain

2. **Testing Complete**
   - Manual testing performed on physical devices
   - Edge cases tested
   - Performance requirements met

3. **Documentation Updated**
   - Code comments added where necessary
   - README updated if needed
   - API documentation updated

4. **Review & Approval**
   - Code review completed
   - UX review completed
   - Product owner approval

5. **Deployment Ready**
   - Changes merged to main branch
   - TestFlight build available
   - Release notes prepared

---

## Prioritization Framework

### High Priority (Must Have)
- Core functionality required for app to be useful
- Features users expect in an MVP
- Safety-critical features

### Medium Priority (Should Have)
- Features that significantly enhance user experience
- Nice-to-have features that differentiate the app
- Features requested by community

### Low Priority (Could Have)
- Polish and refinement features
- Advanced features for power users
- Features that can be added later

---

**Document Version:** 1.0  
**Last Updated:** November 2025  
**Author:** Patrick Federi  
**Status:** Living Document

