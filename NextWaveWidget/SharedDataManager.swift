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
        
        return getSmartDepartures(
            from: allDepartures,
            stationName: firstStation.name,
            now: now,
            count: 1
        ).first
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
                
                let nextDeparture = getSmartDepartures(
                    from: allDepartures,
                    stationName: nearestStation.name,
                    now: now,
                    count: 1
                ).first
                    
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
                let departures = getSmartDepartures(
                    from: allDepartures,
                    stationName: nearestStation.name,
                    now: now,
                    count: count
                )
                    
                if !departures.isEmpty {
                    return departures
                }
            }
            
            // Fallback to first favorite if no nearest station departures found
            let favoriteStations = loadFavoriteStations()
            guard let firstStation = favoriteStations.first else { return [] }
            
            return getSmartDepartures(
                from: allDepartures,
                stationName: firstStation.name,
                now: now,
                count: count
            )
        } else {
            // Use favorites
            let favoriteStations = loadFavoriteStations()
            guard let firstStation = favoriteStations.first else { return [] }
            
            return getSmartDepartures(
                from: allDepartures,
                stationName: firstStation.name,
                now: now,
                count: count
            )
        }
    }
    
    // Smart departure filtering with proactive data loading and multi-day support
    private func getSmartDepartures(from allDepartures: [DepartureInfo], stationName: String, now: Date, count: Int) -> [DepartureInfo] {
        let calendar = Calendar.current
        
        // Get today's future departures for this station
        let todayDepartures = allDepartures
            .filter { $0.stationName == stationName }
            .filter { $0.nextDeparture > now }
            .filter { calendar.isDate($0.nextDeparture, inSameDayAs: now) }
            .sorted { $0.nextDeparture < $1.nextDeparture }
        
        var smartDepartures = Array(todayDepartures)
        
        // If we need more departures to fill the widget, add tomorrow's departures
        if smartDepartures.count < count {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            let tomorrowDepartures = allDepartures
                .filter { $0.stationName == stationName }
                .filter { calendar.isDate($0.nextDeparture, inSameDayAs: tomorrow) }
                .sorted { $0.nextDeparture < $1.nextDeparture }
            
            // Add tomorrow's departures to fill up to the requested count
            let remainingSlots = count - smartDepartures.count
            smartDepartures.append(contentsOf: Array(tomorrowDepartures.prefix(remainingSlots)))
            
            sharedDataLogger.info("🔍 Widget: Combined \(todayDepartures.count) today + \(min(remainingSlots, tomorrowDepartures.count)) tomorrow departures for \(stationName)")
        }
        
        // Return the combined departures if we have any
        if !smartDepartures.isEmpty {
            let result = Array(smartDepartures.prefix(count))
            sharedDataLogger.info("🔍 Widget: Returning \(result.count) of requested \(count) departures for \(stationName)")
            return result
        }
        
        // Fallback: If no departures today and after 17:00, try tomorrow only
        let hour = calendar.component(.hour, from: now)
        if hour >= 17 {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            let tomorrowDepartures = allDepartures
                .filter { $0.stationName == stationName }
                .filter { calendar.isDate($0.nextDeparture, inSameDayAs: tomorrow) }
                .sorted { $0.nextDeparture < $1.nextDeparture }
                .prefix(count)
            
            if !tomorrowDepartures.isEmpty {
                sharedDataLogger.info("🔍 Widget: Using tomorrow's departures only (after 17:00)")
                return Array(tomorrowDepartures)
            }
        }
        
        // Try any future departures from any day
        let futureDepartures = allDepartures
            .filter { $0.stationName == stationName }
            .filter { $0.nextDeparture > now }
            .sorted { $0.nextDeparture < $1.nextDeparture }
            .prefix(count)
        
        if !futureDepartures.isEmpty {
            sharedDataLogger.info("🔍 Widget: Using any future departures")
            return Array(futureDepartures)
        }
        
        // If still no departures, show a helpful message encouraging app usage
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let tomorrowMorning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        
        let placeholderDeparture = DepartureInfo(
            stationName: stationName,
            nextDeparture: tomorrowMorning,
            routeName: "Open App",
            direction: "for fresh departure times"
        )
        
        sharedDataLogger.info("🔍 Widget: No departures found, using placeholder")
        return [placeholderDeparture]
    }
}

struct FavoriteStation: Codable {
    let id: String
    let name: String
    let latitude: Double?
    let longitude: Double?
    let uic_ref: String?
} 