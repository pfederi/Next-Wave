import Foundation

struct FavoriteStation: Codable, Identifiable {
    let id: String // station id
    let name: String
    let latitude: Double?
    let longitude: Double?
    let uic_ref: String?
    
    static let maxFavorites = 5
}

class FavoriteStationsManager: ObservableObject {
    static let shared = FavoriteStationsManager()
    @Published private(set) var favorites: [FavoriteStation] = []
    
    private let userDefaults = UserDefaults(suiteName: "group.com.federi.Next-Wave")
    private let favoritesKey = "favoriteStations"
    private let watchConnectivityManager = WatchConnectivityManager.shared
    
    private init() {
        print("FavoriteStationsManager: Initializing with UserDefaults suite: group.com.federi.Next-Wave")
        if let userDefaults = userDefaults {
            print("FavoriteStationsManager: Available keys before loading: \(Array(userDefaults.dictionaryRepresentation().keys))")
        }
        loadFavorites()
    }
    
    private func loadFavorites() {
        if let data = userDefaults?.data(forKey: favoritesKey) {
            print("FavoriteStationsManager: Found data for key: \(favoritesKey)")
            print("FavoriteStationsManager: Data size: \(data.count) bytes")
            if let decoded = try? JSONDecoder().decode([FavoriteStation].self, from: data) {
                favorites = decoded
                print("FavoriteStationsManager: Successfully loaded \(favorites.count) favorites")
                
                // Send initial state to Watch - let Watch handle widget updates
                watchConnectivityManager.updateFavorites(favorites)
            } else {
                print("FavoriteStationsManager: Failed to decode favorites data")
            }
        } else {
            print("FavoriteStationsManager: No favorites data found")
        }
    }
    
    private func saveFavorites() {
        print("FavoriteStationsManager: Saving \(favorites.count) favorites")
        if let encoded = try? JSONEncoder().encode(favorites) {
            print("FavoriteStationsManager: Encoded data size: \(encoded.count) bytes")
            userDefaults?.set(encoded, forKey: favoritesKey)
            userDefaults?.synchronize() // Force immediate synchronization
            
            // Verify the save
            if let data = userDefaults?.data(forKey: favoritesKey) {
                print("FavoriteStationsManager: Verified data exists after save, size: \(data.count) bytes")
                if let decoded = try? JSONDecoder().decode([FavoriteStation].self, from: data) {
                    print("FavoriteStationsManager: Verified save - can read back \(decoded.count) favorites")
                    
                    // Send to Watch - let Watch handle widget updates
                    watchConnectivityManager.updateFavorites(favorites)
                    print("FavoriteStationsManager: Sent favorites update to Watch")
                    
                    // Also explicitly trigger widget update
                    watchConnectivityManager.triggerWidgetUpdate()
                    print("FavoriteStationsManager: Triggered explicit widget update")
                } else {
                    print("FavoriteStationsManager: Failed to verify favorites save - could not decode data")
                }
            } else {
                print("FavoriteStationsManager: Failed to verify favorites save - no data found")
            }
        }
    }
    
    func addFavorite(_ station: Lake.Station) {
        guard !isFavorite(station) && favorites.count < FavoriteStation.maxFavorites else { return }
        let favorite = FavoriteStation(
            id: station.id, 
            name: station.name,
            latitude: station.coordinates?.latitude,
            longitude: station.coordinates?.longitude,
            uic_ref: station.uic_ref
        )
        favorites.append(favorite)
        saveFavorites()
    }
    
    func removeFavorite(_ station: Lake.Station) {
        favorites.removeAll { $0.id == station.id }
        saveFavorites()
    }
    
    func isFavorite(_ station: Lake.Station) -> Bool {
        favorites.contains { $0.id == station.id }
    }
    
    func reorderFavorites(fromOffsets source: IndexSet, toOffset destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)
        saveFavorites()
    }
} 