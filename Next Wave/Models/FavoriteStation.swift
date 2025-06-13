import Foundation
import WidgetKit

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
        loadFavorites()
        
        // Load departure data when app starts
        Task { @MainActor in
            await loadDepartureDataForWidgets()
        }
    }
    
    private func loadFavorites() {
        print("🔍 FavoriteStationsManager.loadFavorites() called")
        
        if let data = userDefaults?.data(forKey: favoritesKey) {
            print("🔍 Found favorites data: \(data.count) bytes")
            
            if let decoded = try? JSONDecoder().decode([FavoriteStation].self, from: data) {
                favorites = decoded
                print("🔍 Loaded \(favorites.count) favorites from UserDefaults")
                for favorite in favorites {
                    print("🔍   - \(favorite.name)")
                }
                
                // Also ensure SharedDataManager has the same data for widgets
                SharedDataManager.shared.saveFavoriteStations(favorites)
                print("🔍 Synced favorites to SharedDataManager")
                
                // Send initial state to Watch - let Watch handle widget updates
                watchConnectivityManager.updateFavorites(favorites)
            } else {
                print("🔍 Failed to decode favorites data")
            }
        } else {
            print("🔍 No favorites data found in UserDefaults")
        }
    }
    
    private func saveFavorites() {
        print("🔍 FavoriteStationsManager.saveFavorites() called with \(favorites.count) favorites")
        
        if let encoded = try? JSONEncoder().encode(favorites) {
            userDefaults?.set(encoded, forKey: favoritesKey)
            userDefaults?.synchronize() // Force immediate synchronization
            print("🔍 Saved to UserDefaults with key '\(favoritesKey)'")
            
            // DEBUG: Immediately try to read back the data to verify App Group is working
            if let readBackData = userDefaults?.data(forKey: favoritesKey) {
                print("🔍 VERIFICATION: Successfully read back \(readBackData.count) bytes")
                if let readBackFavorites = try? JSONDecoder().decode([FavoriteStation].self, from: readBackData) {
                    print("🔍 VERIFICATION: Successfully decoded \(readBackFavorites.count) favorites")
                    for fav in readBackFavorites {
                        print("🔍 VERIFICATION:   - \(fav.name)")
                    }
                } else {
                    print("🔍 VERIFICATION: Failed to decode read-back data")
                }
            } else {
                print("🔍 VERIFICATION: Failed to read back data - App Group may not be working!")
            }
            
            // DEBUG: Check if standard UserDefaults works as fallback
            let standardDefaults = UserDefaults.standard
            standardDefaults.set(encoded, forKey: "fallback_\(favoritesKey)")
            standardDefaults.synchronize()
            print("🔍 FALLBACK: Also saved to standard UserDefaults as fallback")
            
            // ADDITIONAL FALLBACK: Save to shared file location
            saveToSharedFile(encoded)
            
            // Also save via SharedDataManager for Widget Extension access
            SharedDataManager.shared.saveFavoriteStations(favorites)
            print("🔍 Also saved via SharedDataManager")
            
            // Load departure data for widgets
            Task { @MainActor in
                await loadDepartureDataForWidgets()
            }
            
            // Send to Watch - let Watch handle widget updates
            watchConnectivityManager.updateFavorites(favorites)
            
            // Also explicitly trigger widget update
            watchConnectivityManager.triggerWidgetUpdate()
            
            // Reload iPhone widgets
            WidgetCenter.shared.reloadAllTimelines()
            print("🔍 Triggered widget reload")
        } else {
            print("🔍 Failed to encode favorites")
        }
    }
    
    private func saveToSharedFile(_ data: Data) {
        do {
            let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.federi.Next-Wave")
            if let sharedURL = groupURL?.appendingPathComponent("favorites.json") {
                try data.write(to: sharedURL)
                print("🔍 FILE FALLBACK: Saved to shared file: \(sharedURL.path)")
            } else {
                print("🔍 FILE FALLBACK: Could not get shared container URL")
            }
        } catch {
            print("🔍 FILE FALLBACK: Failed to save to shared file: \(error)")
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
    
    // Load departure data for widgets
    private func loadDepartureDataForWidgets() async {
        print("🔍 Loading departure data for widgets...")
        
        // For now, create placeholder departure data
        // The real departure loading will happen when the user opens the app
        var departureInfos: [DepartureInfo] = []
        
        for favorite in favorites {
            // Create a placeholder departure that indicates data needs to be loaded
            let placeholderDeparture = DepartureInfo(
                stationName: favorite.name,
                nextDeparture: Date().addingTimeInterval(3600), // 1 hour from now
                routeName: "Open App",
                direction: "to load departure times"
            )
            departureInfos.append(placeholderDeparture)
            print("🔍 Created placeholder for \(favorite.name)")
        }
        
        // Save placeholder data for widgets
        SharedDataManager.shared.saveNextDepartures(departureInfos)
        print("🔍 Saved \(departureInfos.count) placeholder departures for widgets")
        
        // Trigger widget reload
        WidgetCenter.shared.reloadAllTimelines()
        print("🔍 Triggered widget reload after creating placeholders")
    }
} 