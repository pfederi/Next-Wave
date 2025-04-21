import Foundation

// Importiere Lake für den Zugriff auf Station
// import struct Next_Wave.Lake

class SharedDataManager {
    static let shared = SharedDataManager()
    
    private let userDefaults = UserDefaults(suiteName: "group.com.federi.Next-Wave")
    private let favoritesKey = "favoriteStations"
    private let departuresKey = "nextDepartures"
    
    private init() {}
    
    // MARK: - Favorites
    
    func saveFavoriteStations(_ stations: [FavoriteStation]) {
        if let encoded = try? JSONEncoder().encode(stations) {
            userDefaults?.set(encoded, forKey: favoritesKey)
        }
    }
    
    func loadFavoriteStations() -> [FavoriteStation] {
        guard let data = userDefaults?.data(forKey: favoritesKey),
              let stations = try? JSONDecoder().decode([FavoriteStation].self, from: data) else {
            return []
        }
        return stations
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
} 