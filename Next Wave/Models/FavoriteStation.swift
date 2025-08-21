import Foundation
import WidgetKit
import UIKit

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
        
        // Setup background refresh notifications
        setupBackgroundRefresh()
    }
    
    private func setupBackgroundRefresh() {
        // Listen for app going to background to refresh widget data
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.loadDepartureDataForWidgets()
            }
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
    
    // Public method to refresh widget data
    func refreshWidgetData() async {
        await loadDepartureDataForWidgets()
    }
    
    // Load departure data for widgets
    private func loadDepartureDataForWidgets() async {
        print("🔍 Loading real departure data for widgets...")
        
        guard !favorites.isEmpty else {
            print("🔍 No favorites to load departure data for")
            return
        }
        
        let transportAPI = TransportAPI()
        var departureInfos: [DepartureInfo] = []
        
        for favorite in favorites {
            print("🔍 Loading departure data for \(favorite.name)...")
            
            // Try to get real departure data
            if let uicRef = favorite.uic_ref {
                do {
                    let journeys = try await transportAPI.getStationboard(stationId: uicRef, for: Date())
                    
                    // Find next 5 departures for widget support
                    let now = Date()
                    let nextJourneys = journeys
                        .compactMap({ journey -> (Date, Journey)? in
                            guard let departureStr = journey.stop.departure,
                                  let departureDate = AppDateFormatter.parseFullTime(departureStr) else { 
                                return nil 
                            }
                            return (departureDate, journey)
                        })
                        .filter({ $0.0 > now })
                        .sorted(by: { $0.0 < $1.0 })
                        .prefix(5) // Take next 5 departures for multiple widget support
                    
                    if !nextJourneys.isEmpty {
                        // Create departure info for each departure
                        for nextJourney in nextJourneys {
                            let departureInfo = DepartureInfo(
                                stationName: favorite.name,
                                nextDeparture: nextJourney.0,
                                routeName: nextJourney.1.name ?? "Boat",
                                direction: nextJourney.1.to ?? "Next Station"
                            )
                            departureInfos.append(departureInfo)
                        }
                        print("🔍 ✅ Found \(nextJourneys.count) departures for \(favorite.name)")
                    } else {
                        // No upcoming departures found - create placeholder
                        let placeholderDeparture = DepartureInfo(
                            stationName: favorite.name,
                            nextDeparture: Date().addingTimeInterval(3600), // 1 hour from now
                            routeName: "No Departures",
                            direction: "Check schedule"
                        )
                        departureInfos.append(placeholderDeparture)
                        print("🔍 ⚠️ No upcoming departures for \(favorite.name), created placeholder")
                    }
                } catch {
                    print("🔍 ❌ Failed to load departure data for \(favorite.name): \(error)")
                    
                    // Create error placeholder
                    let errorDeparture = DepartureInfo(
                        stationName: favorite.name,
                        nextDeparture: Date().addingTimeInterval(3600), // 1 hour from now
                        routeName: "Open App",
                        direction: "to load departures"
                    )
                    departureInfos.append(errorDeparture)
                }
            } else {
                print("🔍 ⚠️ No UIC reference for \(favorite.name), creating placeholder")
                
                // Create placeholder for stations without UIC reference
                let placeholderDeparture = DepartureInfo(
                    stationName: favorite.name,
                    nextDeparture: Date().addingTimeInterval(3600), // 1 hour from now
                    routeName: "Open App",
                    direction: "to load departures"
                )
                departureInfos.append(placeholderDeparture)
            }
        }
        
        // Save real/placeholder data for widgets
        SharedDataManager.shared.saveNextDepartures(departureInfos)
        print("🔍 Saved \(departureInfos.count) departure entries for widgets")
        
        // Trigger widget reload
        WidgetCenter.shared.reloadAllTimelines()
        print("🔍 Triggered widget reload after loading departure data")
    }
} 