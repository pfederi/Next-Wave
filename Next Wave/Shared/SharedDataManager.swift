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
        print("SharedDataManager: Saving \(stations.count) favorite stations: \(stations)")
        if let encoded = try? JSONEncoder().encode(stations) {
            userDefaults?.set(encoded, forKey: favoritesKey)
            userDefaults?.synchronize() // Force immediate synchronization
            print("SharedDataManager: Successfully saved to UserDefaults")
            
            // Verify the save
            if let data = userDefaults?.data(forKey: favoritesKey),
               let decoded = try? JSONDecoder().decode([FavoriteStation].self, from: data) {
                print("SharedDataManager: Verified save - read back \(decoded.count) stations: \(decoded)")
                
                // Print all available keys
                if let keys = userDefaults?.dictionaryRepresentation().keys {
                    print("SharedDataManager: Available keys in UserDefaults: \(Array(keys))")
                }
            } else {
                print("SharedDataManager: Failed to verify save")
            }
        } else {
            print("SharedDataManager: Failed to encode stations")
        }
    }
    
    func loadFavoriteStations() -> [FavoriteStation] {
        print("SharedDataManager: Loading favorite stations")
        if let data = userDefaults?.data(forKey: favoritesKey),
           let stations = try? JSONDecoder().decode([FavoriteStation].self, from: data) {
            print("SharedDataManager: Successfully loaded \(stations.count) stations: \(stations)")
            return stations
        }
        print("SharedDataManager: No stations found")
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

    // Test-Methode für App Group Zugriff
    func testAppGroupAccess() {
        let testKey = "appGroupTestKey"
        let testValue = "Hello from Watch!"

        userDefaults?.set(testValue, forKey: testKey)
        userDefaults?.synchronize()

        if let readValue = userDefaults?.string(forKey: testKey) {
            print("✅ App Group Test: Gelesener Wert: \(readValue)")
        } else {
            print("❌ App Group Test: Konnte Wert nicht lesen!")
        }

        if let keys = userDefaults?.dictionaryRepresentation().keys {
            print("App Group UserDefaults Keys: \(Array(keys))")
        }
    }
}