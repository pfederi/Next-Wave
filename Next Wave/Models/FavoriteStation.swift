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
    
    private var widgetReloadTask: Task<Void, Never>?

    private func saveFavorites() {
        guard let encoded = try? JSONEncoder().encode(favorites) else { return }

        // Primary store.
        userDefaults?.set(encoded, forKey: favoritesKey)

        // Widget data redundancy — all three ARE read by the widget extension
        // (App Group UserDefaults can be unreliable):
        UserDefaults.standard.set(encoded, forKey: "fallback_\(favoritesKey)")
        saveToSharedFile(encoded)
        SharedDataManager.shared.saveFavoriteStations(favorites)

        // Coalesce the network-heavy widget data load across rapid mutations
        // (e.g. several add/remove/reorder actions in quick succession).
        widgetReloadTask?.cancel()
        widgetReloadTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            if Task.isCancelled { return }
            await self?.loadDepartureDataForWidgets()
        }

        // Notify Watch + reload widgets (cheap).
        watchConnectivityManager.updateFavorites(favorites)
        watchConnectivityManager.triggerWidgetUpdate()
        WidgetCenter.shared.reloadAllTimelines()
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
    func loadDepartureDataForWidgets() async {
        print("🔍 Loading real departure data for widgets...")
        
        var stationsToLoad = favorites
        
        // Add nearest station if widget is configured to use it and it's not already in favorites
        let widgetSettings = SharedDataManager.shared.loadWidgetSettings()
        if widgetSettings.useNearestStation,
           let nearestStation = SharedDataManager.shared.loadNearestStation(),
           !favorites.contains(where: { $0.name == nearestStation.name }) {
            stationsToLoad.append(nearestStation)
            print("🔍 Added nearest station '\(nearestStation.name)' to widget data loading")
        }
        
        guard !stationsToLoad.isEmpty else {
            print("🔍 No stations to load departure data for")
            return
        }
        
        let transportAPI = TransportAPI()
        var departureInfos: [DepartureInfo] = []
        
        for favorite in stationsToLoad {
            print("🔍 Loading departure data for \(favorite.name)...")
            
                         // Try to get real departure data
             if let uicRef = favorite.uic_ref {
                 do {
                     let now = Date()
                     let calendar = Calendar.current
                     
                     // Load today's departures (use higher limit for widgets)
                     let todayJourneys = try await transportAPI.getStationboard(stationId: uicRef, for: now, limit: 50)
                     print("🔍 API returned \(todayJourneys.count) journeys for today for \(favorite.name)")
                     
                     // Get today's future departures
                     let todayDepartures = todayJourneys
                         .compactMap({ journey -> (Date, Journey)? in
                             guard let departureStr = journey.stop.departure,
                                   let departureDate = AppDateFormatter.parseFullTime(departureStr) else { 
                                 return nil 
                             }
                             return (departureDate, journey)
                         })
                         .filter({ $0.0 > now })
                         .sorted(by: { $0.0 < $1.0 })
                     
                     var allDepartures = Array(todayDepartures)
                     print("🔍 \(favorite.name): \(todayDepartures.count) valid future departures today")
                     
                     // If we have less than desired departures for today, load tomorrow's as well
                     let minDeparturesBeforeLoadingNextDay = 15 // Load tomorrow if less than 15 today
                     if allDepartures.count < minDeparturesBeforeLoadingNextDay {
                         print("🔍 Only \(allDepartures.count) departures today for \(favorite.name), loading tomorrow's as well (want \(minDeparturesBeforeLoadingNextDay)+)")
                         
                         let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
                         let tomorrowJourneys = try await transportAPI.getStationboard(stationId: uicRef, for: tomorrow, limit: 50)
                         print("🔍 API returned \(tomorrowJourneys.count) journeys for tomorrow for \(favorite.name)")
                         
                         let tomorrowDepartures = tomorrowJourneys
                             .compactMap({ journey -> (Date, Journey)? in
                                 guard let departureStr = journey.stop.departure,
                                       let departureDate = AppDateFormatter.parseFullTime(departureStr) else { 
                                     return nil 
                                 }
                                 return (departureDate, journey)
                             })
                             .sorted(by: { $0.0 < $1.0 })
                         
                         // Add tomorrow's departures to fill up to desired total
                         let maxDeparturesPerStation = 25 // Match ContentView.swift setting
                         let remainingSlots = maxDeparturesPerStation - allDepartures.count
                         allDepartures.append(contentsOf: Array(tomorrowDepartures.prefix(remainingSlots)))
                         
                         print("🔍 Added \(min(remainingSlots, tomorrowDepartures.count)) departures from tomorrow")
                         
                         // If we still don't have enough departures, load day after tomorrow
                         if allDepartures.count < maxDeparturesPerStation {
                             print("🔍 Still need more departures for \(favorite.name) (\(allDepartures.count)/\(maxDeparturesPerStation)), loading day after tomorrow")
                             
                             let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: now) ?? now
                             do {
                                 let dayAfterJourneys = try await transportAPI.getStationboard(stationId: uicRef, for: dayAfterTomorrow, limit: 50)
                                 print("🔍 API returned \(dayAfterJourneys.count) journeys for day after tomorrow for \(favorite.name)")
                                 
                                 let dayAfterDepartures = dayAfterJourneys
                                     .compactMap({ journey -> (Date, Journey)? in
                                         guard let departureStr = journey.stop.departure,
                                               let departureDate = AppDateFormatter.parseFullTime(departureStr) else { 
                                             return nil 
                                         }
                                         return (departureDate, journey)
                                     })
                                     .sorted(by: { $0.0 < $1.0 })
                                 
                                 let finalRemainingSlots = maxDeparturesPerStation - allDepartures.count
                                 allDepartures.append(contentsOf: Array(dayAfterDepartures.prefix(finalRemainingSlots)))
                                 
                                 print("🔍 Added \(min(finalRemainingSlots, dayAfterDepartures.count)) departures from day after tomorrow")
                             } catch {
                                 print("🔍 Error loading day after tomorrow's departures for \(favorite.name): \(error)")
                             }
                         }
                     }
                     
                     let maxDeparturesPerStation = 25 // Match ContentView.swift setting
                     let nextJourneys = allDepartures.prefix(maxDeparturesPerStation) // Take up to 25 departures total
                     print("🔍 Station \(favorite.name): Using \(nextJourneys.count) departures from total \(allDepartures.count) available (max: \(maxDeparturesPerStation))")
                    
                                         if !nextJourneys.isEmpty {
                         // Create departure info for each departure
                         for nextJourney in nextJourneys {
                             let journey = nextJourney.1
                             
                             // Better direction logic using passList
                             let direction: String
                             if let passList = journey.passList,
                                passList.count > 1,
                                let nextStation = passList.dropFirst().first {
                                 direction = nextStation.station.name ?? journey.to ?? "Next Station"
                             } else {
                                 direction = journey.to ?? "Next Station"
                             }
                             
                             let departureInfo = DepartureInfo(
                                 stationName: favorite.name,
                                 nextDeparture: nextJourney.0,
                                 routeName: journey.name ?? "Boat",
                                 direction: direction
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
        
        // Save timestamp of data refresh for widget message logic
        let userDefaults = UserDefaults(suiteName: "group.com.federi.Next-Wave")
        userDefaults?.set(Date(), forKey: "last_data_refresh")
        
        print("🔍 Saved \(departureInfos.count) departure entries for widgets")
        
        // Trigger widget reload
        WidgetCenter.shared.reloadAllTimelines()
        print("🔍 Triggered widget reload after loading departure data")
    }
} 