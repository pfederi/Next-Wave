import Foundation
import SwiftUI
import WidgetKit

@MainActor
class WatchViewModel: ObservableObject {
    @Published var departures: [DepartureInfo] = []
    @Published var departuresByStation: [String: [DepartureInfo]] = [:]
    @Published var stationOrder: [String] = [] // Reihenfolge der Stationen wie in iOS-App
    @Published var isLoading = false
    @Published var error: Error?
    
    private let sharedDataManager = SharedDataManager.shared
    private let transportAPI = TransportAPI()
    private let logger = WatchLogger.shared
    private var timer: Timer?
    private var favoritesObserver: NSObjectProtocol?
    private var connectivityObserver: NSObjectProtocol?
    private var forceUpdateObserver: NSObjectProtocol?
    
    init() {
        logger.info("WatchViewModel initialized")
        setupFavoritesObserver()
        setupConnectivityObserver()
        setupForceUpdateObserver()
        startPeriodicUpdates()
    }
    
    deinit {
        timer?.invalidate()
        if let observer = favoritesObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = connectivityObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = forceUpdateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupFavoritesObserver() {
        favoritesObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults(suiteName: "group.com.federi.Next-Wave"),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.logger.debug("UserDefaults changed, updating departures")
                await self.updateDepartures()
                
                // Update widgets immediately
                WidgetCenter.shared.reloadAllTimelines()
                self.logger.debug("Triggered widget update from UserDefaults change")
            }
        }
    }
    
    private func setupConnectivityObserver() {
        connectivityObserver = NotificationCenter.default.addObserver(
            forName: .favoritesUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.logger.info("Favorites updated via WatchConnectivity, refreshing departures")
                await self.updateDepartures()
                
                // Update widgets immediately
                WidgetCenter.shared.reloadAllTimelines()
                self.logger.info("Triggered widget update from WatchConnectivity")
            }
        }
    }
    
    private func setupForceUpdateObserver() {
        forceUpdateObserver = NotificationCenter.default.addObserver(
            forName: .forceWidgetUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.logger.info("Force widget update requested from iOS")
                
                // Immediately reload timelines multiple times to force update
                for i in 0..<3 {
                    WidgetCenter.shared.reloadAllTimelines()
                    self.logger.debug("Force widget reload #\(i+1)")
                    
                    // Small delay between reloads
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                }
                
                // Also trigger data refresh
                await self.updateDepartures()
            }
        }
    }
    
    private func startPeriodicUpdates() {
        logger.info("Starting periodic updates")
        // Initial update
        Task {
            await updateDepartures()
        }
        
        // Update every minute
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.updateDepartures()
            }
        }
        logger.debug("Timer scheduled for updates every minute")
    }
    
    func updateDepartures() async {
        logger.info("Updating departures")
        isLoading = true
        error = nil
        
        // First try to load from shared storage
        let cachedDepartures = sharedDataManager.loadNextDepartures()
        if !cachedDepartures.isEmpty {
            logger.debug("Loaded \(cachedDepartures.count) cached departures")
            departures = cachedDepartures
            updateDeparturesByStation(cachedDepartures)
        } else {
            logger.debug("No cached departures found")
        }
        
        do {
            // Then fetch fresh data from API
            logger.debug("Fetching stations from API")
            let stations = try await transportAPI.fetchStations()
            logger.info("Found \(stations.count) favorite stations")
            
            var updatedDepartures: [DepartureInfo] = []
            let today = Date()
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
            
            for station in stations {
                logger.debug("Fetching journeys for station: \(station.name)")
                
                // Lade heutige Abfahrten
                var todayDepartures: [DepartureInfo] = []
                if let journeys = try? await transportAPI.fetchJourneys(for: station.id, date: today) {
                    logger.debug("Found \(journeys.count) journeys for \(station.name) today")
                    for journey in journeys {
                        if let departure = journey.stop.departure {
                            logger.debug("Raw departure string: '\(departure)'")
                            if let departureDate = AppDateFormatter.parseFullTime(departure) {
                                logger.debug("Successfully parsed date: \(departureDate)")
                            let departureInfo = DepartureInfo(
                                stationName: station.name,
                                nextDeparture: departureDate,
                                routeName: journey.fullName,
                                    direction: journey.bestDirection
                                )
                                todayDepartures.append(departureInfo)
                            } else {
                                logger.warning("Failed to parse departure: '\(departure)'")
                            }
                        } else {
                            logger.warning("No departure time for journey: \(journey)")
                        }
                    }
                }
                
                // Prüfe, ob es heute noch genug zukünftige Abfahrten gibt
                let futureTodayDepartures = todayDepartures.filter { $0.nextDeparture > today }
                
                if futureTodayDepartures.count < 3 {
                    // Weniger als 3 zukünftige Abfahrten heute -> lade morgen hinzu
                    logger.debug("Only \(futureTodayDepartures.count) future departures today for \(station.name), loading tomorrow")
                    if let tomorrowJourneys = try? await transportAPI.fetchJourneys(for: station.id, date: tomorrow) {
                        logger.debug("Found \(tomorrowJourneys.count) journeys for \(station.name) tomorrow")
                        for journey in tomorrowJourneys {
                            if let departure = journey.stop.departure {
                                logger.debug("Raw tomorrow departure string: '\(departure)'")
                                if let departureDate = AppDateFormatter.parseFullTime(departure) {
                                    logger.debug("Successfully parsed tomorrow date: \(departureDate)")
                                    // Adjust date to tomorrow
                                    let calendar = Calendar.current
                                    let tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                                    let timeComponents = calendar.dateComponents([.hour, .minute], from: departureDate)
                                    
                                    var fullComponents = DateComponents()
                                    fullComponents.year = tomorrowComponents.year
                                    fullComponents.month = tomorrowComponents.month
                                    fullComponents.day = tomorrowComponents.day
                                    fullComponents.hour = timeComponents.hour
                                    fullComponents.minute = timeComponents.minute
                                    
                                    if let tomorrowDepartureDate = calendar.date(from: fullComponents) {
                                        logger.debug("Final tomorrow departure date: \(tomorrowDepartureDate)")
                                        let departureInfo = DepartureInfo(
                                            stationName: station.name,
                                            nextDeparture: tomorrowDepartureDate,
                                            routeName: journey.fullName,
                                            direction: journey.bestDirection
                            )
                            updatedDepartures.append(departureInfo)
                                    } else {
                                        logger.error("Failed to create tomorrow departure date")
                    }
                } else {
                                    logger.warning("Failed to parse tomorrow departure: '\(departure)'")
                                }
                            } else {
                                logger.warning("No departure time for tomorrow journey: \(journey)")
                }
                        }
                    }
                }
                
                // Füge alle heutigen Abfahrten hinzu (egal ob es morgige gibt oder nicht)
                updatedDepartures.append(contentsOf: todayDepartures)
            }
            
            // Update the UI and cache
            logger.info("Updating UI with \(updatedDepartures.count) departures")
            departures = updatedDepartures
            updateDeparturesByStation(updatedDepartures)
            sharedDataManager.saveNextDepartures(updatedDepartures)
            
            // Update complications
            WidgetCenter.shared.reloadAllTimelines()
            logger.debug("Updated complications with new departure data")
            
        } catch {
            logger.error("Failed to update departures: \(error.localizedDescription)")
            self.error = error
        }
        
        isLoading = false
        logger.info("Departure update completed")
    }
    
    private func updateDeparturesByStation(_ departures: [DepartureInfo]) {
        // Group departures by station
        var grouped: [String: [DepartureInfo]] = [:]
        for departure in departures {
            grouped[departure.stationName, default: []].append(departure)
        }
        
        // Sort departures within each station
        for (station, stationDepartures) in grouped {
            grouped[station] = stationDepartures.sorted { $0.nextDeparture < $1.nextDeparture }
        }
        
        // Update the station order based on favorite stations order
        let favoriteStations = sharedDataManager.loadFavoriteStations()
        stationOrder = favoriteStations.map { $0.name }
        
        departuresByStation = grouped
        logger.debug("Grouped departures by \(grouped.count) stations in order: \(stationOrder)")
    }
} 