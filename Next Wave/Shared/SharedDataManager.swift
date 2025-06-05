import Foundation

// Importiere Lake für den Zugriff auf Station
// import struct Next_Wave.Lake

class SharedDataManager {
    static let shared = SharedDataManager()
    
    private let userDefaults = UserDefaults(suiteName: "group.com.federi.Next-Wave")
    private let favoritesKey = "favoriteStations"
    private let departuresKey = "nextDepartures"
    private let nearestStationKey = "nearestStation"
    private let widgetSettingsKey = "widgetSettings"
    
    private init() {}
    
    // MARK: - Favorites
    
    func saveFavoriteStations(_ stations: [FavoriteStation]) {
        if let encoded = try? JSONEncoder().encode(stations) {
            userDefaults?.set(encoded, forKey: favoritesKey)
            userDefaults?.synchronize() // Force immediate synchronization
        }
    }
    
    func loadFavoriteStations() -> [FavoriteStation] {
        if let data = userDefaults?.data(forKey: favoritesKey),
           let stations = try? JSONDecoder().decode([FavoriteStation].self, from: data) {
            return stations
        }
        return []
    }
    
    // MARK: - Departures
    
    func saveNextDepartures(_ departures: [DepartureInfo]) {
        if let encoded = try? JSONEncoder().encode(departures) {
            userDefaults?.set(encoded, forKey: departuresKey)
        }
    }
    
    func loadNextDepartures() -> [DepartureInfo] {
        guard let data = userDefaults?.data(forKey: departuresKey),
              let departures = try? JSONDecoder().decode([DepartureInfo].self, from: data) else {
            return []
        }
        return departures
    }


    
    // MARK: - Nearest Station
    func saveNearestStation(_ station: FavoriteStation?) {
        if let station = station,
           let encoded = try? JSONEncoder().encode(station) {
            userDefaults?.set(encoded, forKey: nearestStationKey)
            userDefaults?.synchronize()
        } else {
            userDefaults?.removeObject(forKey: nearestStationKey)
            userDefaults?.synchronize()
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
            userDefaults?.synchronize()
        }
    }
    
    func loadWidgetSettings() -> WidgetSettings {
        guard let data = userDefaults?.data(forKey: widgetSettingsKey),
              let settings = try? JSONDecoder().decode(WidgetSettings.self, from: data) else {
            return WidgetSettings(useNearestStation: false) // Default to favorites
        }
        return settings
    }
}