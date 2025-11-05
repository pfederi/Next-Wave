# Arc42 Architektur-Dokumentation: Next Wave

Version 1.0 | Stand: November 2025

---

## 1. Einführung und Ziele

### 1.1 Aufgabenstellung

Next Wave ist eine iOS-App, die Wake-Surfern und Foilern auf dem Zürichsee und anderen Schweizer Seen hilft, die perfekte Welle zu erwischen. Die App bietet Echtzeit-Schiffsfahrpläne, intelligente Benachrichtigungen und umfassende Wetterinformationen.

### 1.2 Qualitätsziele

| Priorität | Qualitätsziel | Beschreibung |
|-----------|---------------|--------------|
| 1 | Performance | Schnelle Ladezeiten durch intelligentes Caching (< 2s für Abfahrten) |
| 2 | Zuverlässigkeit | Hohe Verfügbarkeit der Fahrplandaten durch Fallback-Mechanismen |
| 3 | Benutzerfreundlichkeit | Intuitive Bedienung mit maximal 2 Klicks zum Ziel |
| 4 | Datenschutz | Keine Datensammlung, alle Daten bleiben auf dem Gerät |
| 5 | Offline-Fähigkeit | Grundfunktionen auch ohne Internetverbindung nutzbar |

### 1.3 Stakeholder

| Rolle | Kontakt | Erwartungshaltung |
|-------|---------|-------------------|
| Wake-Surfer & Foiler | Community | Zuverlässige Wellenvorhersagen, präzise Timing-Informationen |
| Entwickler | @pfederi | Wartbare, erweiterbare Codebasis |
| App Store Nutzer | Öffentlich | Stabile App ohne Crashes, regelmäßige Updates |
| Schifffahrtsgesellschaften | ZSG, etc. | Korrekte Darstellung der Fahrpläne |

---

## 2. Randbedingungen

### 2.1 Technische Randbedingungen

| Randbedingung | Erläuterung |
|---------------|-------------|
| iOS 16+ | Mindestversion für SwiftUI-Features |
| watchOS 9+ | Für Apple Watch Companion App |
| Swift 5.9+ | Programmiersprache |
| Xcode 15+ | Entwicklungsumgebung |
| Vercel | Serverless Functions für Backend-APIs |

### 2.2 Organisatorische Randbedingungen

| Randbedingung | Erläuterung |
|---------------|-------------|
| Open Source | MIT Lizenz, öffentliches GitHub Repository |
| Solo-Entwicklung | Hauptentwickler: Patrick Federi |
| Community-Driven | Feature-Requests aus der Pumpfoiling Community |

### 2.3 Konventionen

- **Code Style**: Swift Standard Library Conventions
- **Branching**: Git Flow (main, develop, feature branches)
- **Dokumentation**: Inline-Kommentare für komplexe Logik
- **Testing**: Manuelle Tests vor jedem Release

---

## 3. Kontextabgrenzung

### 3.1 Fachlicher Kontext

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
│                     Externe Systeme                           │
├──────────────────────────────────────────────────────────────┤
│  • transport.opendata.ch (Fahrplandaten)                     │
│  • OpenWeather API (Wetterdaten)                             │
│  • Sunrise-Sunset.org (Sonnenzeiten)                         │
│  • Custom Vercel API (Schiffszuweisungen)                    │
│  • MeteoNews (Wassertemperatur & Pegelstände)                │
│  • OpenStreetMap (Kartendaten)                               │
└──────────────────────────────────────────────────────────────┘
```

### 3.2 Technischer Kontext

**Eingehende Schnittstellen:**

| Schnittstelle | Technologie | Zweck |
|---------------|-------------|-------|
| transport.opendata.ch | REST API | Echtzeit-Fahrplandaten für Schweizer Fähren |
| OpenWeather API | REST API | Wetter-Forecasts (Temperatur, Wind, Druck) |
| Sunrise-Sunset.org | REST API | Sonnenauf-/untergangszeiten |
| Custom Vercel API | REST API | Schiffszuweisungen für Zürichsee (Web Scraping) |
| MeteoNews API | REST API | Wassertemperatur & Pegelstände |
| OpenStreetMap | Tile Server | Kartendarstellung |

**Ausgehende Schnittstellen:**

| Schnittstelle | Technologie | Zweck |
|---------------|-------------|-------|
| UserNotifications | iOS Framework | Lokale Push-Benachrichtigungen |
| WidgetKit | iOS Framework | Home Screen & Lock Screen Widgets |
| WatchConnectivity | iOS Framework | Datensynchronisation mit Apple Watch |
| CoreLocation | iOS Framework | GPS-Positionsbestimmung |

---

## 4. Lösungsstrategie

### 4.1 Technologieentscheidungen

| Entscheidung | Begründung |
|--------------|------------|
| SwiftUI | Moderne, deklarative UI, plattformübergreifend (iOS/watchOS) |
| Swift Concurrency (async/await) | Nicht-blockierende API-Aufrufe, bessere Performance |
| MVVM-Architektur | Klare Trennung von UI und Business Logic |
| App Groups | Datenaustausch zwischen App, Widgets und Watch |
| Vercel Serverless | Kostengünstige Backend-Lösung für Web Scraping |

### 4.2 Architekturmuster

**MVVM (Model-View-ViewModel)**
- **Models**: Datenstrukturen (Journey, Lake, Station, etc.)
- **Views**: SwiftUI Views (ContentView, DeparturesListView, etc.)
- **ViewModels**: Business Logic (ScheduleViewModel, LakeStationsViewModel, etc.)

**Repository Pattern**
- API-Layer abstrahiert externe Datenquellen
- Caching-Strategien in API-Services implementiert

### 4.3 Qualitätssicherung

- **Caching**: 24h-Cache für Schiffsnamen, Wetter und Wassertemperatur
- **Error Handling**: Graceful Degradation bei API-Fehlern
- **Offline Support**: Gecachte Daten bleiben verfügbar
- **Performance**: Parallele API-Aufrufe mit TaskGroups

---

## 5. Bausteinsicht

### 5.1 Ebene 1: Systemübersicht

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

### 5.2 Ebene 2: iOS App Komponenten

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

### 5.3 Wichtige Komponenten

#### 5.3.1 ScheduleViewModel
**Verantwortlichkeit**: Verwaltung der Abfahrtsdaten und Business Logic

**Schnittstellen**:
- `loadDepartures(for station: Station, date: Date)` - Lädt Abfahrten
- `refreshDepartures()` - Aktualisiert Daten
- `scheduleNotification(for departure: Journey)` - Plant Benachrichtigung

**Abhängigkeiten**: TransportAPI, WeatherAPI, VesselAPI

#### 5.3.2 TransportAPI
**Verantwortlichkeit**: Kommunikation mit transport.opendata.ch

**Schnittstellen**:
- `getStationboard(stationId: String, for date: Date) async throws -> [Journey]`

**Caching**: In-Memory Cache für Abfragen

#### 5.3.3 VesselAPI
**Verantwortlichkeit**: Abruf von Schiffszuweisungen

**Schnittstellen**:
- `getShipName(for courseNumber: String, date: Date) async -> String?`
- `preloadData() async` - Lädt Daten im Voraus

**Caching**: 24h-Cache mit Datum als Schlüssel

#### 5.3.4 SharedDataManager
**Verantwortlichkeit**: Datenaustausch zwischen App, Widgets und Watch

**Schnittstellen**:
- `saveNextDepartures(_ departures: [DepartureInfo])`
- `loadNextDepartures() -> [DepartureInfo]`
- `saveWidgetSettings(_ settings: WidgetSettings)`

**Speicherort**: UserDefaults mit App Group Container

---

## 6. Laufzeitsicht

### 6.1 Szenario: Abfahrten laden

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

### 6.2 Szenario: Widget-Update

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

### 6.3 Szenario: Schiffsnamen laden (mit Caching)

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

## 7. Verteilungssicht

### 7.1 Infrastruktur

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
- Verteilung über Apple App Store
- TestFlight für Beta-Testing
- Xcode Cloud für CI/CD (optional)

**Backend APIs**:
- Vercel für Serverless Functions
- Automatisches Deployment via Git Push
- Edge Caching für Performance

---

## 8. Querschnittliche Konzepte

### 8.1 Caching-Strategie

| Datentyp | Cache-Dauer | Speicherort | Invalidierung |
|----------|-------------|-------------|---------------|
| Abfahrten | In-Memory | ViewModel | Bei Refresh |
| Schiffsnamen | 24h | UserDefaults | Mitternacht |
| Wetterdaten | 6h | In-Memory | Zeitbasiert |
| Wassertemperatur | 24h | UserDefaults | Mitternacht |
| Kartenkacheln | Unbegrenzt | Disk Cache | Manuell |

### 8.2 Error Handling

**Strategie**: Graceful Degradation
- API-Fehler werden geloggt, aber nicht dem User angezeigt
- Fallback auf gecachte Daten
- Leere States mit hilfreichen Nachrichten

**Beispiel**:
```swift
do {
    let journeys = try await TransportAPI().getStationboard(...)
} catch {
    Logger.shared.error("Failed to load departures: \(error)")
    // Fallback auf gecachte Daten oder leere Liste
}
```

### 8.3 Logging

**Logger-Komponente**:
- Zentrale Logging-Klasse für strukturierte Logs
- Log-Level: Debug, Info, Warning, Error
- Ausgabe in Xcode Console
- Keine Logs in Production (nur bei DEBUG Flag)

### 8.4 Datenschutz

**Privacy by Design**:
- Keine Tracking-SDKs
- Keine Analytics
- Standortdaten nur lokal verarbeitet
- Keine Datenübertragung an Dritte (außer APIs)
- Alle Nutzerdaten in App Groups (lokal)

### 8.5 Lokalisierung

**Aktuell**: Nur Englisch
**Geplant**: Deutsch, Französisch, Italienisch

### 8.6 Accessibility

- VoiceOver-Unterstützung
- Dynamic Type für Schriftgrößen
- Kontrastreiche Farben
- Haptic Feedback für wichtige Aktionen

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

