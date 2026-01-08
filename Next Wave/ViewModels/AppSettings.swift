import SwiftUI
import WidgetKit
import Foundation

extension UserDefaults {
    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        if object(forKey: key) == nil {
            return defaultValue
        }
        return bool(forKey: key)
    }
}

class AppSettings: ObservableObject {
    enum Theme: String, Codable {
        case light, dark, system
    }
    
    @Published var theme: Theme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "theme")
        }
    }
    
    @Published var lastLocationPickerMode: LocationPickerMode {
        didSet {
            UserDefaults.standard.set(lastLocationPickerMode.rawValue, forKey: "lastLocationPickerMode")
        }
    }
    
    @Published var lastMapRegion: MapRegion {
        didSet {
            UserDefaults.standard.set(try? JSONEncoder().encode(lastMapRegion), forKey: "lastMapRegion")
        }
    }
    
    @Published var showNearestStation: Bool {
        didSet {
            UserDefaults.standard.set(showNearestStation, forKey: "showNearestStation")
        }
    }
    
    @Published var showWeatherInfo: Bool {
        didSet {
            UserDefaults.standard.set(showWeatherInfo, forKey: "showWeatherInfo")
        }
    }
    
    @Published var enableAlbisClassFilter: Bool {
        didSet {
            UserDefaults.standard.set(enableAlbisClassFilter, forKey: "enableAlbisClassFilter")
        }
    }
    
    @Published var useNearestStationForWidget: Bool {
        didSet {
            UserDefaults.standard.set(useNearestStationForWidget, forKey: "useNearestStationForWidget")
            // Update the shared data for Watch/Widget when this changes
            SharedDataManager.shared.saveWidgetSettings(useNearestStation: useNearestStationForWidget)
            // Send to Watch via WatchConnectivity
            WatchConnectivityManager.shared.updateWidgetSettings(useNearestStationForWidget)
            
            // Load departure data for the new widget configuration
            Task {
                await loadDepartureDataForNewWidgetSettings()
                
                // Small delay to ensure data is fully saved before widget reload
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                // Force widget reload with new data
                await MainActor.run {
                    WidgetCenter.shared.reloadAllTimelines()
                    print("📱 AppSettings: Final widget reload triggered")
                }
            }
        }
    }
    
    @Published var showPromoTiles: Bool {
        didSet {
            UserDefaults.standard.set(showPromoTiles, forKey: "showPromoTiles")
        }
    }
    
    // Dismissed promo tile IDs
    private(set) var dismissedPromoTileIds: Set<String> {
        didSet {
            if let encoded = try? JSONEncoder().encode(Array(dismissedPromoTileIds)) {
                UserDefaults.standard.set(encoded, forKey: "dismissedPromoTileIds")
            }
        }
    }
    
    func dismissPromoTile(_ id: String) {
        dismissedPromoTileIds.insert(id)
    }
    
    func isPromoTileDismissed(_ id: String) -> Bool {
        return dismissedPromoTileIds.contains(id)
    }
    
    func resetDismissedPromoTiles() {
        dismissedPromoTileIds.removeAll()
        print("🔄 All dismissed promo tiles reset")
    }
    
    var isDarkMode: Bool {
        switch theme {
        case .light:
            return false
        case .dark:
            return true
        case .system:
            return UITraitCollection.current.userInterfaceStyle == .dark
        }
    }
    
    init() {
        let savedTheme = UserDefaults.standard.string(forKey: "theme") ?? Theme.system.rawValue
        self.theme = Theme(rawValue: savedTheme) ?? .system
        
        let savedMode = UserDefaults.standard.string(forKey: "lastLocationPickerMode") ?? LocationPickerMode.list.rawValue
        self.lastLocationPickerMode = LocationPickerMode(rawValue: savedMode) ?? .list
        
        if let savedRegionData = UserDefaults.standard.data(forKey: "lastMapRegion"),
           let savedRegion = try? JSONDecoder().decode(MapRegion.self, from: savedRegionData) {
            self.lastMapRegion = savedRegion
        } else {
            self.lastMapRegion = MapRegion(
                latitude: 47.3769,
                longitude: 8.5417,
                latitudeDelta: 3,
                longitudeDelta: 3
            )
        }
        
        // Initialize showNearestStation with default value true
        self.showNearestStation = UserDefaults.standard.bool(forKey: "showNearestStation", defaultValue: true)
        
        // Initialize showWeatherInfo with default value true
        self.showWeatherInfo = UserDefaults.standard.bool(forKey: "showWeatherInfo", defaultValue: true)
        
        // Initialize enableAlbisClassFilter with default value true
        self.enableAlbisClassFilter = UserDefaults.standard.bool(forKey: "enableAlbisClassFilter", defaultValue: true)
        
        // Initialize useNearestStationForWidget with default value false (favorites first)
        self.useNearestStationForWidget = UserDefaults.standard.bool(forKey: "useNearestStationForWidget", defaultValue: false)
        
        // Initialize showPromoTiles with default value true
        self.showPromoTiles = UserDefaults.standard.bool(forKey: "showPromoTiles", defaultValue: true)
        
        // Load dismissed promo tile IDs
        if let data = UserDefaults.standard.data(forKey: "dismissedPromoTileIds"),
           let ids = try? JSONDecoder().decode([String].self, from: data) {
            self.dismissedPromoTileIds = Set(ids)
        } else {
            self.dismissedPromoTileIds = []
        }
    }
    
    private func loadDepartureDataForNewWidgetSettings() async {
        print("📱 AppSettings: Loading departure data for new widget settings...")
        
        let favorites = FavoriteStationsManager.shared.favorites
        var stationsToLoad: [FavoriteStation] = []
        
        if useNearestStationForWidget {
            // If switching to nearest station, make sure we have nearest station data
            if let nearestStation = SharedDataManager.shared.loadNearestStation() {
                stationsToLoad.append(nearestStation)
                print("📱 AppSettings: Loading data for nearest station: \(nearestStation.name)")
            } else {
                print("📱 AppSettings: No nearest station available, falling back to first favorite")
                if let firstFavorite = favorites.first {
                    stationsToLoad.append(firstFavorite)
                }
            }
        } else {
            // If switching to favorites, use first favorite
            if let firstFavorite = favorites.first {
                stationsToLoad.append(firstFavorite)
                print("📱 AppSettings: Loading data for first favorite: \(firstFavorite.name)")
            }
        }
        
        // Load departure data for selected stations
        var departureInfos: [DepartureInfo] = []
        
        for station in stationsToLoad {
            do {
                guard let uicRef = station.uic_ref else { 
                    print("📱 AppSettings: No UIC reference for station: \(station.name)")
                    continue 
                }
                
                let today = Date()
                let now = today
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
                
                // Load today's departures first
                let todayJourneys = try await TransportAPI().getStationboard(stationId: uicRef, for: today)
                
                // Convert today's journeys to DepartureInfo
                var todayDepartures: [DepartureInfo] = []
                for journey in todayJourneys {
                    guard let departureStr = journey.stop.departure else { continue }
                    guard let departureTime = AppDateFormatter.parseFullTime(departureStr) else { continue }
                    guard departureTime > now else { continue } // Only future departures
                    
                    // Create fullName like in Watch app
                    let routeName: String
                    if let category = journey.category, let number = journey.number {
                        routeName = "\(category)\(number)"
                    } else {
                        routeName = journey.name ?? "Unknown"
                    }
                    
                    // Create bestDirection like in Watch app
                    let direction: String
                    if let passList = journey.passList,
                       passList.count > 1,
                       let nextStation = passList.dropFirst().first {
                        direction = nextStation.station.name ?? "Unknown"
                    } else if let to = journey.to, !to.isEmpty {
                        direction = to
                    } else {
                        direction = journey.name ?? "Departure"
                    }
                    
                    todayDepartures.append(DepartureInfo(
                        stationName: station.name,
                        nextDeparture: departureTime,
                        routeName: routeName,
                        direction: direction
                    ))
                }
                
                print("📱 AppSettings: Found \(todayDepartures.count) future departures today for \(station.name)")
                
                // If less than 3 future departures today, also load tomorrow
                if todayDepartures.count < 3 {
                    print("📱 AppSettings: Loading tomorrow's departures for \(station.name) (only \(todayDepartures.count) today)")
                    
                    do {
                        let tomorrowJourneys = try await TransportAPI().getStationboard(stationId: uicRef, for: tomorrow)
                        
                        for journey in tomorrowJourneys {
                            guard let departureStr = journey.stop.departure else { continue }
                            guard let departureTime = AppDateFormatter.parseFullTime(departureStr) else { continue }
                            
                            // Adjust date to tomorrow
                            let calendar = Calendar.current
                            let tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                            let timeComponents = calendar.dateComponents([.hour, .minute], from: departureTime)
                            
                            var fullComponents = DateComponents()
                            fullComponents.year = tomorrowComponents.year
                            fullComponents.month = tomorrowComponents.month
                            fullComponents.day = tomorrowComponents.day
                            fullComponents.hour = timeComponents.hour
                            fullComponents.minute = timeComponents.minute
                            
                            guard let tomorrowDepartureDate = calendar.date(from: fullComponents) else { continue }
                            
                            // Create fullName like in Watch app
                            let routeName: String
                            if let category = journey.category, let number = journey.number {
                                routeName = "\(category)\(number)"
                            } else {
                                routeName = journey.name ?? "Unknown"
                            }
                            
                            // Create bestDirection like in Watch app
                            let direction: String
                            if let passList = journey.passList,
                               passList.count > 1,
                               let nextStation = passList.dropFirst().first {
                                direction = nextStation.station.name ?? "Unknown"
                            } else if let to = journey.to, !to.isEmpty {
                                direction = to
                            } else {
                                direction = journey.name ?? "Departure"
                            }
                            
                            todayDepartures.append(DepartureInfo(
                                stationName: station.name,
                                nextDeparture: tomorrowDepartureDate,
                                routeName: routeName,
                                direction: direction
                            ))
                        }
                        
                        print("📱 AppSettings: Added \(tomorrowJourneys.count) departures from tomorrow for \(station.name)")
                    } catch {
                        print("📱 AppSettings: Error loading tomorrow's departures for \(station.name): \(error)")
                    }
                }
                
                departureInfos.append(contentsOf: todayDepartures)
                print("📱 AppSettings: Total loaded \(todayDepartures.count) departures for \(station.name)")
            } catch {
                print("📱 AppSettings: Error loading departures for \(station.name): \(error)")
            }
        }
        
        // Save to SharedDataManager for widgets
        SharedDataManager.shared.saveNextDepartures(departureInfos)
        print("📱 AppSettings: Saved \(departureInfos.count) total departures for widgets")
        
        // Force widget update with new data
        WidgetCenter.shared.reloadAllTimelines()
        print("📱 AppSettings: Triggered widget update with new departure data")
    }
}

enum LocationPickerMode: String {
    case list
    case map
}

struct MapRegion: Codable {
    let latitude: Double
    let longitude: Double
    let latitudeDelta: Double
    let longitudeDelta: Double
} 