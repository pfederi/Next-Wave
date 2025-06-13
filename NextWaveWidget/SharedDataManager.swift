import Foundation
import os.log

// Create a specific logger for the widget SharedDataManager
private let sharedDataLogger = Logger(subsystem: "com.federi.Next-Wave.NextWaveWidget", category: "SharedDataManager")

class SharedDataManager {
    static let shared = SharedDataManager()
    
    private let userDefaults = UserDefaults(suiteName: "group.com.federi.Next-Wave")
    private let nextDeparturesKey = "nextDepartures"
    private let favoriteStationsKey = "favoriteStations"
    private let nearestStationKey = "nearestStation"
    private let widgetSettingsKey = "widgetSettings"
    
    private init() {}
    
    func saveNextDepartures(_ departures: [DepartureInfo]) {
        if let encoded = try? JSONEncoder().encode(departures) {
            userDefaults?.set(encoded, forKey: nextDeparturesKey)
        }
    }
    
    func loadNextDepartures() -> [DepartureInfo] {
        guard let data = userDefaults?.data(forKey: nextDeparturesKey),
              let departures = try? JSONDecoder().decode([DepartureInfo].self, from: data) else {
            return []
        }
        return departures
    }
    
    func loadFavoriteStations() -> [FavoriteStation] {
        sharedDataLogger.info("🔍 SharedDataManager.loadFavoriteStations() called")
        sharedDataLogger.info("🔍 UserDefaults suite: group.com.federi.Next-Wave")
        
        // First, try to check if userDefaults is available
        if userDefaults == nil {
            sharedDataLogger.error("🔍 ERROR: UserDefaults suite is nil - App Group not working!")
        }
        
        // Check all available keys in App Group UserDefaults
        if let dict = userDefaults?.dictionaryRepresentation() {
            sharedDataLogger.info("🔍 App Group UserDefaults keys: \(Array(dict.keys).sorted())")
        } else {
            sharedDataLogger.info("🔍 App Group UserDefaults dictionary is nil or empty")
        }
        
        // Try App Group first
        if let data = userDefaults?.data(forKey: favoriteStationsKey) {
            sharedDataLogger.info("🔍 Found data for favoriteStations in App Group: \(data.count) bytes")
            
            if let stations = try? JSONDecoder().decode([FavoriteStation].self, from: data) {
                sharedDataLogger.info("🔍 Successfully decoded \(stations.count) favorite stations from App Group")
                for station in stations {
                    sharedDataLogger.info("🔍   - \(station.name)")
                }
                return stations
            } else {
                sharedDataLogger.error("🔍 Failed to decode favorites data from App Group")
            }
        } else {
            sharedDataLogger.info("🔍 No data found for key '\(self.favoriteStationsKey)' in App Group")
        }
        
        // FALLBACK: Try standard UserDefaults as backup
        sharedDataLogger.info("🔍 FALLBACK: Trying standard UserDefaults")
        let standardDefaults = UserDefaults.standard
        
        if let fallbackData = standardDefaults.data(forKey: "fallback_\(self.favoriteStationsKey)") {
            sharedDataLogger.info("🔍 FALLBACK: Found fallback data: \(fallbackData.count) bytes")
            
            if let stations = try? JSONDecoder().decode([FavoriteStation].self, from: fallbackData) {
                sharedDataLogger.info("🔍 FALLBACK: Successfully decoded \(stations.count) favorite stations from standard UserDefaults")
                for station in stations {
                    sharedDataLogger.info("🔍 FALLBACK:   - \(station.name)")
                }
                return stations
            } else {
                sharedDataLogger.error("🔍 FALLBACK: Failed to decode fallback data")
            }
        } else {
            sharedDataLogger.info("🔍 FALLBACK: No fallback data found either")
        }
        
        // FILE FALLBACK: Try shared file location
        sharedDataLogger.info("🔍 FILE FALLBACK: Trying shared file location")
        if let stations = loadFromSharedFile() {
            sharedDataLogger.info("🔍 FILE FALLBACK: Successfully loaded \(stations.count) stations from shared file")
            return stations
        }
        
        sharedDataLogger.info("🔍 No favorites found in either App Group, standard UserDefaults, or shared file")
        return []
    }
    
    private func loadFromSharedFile() -> [FavoriteStation]? {
        do {
            let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.federi.Next-Wave")
            guard let sharedURL = groupURL?.appendingPathComponent("favorites.json") else {
                sharedDataLogger.error("🔍 FILE FALLBACK: Could not get shared container URL")
                return nil
            }
            
            let data = try Data(contentsOf: sharedURL)
            let stations = try JSONDecoder().decode([FavoriteStation].self, from: data)
            sharedDataLogger.info("🔍 FILE FALLBACK: Successfully loaded \(stations.count) stations from \(sharedURL.path)")
            for station in stations {
                sharedDataLogger.info("🔍 FILE FALLBACK:   - \(station.name)")
            }
            return stations
        } catch {
            sharedDataLogger.error("🔍 FILE FALLBACK: Failed to load from shared file: \(error)")
            return nil
        }
    }
    
    func saveFavoriteStations(_ stations: [FavoriteStation]) {
        sharedDataLogger.info("🔍 SharedDataManager.saveFavoriteStations() called with \(stations.count) stations")
        
        if let encoded = try? JSONEncoder().encode(stations) {
            userDefaults?.set(encoded, forKey: favoriteStationsKey)
            sharedDataLogger.info("🔍 Saved \(encoded.count) bytes to UserDefaults with key '\(self.favoriteStationsKey)'")
            
            // Verify the save
            if let verifyData = userDefaults?.data(forKey: favoriteStationsKey) {
                sharedDataLogger.info("🔍 Verification: found \(verifyData.count) bytes after save")
                if let verifyStations = try? JSONDecoder().decode([FavoriteStation].self, from: verifyData) {
                    sharedDataLogger.info("🔍 Verification: successfully decoded \(verifyStations.count) stations")
                } else {
                    sharedDataLogger.error("🔍 Verification: failed to decode after save")
                }
            } else {
                sharedDataLogger.error("🔍 Verification: no data found after save!")
            }
        } else {
            sharedDataLogger.error("🔍 Failed to encode \(stations.count) stations")
        }
    }
    
    func getNextDepartureForFirstFavorite() -> DepartureInfo? {
        let favoriteStations = loadFavoriteStations()
        guard let firstStation = favoriteStations.first else { return nil }
        
        let allDepartures = loadNextDepartures()
        let now = Date()
        
        // Find next departure for the first favorite station
        let nextDeparture = allDepartures
            .filter { $0.stationName == firstStation.name }
            .filter { $0.nextDeparture > now }
            .sorted { $0.nextDeparture < $1.nextDeparture }
            .first
            
        return nextDeparture
    }
    
    // MARK: - Nearest Station
    func saveNearestStation(_ station: FavoriteStation?) {
        if let station = station,
           let encoded = try? JSONEncoder().encode(station) {
            userDefaults?.set(encoded, forKey: nearestStationKey)
        } else {
            userDefaults?.removeObject(forKey: nearestStationKey)
        }
    }
    
    func loadNearestStation() -> FavoriteStation? {
        guard let data = userDefaults?.data(forKey: nearestStationKey),
              let station = try? JSONDecoder().decode(FavoriteStation.self, from: data) else {
            return nil
        }
        return station
    }
    
    // MARK: - Widget Settings
    struct WidgetSettings: Codable {
        let useNearestStation: Bool
    }
    
    func saveWidgetSettings(useNearestStation: Bool) {
        let settings = WidgetSettings(useNearestStation: useNearestStation)
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults?.set(encoded, forKey: widgetSettingsKey)
        }
    }
    
    func loadWidgetSettings() -> WidgetSettings {
        guard let data = userDefaults?.data(forKey: widgetSettingsKey),
              let settings = try? JSONDecoder().decode(WidgetSettings.self, from: data) else {
            return WidgetSettings(useNearestStation: false) // Default to favorites
        }
        return settings
    }
    
    // MARK: - Widget Logic
    func getNextDepartureForWidget() -> DepartureInfo? {
        let settings = loadWidgetSettings()
        
        if settings.useNearestStation {
            // Try nearest station first
            if let nearestStation = loadNearestStation() {
                let allDepartures = loadNextDepartures()
                let now = Date()
                
                let nextDeparture = allDepartures
                    .filter { $0.stationName == nearestStation.name }
                    .filter { $0.nextDeparture > now }
                    .sorted { $0.nextDeparture < $1.nextDeparture }
                    .first
                    
                if let departure = nextDeparture {
                    return departure
                }
            }
            
            // Fallback to first favorite if no nearest station departure found
            return getNextDepartureForFirstFavorite()
        } else {
            // Use favorites
            return getNextDepartureForFirstFavorite()
        }
    }
    
    // Get next 3 departures for widget
    func getNext3DeparturesForWidget() -> [DepartureInfo] {
        return getNextDeparturesForWidget(count: 3)
    }
    
    // Get next 5 departures for widget
    func getNext5DeparturesForWidget() -> [DepartureInfo] {
        return getNextDeparturesForWidget(count: 5)
    }
    
    // Generic function to get next N departures
    private func getNextDeparturesForWidget(count: Int) -> [DepartureInfo] {
        let settings = loadWidgetSettings()
        let allDepartures = loadNextDepartures()
        let now = Date()
        
        if settings.useNearestStation {
            // Try nearest station first
            if let nearestStation = loadNearestStation() {
                let departures = allDepartures
                    .filter { $0.stationName == nearestStation.name }
                    .filter { $0.nextDeparture > now }
                    .sorted { $0.nextDeparture < $1.nextDeparture }
                    .prefix(count)
                    
                if !departures.isEmpty {
                    return Array(departures)
                }
            }
            
            // Fallback to first favorite if no nearest station departures found
            let favoriteStations = loadFavoriteStations()
            guard let firstStation = favoriteStations.first else { return [] }
            
            return allDepartures
                .filter { $0.stationName == firstStation.name }
                .filter { $0.nextDeparture > now }
                .sorted { $0.nextDeparture < $1.nextDeparture }
                .prefix(count)
                .map { $0 }
        } else {
            // Use favorites
            let favoriteStations = loadFavoriteStations()
            guard let firstStation = favoriteStations.first else { return [] }
            
            return allDepartures
                .filter { $0.stationName == firstStation.name }
                .filter { $0.nextDeparture > now }
                .sorted { $0.nextDeparture < $1.nextDeparture }
                .prefix(count)
                .map { $0 }
        }
    }
}

struct FavoriteStation: Codable {
    let id: String
    let name: String
    let latitude: Double?
    let longitude: Double?
    let uic_ref: String?
} 