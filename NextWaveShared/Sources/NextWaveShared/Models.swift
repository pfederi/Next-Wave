import Foundation

public struct Lake: Identifiable, Codable {
    public let name: String
    public let operators: [String]
    public let stations: [Station]
    
    public var id: String { name }
    
    public struct Station: Identifiable, Codable {
        public let name: String
        public let uic_ref: String
        public let coordinates: Coordinates?
        
        public var id: String { uic_ref }
        
        public struct Coordinates: Codable {
            public let latitude: Double
            public let longitude: Double
            
            public init(latitude: Double, longitude: Double) {
                self.latitude = latitude
                self.longitude = longitude
            }
        }
        
        public init(id: String, name: String, coordinates: Coordinates?) {
            self.uic_ref = id
            self.name = name
            self.coordinates = coordinates
        }
    }
    
    public init(id: String, name: String, stations: [Station]) {
        self.name = name
        self.operators = []
        self.stations = stations
    }
}

public struct LakesResponse: Codable {
    public let lakes: [Lake]
}

public struct FavoriteStation: Codable, Identifiable {
    public let id: String
    public let name: String
    
    public static let maxFavorites = 5
    
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public class FavoriteStationsManager: ObservableObject {
    public static let shared = FavoriteStationsManager()
    @Published public private(set) var favorites: [FavoriteStation] = []
    
    private init() {
        print("📱 Initializing FavoriteStationsManager")
        AppGroup.initialize()
        loadFavorites()
    }
    
    private func loadFavorites() {
        print("📱 Loading favorites from App Group")
        guard let defaults = AppGroup.userDefaults else {
            print("❌ Failed to access App Group UserDefaults")
            return
        }
        
        guard let data = defaults.data(forKey: AppGroup.Keys.favorites) else {
            print("❌ No favorites data found in App Group")
            return
        }
        
        do {
            let decoded = try JSONDecoder().decode([FavoriteStation].self, from: data)
            print("✅ Successfully loaded \(decoded.count) favorites from App Group")
            favorites = decoded
        } catch {
            print("❌ Failed to decode favorites: \(error)")
        }
    }
    
    private func saveFavorites() {
        print("📱 Saving \(favorites.count) favorites to App Group")
        guard let defaults = AppGroup.userDefaults else {
            print("❌ Failed to access App Group UserDefaults")
            return
        }
        
        do {
            let encoded = try JSONEncoder().encode(favorites)
            defaults.set(encoded, forKey: AppGroup.Keys.favorites)
            defaults.synchronize()
            print("✅ Successfully saved favorites to App Group")
        } catch {
            print("❌ Failed to encode favorites: \(error)")
        }
    }
    
    public func addFavorite(_ station: Lake.Station) {
        guard !isFavorite(station) && favorites.count < FavoriteStation.maxFavorites else { return }
        let favorite = FavoriteStation(id: station.id, name: station.name)
        favorites.append(favorite)
        saveFavorites()
    }
    
    public func removeFavorite(_ station: Lake.Station) {
        favorites.removeAll { $0.id == station.id }
        saveFavorites()
    }
    
    public func isFavorite(_ station: Lake.Station) -> Bool {
        favorites.contains { $0.id == station.id }
    }
}

public enum AppGroup {
    public static let groupId = "group.com.federi.NextWave"
    
    public static var userDefaults: UserDefaults? = {
        guard let defaults = UserDefaults(suiteName: groupId) else {
            print("⚠️ Failed to initialize UserDefaults with App Group: \(groupId)")
            return nil
        }
        return defaults
    }()
    
    public enum Keys {
        public static let favorites = "favoriteStations"
        public static let lastLocation = "lastKnownLocation"
        public static let stations = "allStations"
    }
    
    public static func initialize() {
        guard let defaults = userDefaults else {
            print("⚠️ Cannot initialize App Group: UserDefaults is nil")
            return
        }
        
        // Create default JSON values
        let defaultFavorites = try? JSONEncoder().encode([FavoriteStation]())
        let defaultLocation = try? JSONEncoder().encode(Location(latitude: 0, longitude: 0))
        let defaultStations = try? JSONEncoder().encode([Lake]())
        
        // Register default values with proper JSON arrays/objects
        let defaultValues: [String: Any] = [
            Keys.favorites: defaultFavorites ?? "[]".data(using: .utf8)!,
            Keys.lastLocation: defaultLocation ?? "{}".data(using: .utf8)!,
            Keys.stations: defaultStations ?? "[]".data(using: .utf8)!
        ]
        
        defaults.register(defaults: defaultValues)
        
        // Verify we can write to the container
        defaults.set(Date(), forKey: "lastInitialized")
        defaults.synchronize()
        
        // Verify we can read from the container
        if let _ = defaults.object(forKey: "lastInitialized") {
            print("✅ App Group container initialized successfully")
        } else {
            print("⚠️ Failed to verify App Group container access")
        }
        
        // Debug: Print current values and verify data format
        print("📦 Current App Group Data:")
        verifyData(defaults)
    }
    
    private static func verifyData(_ defaults: UserDefaults) {
        // Verify favorites
        if let favData = defaults.data(forKey: Keys.favorites) {
            print("- Favorites data size: \(favData.count) bytes")
            do {
                let favorites = try JSONDecoder().decode([FavoriteStation].self, from: favData)
                print("  ✅ Valid favorites data: \(favorites.count) favorites")
            } catch {
                print("  ❌ Invalid favorites data: \(error)")
            }
        } else {
            print("- No favorites data")
        }
        
        // Verify location
        if let locData = defaults.data(forKey: Keys.lastLocation) {
            print("- Location data size: \(locData.count) bytes")
            do {
                let location = try JSONDecoder().decode(Location.self, from: locData)
                print("  ✅ Valid location data: \(location.latitude), \(location.longitude)")
            } catch {
                print("  ❌ Invalid location data: \(error)")
            }
        } else {
            print("- No location data")
        }
        
        // Verify stations
        if let stationsData = defaults.data(forKey: Keys.stations) {
            print("- Stations data size: \(stationsData.count) bytes")
            do {
                let stations = try JSONDecoder().decode([Lake].self, from: stationsData)
                print("  ✅ Valid stations data: \(stations.count) lakes")
            } catch {
                print("  ❌ Invalid stations data: \(error)")
            }
        } else {
            print("- No stations data")
        }
    }
    
    public static func reset() {
        userDefaults?.removePersistentDomain(forName: groupId)
        userDefaults?.synchronize()
        initialize()
    }
}

// Helper struct for location data
private struct Location: Codable {
    let latitude: Double
    let longitude: Double
} 