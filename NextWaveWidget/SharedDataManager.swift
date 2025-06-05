import Foundation

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
        guard let data = userDefaults?.data(forKey: favoriteStationsKey),
              let stations = try? JSONDecoder().decode([FavoriteStation].self, from: data) else {
            return []
        }
        return stations
    }
    
    func saveFavoriteStations(_ stations: [FavoriteStation]) {
        if let encoded = try? JSONEncoder().encode(stations) {
            userDefaults?.set(encoded, forKey: favoriteStationsKey)
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
}

struct FavoriteStation: Codable {
    let id: String
    let name: String
    let latitude: Double?
    let longitude: Double?
    let uic_ref: String?
} 