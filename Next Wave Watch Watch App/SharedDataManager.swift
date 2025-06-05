import Foundation

struct DepartureInfo: Codable {
    let stationName: String
    let nextDeparture: Date
    let routeName: String
    let direction: String
}

struct FavoriteStation: Codable {
    let id: String
    let name: String
    let latitude: Double?
    let longitude: Double?
    let uic_ref: String?
    
    private enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, uic_ref
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        uic_ref = try container.decodeIfPresent(String.self, forKey: .uic_ref)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encodeIfPresent(uic_ref, forKey: .uic_ref)
    }
}

class SharedDataManager {
    static let shared = SharedDataManager()
    private let logger = WatchLogger.shared
    
    private let userDefaults = UserDefaults(suiteName: "group.com.federi.Next-Wave")
    private let favoritesKey = "favoriteStations"
    private let departuresKey = "nextDepartures"
    private var notificationToken: NSObjectProtocol?
    
    private init() {
        logger.debug("SharedDataManager initializing...")
        
        // Force synchronize to ensure we have the latest data
        userDefaults?.synchronize()
        
        // Add observer for UserDefaults changes
        notificationToken = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: userDefaults,
            queue: .main
        ) { [weak self] _ in
            self?.logger.debug("UserDefaults changed notification received")
            self?.userDefaults?.synchronize()
            
            // Check if favorites changed
            if let data = self?.userDefaults?.data(forKey: self?.favoritesKey ?? ""),
               let stations = try? JSONDecoder().decode([FavoriteStation].self, from: data) {
                self?.logger.debug("UserDefaults change contained \(stations.count) favorites")
            }
        }
        
        // Try to read favorites immediately to verify access
        if let data = userDefaults?.data(forKey: favoritesKey) {
            logger.debug("Found favorites data on init, size: \(data.count) bytes")
            do {
                let stations = try JSONDecoder().decode([FavoriteStation].self, from: data)
                logger.debug("Successfully decoded \(stations.count) stations on init")
            } catch {
                logger.error("Failed to decode favorites on init: \(error.localizedDescription)")
                logger.error("Raw data: \(data.base64EncodedString())")
            }
        } else {
            logger.debug("No favorites data found on init")
        }
    }
    
    deinit {
        if let token = notificationToken {
            NotificationCenter.default.removeObserver(token)
        }
    }
    
    // MARK: - Favorites
    
    func saveFavoriteStations(_ stations: [FavoriteStation]) {
        logger.debug("Saving \(stations.count) favorite stations: \(stations)")
        if let encoded = try? JSONEncoder().encode(stations) {
            userDefaults?.set(encoded, forKey: favoritesKey)
            userDefaults?.synchronize() // Force immediate synchronization
            logger.debug("Successfully saved to UserDefaults")
            
            // Verify the save
            if let data = userDefaults?.data(forKey: favoritesKey),
               let decoded = try? JSONDecoder().decode([FavoriteStation].self, from: data) {
                logger.debug("Verified save - read back \(decoded.count) stations: \(decoded)")
                
                // Print all available keys
                if let keys = userDefaults?.dictionaryRepresentation().keys {
                    logger.debug("Available keys in UserDefaults: \(Array(keys))")
                }
            } else {
                logger.error("Failed to verify save")
            }
        } else {
            logger.error("Failed to encode stations")
        }
    }
    
    func loadFavoriteStations() -> [FavoriteStation] {
        logger.debug("Loading favorite stations")
        if let data = userDefaults?.data(forKey: favoritesKey),
           let stations = try? JSONDecoder().decode([FavoriteStation].self, from: data) {
            logger.debug("Successfully loaded \(stations.count) stations: \(stations)")
            return stations
        }
        logger.debug("No stations found")
        return []
    }
    
    // MARK: - Departures
    
    func saveNextDepartures(_ departures: [DepartureInfo]) {
        if let encoded = try? JSONEncoder().encode(departures) {
            userDefaults?.set(encoded, forKey: departuresKey)
            userDefaults?.synchronize() // Force immediate synchronization
        }
    }
    
    func loadNextDepartures() -> [DepartureInfo] {
        guard let data = userDefaults?.data(forKey: departuresKey),
              let departures = try? JSONDecoder().decode([DepartureInfo].self, from: data) else {
            return []
        }
        return departures
    }
    
    // MARK: - Testing
    
    func testAppGroupAccess() {
        let testKey = "appGroupTestKey"
        let testValue = "Hello from Watch!"

        userDefaults?.set(testValue, forKey: testKey)
        userDefaults?.synchronize()

        if let readValue = userDefaults?.string(forKey: testKey) {
            logger.info("✅ App Group Test: Gelesener Wert: \(readValue)")
        } else {
            logger.error("❌ App Group Test: Konnte Wert nicht lesen!")
        }

        if let keys = userDefaults?.dictionaryRepresentation().keys {
            logger.debug("App Group UserDefaults Keys: \(Array(keys))")
        }
    }
} 