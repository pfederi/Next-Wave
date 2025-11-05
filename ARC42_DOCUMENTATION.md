# Arc42 Architecture Documentation: Next Wave

Version 1.0 | Date: November 2025

---

## 1. Introduction and Goals

### 1.1 Requirements Overview

Next Wave is an iOS app that helps wake surfers and foilers on Lake Zurich and other Swiss lakes catch their perfect wave. The app provides real-time boat schedules, smart notifications, and comprehensive weather information.

### 1.2 Quality Goals

| Priority | Quality Goal | Description |
|----------|--------------|-------------|
| 1 | Performance | Fast loading times through intelligent caching (< 2s for departures) |
| 2 | Reliability | High availability of schedule data through fallback mechanisms |
| 3 | Usability | Intuitive navigation with maximum 2 clicks to goal |
| 4 | Privacy | No data collection, all data stays on device |
| 5 | Offline Capability | Core functions available without internet connection |

### 1.3 Stakeholders

| Role | Contact | Expectations |
|------|---------|--------------|
| Wake Surfers & Foilers | Community | Reliable wave predictions, precise timing information |
| Developer | @pfederi | Maintainable, extensible codebase |
| App Store Users | Public | Stable app without crashes, regular updates |
| Shipping Companies | ZSG, etc. | Correct representation of schedules |

---

## 2. Architecture Constraints

### 2.1 Technical Constraints

| Constraint | Explanation |
|------------|-------------|
| iOS 16+ | Minimum version for SwiftUI features |
| watchOS 9+ | For Apple Watch companion app |
| Swift 5.9+ | Programming language |
| Xcode 15+ | Development environment |
| Vercel | Serverless functions for backend APIs |

### 2.2 Organizational Constraints

| Constraint | Explanation |
|------------|-------------|
| Open Source | MIT License, public GitHub repository |
| Solo Development | Main developer: Patrick Federi |
| Community-Driven | Feature requests from Pumpfoiling Community |

### 2.3 Conventions

- **Code Style**: Swift Standard Library Conventions
- **Branching**: Git Flow (main, develop, feature branches)
- **Documentation**: Inline comments for complex logic
- **Testing**: Manual testing before each release

---

## 3. Context and Scope

### 3.1 Business Context

```
┌─────────────────────────────────────────────────────────────┐
│                         Next Wave App                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   iOS App    │  │  Watch App   │  │   Widgets    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
           │                    │                    │
           ▼                    ▼                    ▼
┌──────────────────────────────────────────────────────────────┐
│                     External Systems                          │
├──────────────────────────────────────────────────────────────┤
│  • transport.opendata.ch (Schedule data)                     │
│  • OpenWeather API (Weather data)                            │
│  • Sunrise-Sunset.org (Sun times)                            │
│  • Custom Vercel API (Ship assignments)                      │
│  • MeteoNews (Water temperature & levels)                    │
│  • OpenStreetMap (Map data)                                  │
└──────────────────────────────────────────────────────────────┘
```

### 3.2 Technical Context

**Incoming Interfaces:**

| Interface | Technology | Purpose |
|-----------|------------|---------|
| transport.opendata.ch | REST API | Real-time schedule data for Swiss ferries |
| OpenWeather API | REST API | Weather forecasts (temperature, wind, pressure) |
| Sunrise-Sunset.org | REST API | Sunrise/sunset times |
| Custom Vercel API | REST API | Ship assignments for Lake Zurich (web scraping) |
| MeteoNews API | REST API | Water temperature & water levels |
| OpenStreetMap | Tile Server | Map rendering |

**Outgoing Interfaces:**

| Interface | Technology | Purpose |
|-----------|------------|---------|
| UserNotifications | iOS Framework | Local push notifications |
| WidgetKit | iOS Framework | Home screen & lock screen widgets |
| WatchConnectivity | iOS Framework | Data synchronization with Apple Watch |
| CoreLocation | iOS Framework | GPS positioning |

---

## 4. Solution Strategy

### 4.1 Technology Decisions

| Decision | Rationale |
|----------|-----------|
| SwiftUI | Modern, declarative UI, cross-platform (iOS/watchOS) |
| Swift Concurrency (async/await) | Non-blocking API calls, better performance |
| MVVM Architecture | Clear separation of UI and business logic |
| App Groups | Data sharing between app, widgets, and watch |
| Vercel Serverless | Cost-effective backend solution for web scraping |

### 4.2 Architecture Patterns

**MVVM (Model-View-ViewModel)**
- **Models**: Data structures (Journey, Lake, Station, etc.)
- **Views**: SwiftUI Views (ContentView, DeparturesListView, etc.)
- **ViewModels**: Business logic (ScheduleViewModel, LakeStationsViewModel, etc.)

**Repository Pattern**
- API layer abstracts external data sources
- Caching strategies implemented in API services

### 4.3 Quality Assurance

- **Caching**: 24h cache for ship names, weather, and water temperature
- **Error Handling**: Graceful degradation on API failures
- **Offline Support**: Cached data remains available
- **Performance**: Parallel API calls with TaskGroups

---

## 5. Building Block View

### 5.1 Level 1: System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Next Wave System                        │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │              │  │              │  │              │      │
│  │   iOS App    │◄─┤  Watch App   │  │   Widgets    │      │
│  │              │  │              │  │              │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                 │                 │              │
│         └─────────────────┴─────────────────┘              │
│                           │                                │
│                  ┌────────▼────────┐                       │
│                  │                 │                       │
│                  │  Shared Data    │                       │
│                  │  (App Groups)   │                       │
│                  │                 │                       │
│                  └─────────────────┘                       │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Level 2: iOS App Components

```
┌─────────────────────────────────────────────────────────────┐
│                         iOS App                              │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                    Views Layer                        │   │
│  │  • ContentView                                        │   │
│  │  • DeparturesListView                                 │   │
│  │  • LocationPickerView                                 │   │
│  │  • SettingsView                                       │   │
│  │  • WaveAnalyticsView                                  │   │
│  └──────────────────┬───────────────────────────────────┘   │
│                     │                                        │
│  ┌──────────────────▼───────────────────────────────────┐   │
│  │                ViewModels Layer                       │   │
│  │  • ScheduleViewModel                                  │   │
│  │  • LakeStationsViewModel                              │   │
│  │  • WaveAnalyticsViewModel                             │   │
│  │  • AppSettings                                        │   │
│  └──────────────────┬───────────────────────────────────┘   │
│                     │                                        │
│  ┌──────────────────▼───────────────────────────────────┐   │
│  │                   API Layer                           │   │
│  │  • TransportAPI (Fahrplandaten)                       │   │
│  │  • WeatherAPI (Wetterdaten)                           │   │
│  │  • VesselAPI (Schiffsnamen)                           │   │
│  │  • WaterTemperatureAPI (Wassertemperatur)             │   │
│  └──────────────────┬───────────────────────────────────┘   │
│                     │                                        │
│  ┌──────────────────▼───────────────────────────────────┐   │
│  │                  Models Layer                         │   │
│  │  • Journey, Lake, Station                             │   │
│  │  • DepartureInfo, FavoriteStation                     │   │
│  │  • WaveAnalytics, SunTimes                            │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### 5.3 Key Components

#### 5.3.1 ScheduleViewModel
**Responsibility**: Management of departure data and business logic

**Interfaces**:
- `loadDepartures(for station: Station, date: Date)` - Loads departures
- `refreshDepartures()` - Refreshes data
- `scheduleNotification(for departure: Journey)` - Schedules notification

**Dependencies**: TransportAPI, WeatherAPI, VesselAPI

#### 5.3.2 TransportAPI
**Responsibility**: Communication with transport.opendata.ch

**Interfaces**:
- `getStationboard(stationId: String, for date: Date) async throws -> [Journey]`

**Caching**: In-memory cache for queries

#### 5.3.3 VesselAPI
**Responsibility**: Fetching ship assignments

**Interfaces**:
- `getShipName(for courseNumber: String, date: Date) async -> String?`
- `preloadData() async` - Preloads data

**Caching**: 24h cache with date as key

#### 5.3.4 SharedDataManager
**Responsibility**: Data exchange between app, widgets, and watch

**Interfaces**:
- `saveNextDepartures(_ departures: [DepartureInfo])`
- `loadNextDepartures() -> [DepartureInfo]`
- `saveWidgetSettings(_ settings: WidgetSettings)`

**Storage**: UserDefaults with App Group container

---

## 6. Runtime View

### 6.1 Scenario: Loading Departures

```
┌──────┐         ┌──────────────┐         ┌──────────────┐         ┌─────────────┐
│ User │         │ ContentView  │         │ViewModel     │         │ TransportAPI│
└──┬───┘         └──────┬───────┘         └──────┬───────┘         └──────┬──────┘
   │                    │                        │                        │
   │ Select Station     │                        │                        │
   ├───────────────────►│                        │                        │
   │                    │                        │                        │
   │                    │ loadDepartures()       │                        │
   │                    ├───────────────────────►│                        │
   │                    │                        │                        │
   │                    │                        │ getStationboard()      │
   │                    │                        ├───────────────────────►│
   │                    │                        │                        │
   │                    │                        │                        │ HTTP GET
   │                    │                        │                        ├─────────►
   │                    │                        │                        │
   │                    │                        │      [Journey]         │
   │                    │                        │◄───────────────────────┤
   │                    │                        │                        │
   │                    │      [Journey]         │                        │
   │                    │◄───────────────────────┤                        │
   │                    │                        │                        │
   │  Display Departures│                        │                        │
   │◄───────────────────┤                        │                        │
   │                    │                        │                        │
```

### 6.2 Scenario: Widget Update

```
┌─────────┐         ┌──────────────┐         ┌─────────────────┐
│ Widget  │         │ SharedData   │         │ iOS App         │
│         │         │ Manager      │         │                 │
└────┬────┘         └──────┬───────┘         └────────┬────────┘
     │                     │                          │
     │ Timeline Request    │                          │
     ├────────────────────►│                          │
     │                     │                          │
     │                     │ loadNextDepartures()     │
     │                     ├─────────────────────────►│
     │                     │                          │
     │                     │                          │ Load from
     │                     │                          │ App Groups
     │                     │                          │
     │                     │   [DepartureInfo]        │
     │                     │◄─────────────────────────┤
     │                     │                          │
     │  [DepartureInfo]    │                          │
     │◄────────────────────┤                          │
     │                     │                          │
     │ Display Widget      │                          │
     │                     │                          │
```

### 6.3 Scenario: Loading Ship Names (with Caching)

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ViewModel     │    │ VesselAPI    │    │ Cache        │    │ Vercel API   │
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘    └──────┬───────┘
       │                   │                   │                   │
       │ getShipName()     │                   │                   │
       ├──────────────────►│                   │                   │
       │                   │                   │                   │
       │                   │ Check Cache       │                   │
       │                   ├──────────────────►│                   │
       │                   │                   │                   │
       │                   │  Cache Hit?       │                   │
       │                   │◄──────────────────┤                   │
       │                   │                   │                   │
       │                   │                   │                   │
       │                   │ [If Miss] HTTP GET│                   │
       │                   ├───────────────────┴──────────────────►│
       │                   │                                       │
       │                   │              Ship Name                │
       │                   │◄──────────────────────────────────────┤
       │                   │                                       │
       │                   │ Store in Cache    │                   │
       │                   ├──────────────────►│                   │
       │                   │                   │                   │
       │  Ship Name        │                   │                   │
       │◄──────────────────┤                   │                   │
       │                   │                   │                   │
```

---

## 7. Deployment View

### 7.1 Infrastructure

```
┌─────────────────────────────────────────────────────────────┐
│                        User Devices                          │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   iPhone     │  │  Apple Watch │  │  iPad        │      │
│  │              │  │              │  │              │      │
│  │  iOS 16+     │  │  watchOS 9+  │  │  iOS 16+     │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                 │                 │              │
└─────────┼─────────────────┼─────────────────┼──────────────┘
          │                 │                 │
          └─────────────────┴─────────────────┘
                            │
                            │ HTTPS
                            │
          ┌─────────────────▼─────────────────┐
          │                                   │
          │        Internet / Cloud           │
          │                                   │
          └─────────────────┬─────────────────┘
                            │
          ┌─────────────────┴─────────────────┐
          │                                   │
          │                                   │
┌─────────▼──────────┐            ┌───────────▼──────────┐
│                    │            │                      │
│  Vercel Serverless │            │  External APIs       │
│  Functions         │            │                      │
│                    │            │  • transport.opendata│
│  • /api/ships      │            │  • OpenWeather       │
│  • /api/water-temp │            │  • Sunrise-Sunset    │
│                    │            │  • MeteoNews         │
│  Node.js Runtime   │            │  • OpenStreetMap     │
│  Puppeteer         │            │                      │
│                    │            │                      │
└────────────────────┘            └──────────────────────┘
```

### 7.2 Deployment

**iOS App**:
- Distribution via Apple App Store
- TestFlight for beta testing
- Xcode Cloud for CI/CD (optional)

**Backend APIs**:
- Vercel for serverless functions
- Automatic deployment via Git push
- Edge caching for performance

---

## 8. Cross-Cutting Concepts

### 8.1 Caching Strategy

| Data Type | Cache Duration | Storage Location | Invalidation |
|-----------|----------------|------------------|--------------|
| Departures | In-Memory | ViewModel | On refresh |
| Ship Names | 24h | UserDefaults | Midnight |
| Weather Data | 6h | In-Memory | Time-based |
| Water Temperature | 24h | UserDefaults | Midnight |
| Map Tiles | Unlimited | Disk Cache | Manual |

### 8.2 Error Handling

**Strategy**: Graceful Degradation
- API errors are logged but not shown to user
- Fallback to cached data
- Empty states with helpful messages

**Example**:
```swift
do {
    let journeys = try await TransportAPI().getStationboard(...)
} catch {
    Logger.shared.error("Failed to load departures: \(error)")
    // Fallback to cached data or empty list
}
```

### 8.3 Logging

**Logger Component**:
- Central logging class for structured logs
- Log levels: Debug, Info, Warning, Error
- Output to Xcode console
- No logs in production (DEBUG flag only)

### 8.4 Privacy

**Privacy by Design**:
- No tracking SDKs
- No analytics
- Location data processed locally only
- No data transmission to third parties (except APIs)
- All user data in App Groups (local)

### 8.5 Localization

**Current**: English only
**Planned**: German, French, Italian

### 8.6 Accessibility

- VoiceOver support
- Dynamic Type for font sizes
- High-contrast colors
- Haptic feedback for important actions

---

## 9. Architekturentscheidungen

### 9.1 ADR-001: MVVM statt MVC

**Status**: Akzeptiert

**Kontext**: SwiftUI bevorzugt reaktive Programmierung

**Entscheidung**: MVVM mit @Published Properties und Combine

**Begründung**:
- Bessere Testbarkeit
- Klare Trennung von UI und Logic
- SwiftUI-native Datenbindung

**Konsequenzen**:
- Mehr Boilerplate Code
- Steilere Lernkurve für neue Entwickler

### 9.2 ADR-002: Vercel für Backend statt eigener Server

**Status**: Akzeptiert

**Kontext**: Web Scraping für Schiffszuweisungen notwendig

**Entscheidung**: Vercel Serverless Functions mit Puppeteer

**Begründung**:
- Kostenlos für kleine Projekte
- Automatisches Scaling
- Einfaches Deployment
- Integriertes Caching

**Konsequenzen**:
- Vendor Lock-in
- Cold Start Latency
- Begrenzte Ausführungszeit (10s)

### 9.3 ADR-003: App Groups für Datenaustausch

**Status**: Akzeptiert

**Kontext**: Widgets und Watch App benötigen Zugriff auf Abfahrtsdaten

**Entscheidung**: Shared UserDefaults via App Groups

**Begründung**:
- Native iOS-Lösung
- Einfache API
- Keine zusätzlichen Dependencies

**Konsequenzen**:
- Datengröße begrenzt (wenige MB)
- Keine Echtzeit-Synchronisation
- Manuelle Serialisierung notwendig

### 9.4 ADR-004: 24h-Cache für externe Daten

**Status**: Akzeptiert

**Kontext**: API-Limits und Performance-Optimierung

**Entscheidung**: Aggressive Caching-Strategie mit 24h Gültigkeit

**Begründung**:
- Reduziert API-Calls um 95%
- Verbessert App-Startzeit
- Offline-Fähigkeit

**Konsequenzen**:
- Daten können bis zu 24h alt sein
- Komplexere Cache-Invalidierung
- Höherer Speicherbedarf

---

## 10. Qualitätsanforderungen

### 10.1 Qualitätsbaum

```
Qualität
├── Performance
│   ├── App-Start < 2s
│   ├── Abfragen laden < 1s
│   └── Widget-Update < 500ms
├── Zuverlässigkeit
│   ├── Verfügbarkeit > 99%
│   ├── Fehlertoleranz (Graceful Degradation)
│   └── Datenintegrität
├── Benutzerfreundlichkeit
│   ├── Intuitive Navigation
│   ├── Klare Fehlermeldungen
│   └── Accessibility
├── Wartbarkeit
│   ├── Modulare Architektur
│   ├── Code-Dokumentation
│   └── Testbarkeit
└── Sicherheit
    ├── Datenschutz (keine Tracking)
    ├── HTTPS für alle APIs
    └── Sichere Datenspeicherung
```

### 10.2 Qualitätsszenarien

| ID | Szenario | Qualitätsmerkmal | Priorität |
|----|----------|------------------|-----------|
| QS-1 | User öffnet App → Abfahrten werden in < 1s angezeigt | Performance | Hoch |
| QS-2 | API nicht erreichbar → App zeigt gecachte Daten | Zuverlässigkeit | Hoch |
| QS-3 | User aktiviert VoiceOver → Alle Elemente sind lesbar | Accessibility | Mittel |
| QS-4 | Entwickler fügt neuen See hinzu → < 30min Aufwand | Wartbarkeit | Mittel |
| QS-5 | User dreht Gerät → Theme wechselt sofort | Benutzerfreundlichkeit | Niedrig |

---

## 11. Risiken und technische Schulden

### 11.1 Risiken

| ID | Risiko | Wahrscheinlichkeit | Auswirkung | Maßnahme |
|----|--------|-------------------|------------|----------|
| R-1 | transport.opendata.ch API ändert sich | Mittel | Hoch | Monitoring, Fallback-Logik |
| R-2 | ZSG ändert Website-Struktur | Hoch | Mittel | Flexibles Scraping, Fehlerbehandlung |
| R-3 | Apple ändert WidgetKit API | Niedrig | Hoch | Regelmäßige Updates, Beta-Testing |
| R-4 | Vercel Free Tier Limits | Niedrig | Mittel | Monitoring, Upgrade-Plan |
| R-5 | Schlechte Performance bei vielen Favoriten | Mittel | Niedrig | Pagination, Lazy Loading |

### 11.2 Technische Schulden

| ID | Beschreibung | Priorität | Aufwand |
|----|--------------|-----------|---------|
| TD-1 | Fehlende Unit Tests für ViewModels | Hoch | 2 Wochen |
| TD-2 | Keine Lokalisierung (nur Englisch) | Mittel | 1 Woche |
| TD-3 | Hardcodierte Schiffsbewertungen | Niedrig | 2 Tage |
| TD-4 | Keine CI/CD Pipeline | Mittel | 3 Tage |
| TD-5 | Veraltete Dependencies | Niedrig | 1 Tag |

---

## 12. Glossar

| Begriff | Definition |
|---------|------------|
| Wakethieving | Sport, bei dem man auf den Wellen hinter Schiffen surft |
| Foiling | Surfen auf einem Hydrofoil-Board |
| ZSG | Zürichsee-Schifffahrtsgesellschaft |
| Albis-Class | Große Schiffe, die besonders gute Wellen erzeugen |
| UIC-Ref | Eindeutige Stationskennung im Schweizer Transportsystem |
| Stationboard | Fahrplan-Anzeigetafel mit Abfahrten |
| Wave Rating | Bewertung der Wellenqualität (1-3 Wellen) |
| Session | Surf-Session mit mehreren Wellen |
| Nearest Station | Nächstgelegene Schiffsstation basierend auf GPS |
| Widget Timeline | Zeitplan für Widget-Updates |
| App Groups | iOS-Mechanismus für Datenaustausch zwischen Apps |
| Serverless Function | Cloud-Funktion ohne eigenen Server (Vercel) |
| Puppeteer | Headless Browser für Web Scraping |
| Graceful Degradation | Fehlertolerantes Verhalten mit reduzierter Funktionalität |

---

## Anhang

### A.1 Verwendete Frameworks und Libraries

**iOS/Swift**:
- SwiftUI (UI Framework)
- Combine (Reactive Programming)
- CoreLocation (GPS)
- CoreMotion (Gerätebewegung)
- MapKit (Karten)
- WidgetKit (Widgets)
- WatchConnectivity (Watch-Sync)
- UserNotifications (Benachrichtigungen)

**Backend (Node.js)**:
- @vercel/node (Serverless Runtime)
- puppeteer-core (Web Scraping)
- @sparticuz/chromium (Headless Browser)
- cheerio (HTML Parsing)
- axios (HTTP Client)

### A.2 Externe APIs

| API | Zweck | Dokumentation |
|-----|-------|---------------|
| transport.opendata.ch | Fahrplandaten | https://transport.opendata.ch |
| OpenWeather | Wetterdaten | https://openweathermap.org/api |
| Sunrise-Sunset.org | Sonnenzeiten | https://sunrise-sunset.org/api |
| MeteoNews | Wassertemperatur | https://meteonews.ch |
| OpenStreetMap | Kartendaten | https://www.openstreetmap.org |

### A.3 Projektstruktur

```
Next Wave/
├── Next Wave/                    # iOS App
│   ├── API/                      # API Layer
│   ├── Models/                   # Datenmodelle
│   ├── ViewModels/               # Business Logic
│   ├── Views/                    # SwiftUI Views
│   ├── Utilities/                # Helper-Klassen
│   └── Data/                     # Statische Daten (JSON)
├── Next Wave Watch Watch App/    # watchOS App
├── NextWaveWidget/               # iOS Widgets
├── NextWaveWatchWidgetExtension/ # watchOS Widgets
├── api/                          # Vercel Serverless Functions
│   ├── ships.ts                  # Schiffszuweisungen
│   └── water-temperature.ts      # Wassertemperatur
├── scripts/                      # Python Scripts
└── Shared/                       # Gemeinsame Daten
```

### A.4 Deployment-Prozess

**iOS App**:
1. Code-Änderungen in Feature-Branch
2. Pull Request + Code Review
3. Merge in `develop`
4. Testing auf TestFlight
5. Release in `main` Branch
6. App Store Submission

**Backend APIs**:
1. Code-Änderungen in Git
2. Push zu GitHub
3. Automatisches Deployment via Vercel
4. Edge Caching aktiviert

### A.5 Kontakt und Ressourcen

- **GitHub**: https://github.com/pfederi/Next-Wave
- **App Store**: https://apps.apple.com/ch/app/next-wave/id6739363035
- **Community**: https://pumpfoiling.community
- **Maintainer**: @pfederi (Patrick Federi)

---

**Dokumentversion**: 1.0  
**Letzte Aktualisierung**: November 2025  
**Autor**: Patrick Federi  
**Status**: Living Document

