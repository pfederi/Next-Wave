import Foundation
import SwiftUI
import WidgetKit
import Combine

@MainActor
class WatchViewModel: ObservableObject {
    @Published var departures: [DepartureInfo] = []
    @Published var departuresByStation: [String: [DepartureInfo]] = [:]
    @Published var stationOrder: [String] = [] // Reihenfolge der Stationen wie in iOS-App
    @Published var isLoading = false
    @Published var error: Error?
    @Published var refreshTrigger = Date() // Force UI refresh every 30 seconds
    @Published var nearestStation: FavoriteStation? = nil
    @Published var useNearestStationForWidget: Bool = false
    
    private let sharedDataManager = SharedDataManager.shared
    private let transportAPI = TransportAPI()
    private let logger = WatchLogger.shared
    private let locationManager = WatchLocationManager()
    private var timer: Timer?
    private var uiRefreshTimer: Timer?
    private var favoritesObserver: NSObjectProtocol?
    private var connectivityObserver: NSObjectProtocol?
    private var forceUpdateObserver: NSObjectProtocol?
    private var widgetSettingsObserver: NSObjectProtocol?
    private var contextUpdateObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        logger.info("WatchViewModel initialized")
        setupFavoritesObserver()
        setupConnectivityObserver()
        setupForceUpdateObserver()
        setupWidgetSettingsObserver()
        setupLocationObserver()
        loadWidgetSettings()
        startLocationServices()
        startPeriodicUpdates()
        startUIRefreshTimer()
        
        // Debug: Listen for any application context changes
        contextUpdateObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ApplicationContextUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.loadWidgetSettings()
            }
        }
    }
    
    deinit {
        timer?.invalidate()
        uiRefreshTimer?.invalidate()
        cancellables.removeAll()
        
        // Stop location updates directly without Task
        let localLocationManager = locationManager
        DispatchQueue.main.async {
            localLocationManager.stopLocationUpdates()
        }
        
        if let observer = favoritesObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = connectivityObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = forceUpdateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = widgetSettingsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = contextUpdateObserver {
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
    
    private func setupWidgetSettingsObserver() {
        widgetSettingsObserver = NotificationCenter.default.addObserver(
            forName: .widgetSettingsUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.logger.info("Widget settings updated via WatchConnectivity, reloading")
                self.loadWidgetSettings()
                
                // Update widgets immediately
                WidgetCenter.shared.reloadAllTimelines()
                self.logger.info("Triggered widget update from widget settings change")
            }
        }
    }
    
    private func startPeriodicUpdates() {
        logger.info("Starting periodic updates")
        // Initial update
        Task {
            await updateDepartures()
        }
        
        // Start with smart adaptive updates
        scheduleNextUpdate()
        logger.debug("Started adaptive update scheduling")
    }
    
    private func startUIRefreshTimer() {
        logger.info("Starting UI refresh timer")
        
        // Timer to force UI refresh every 30 seconds to update minute counters
        uiRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // Force UI refresh by updating refresh trigger
                self.refreshTrigger = Date()
                self.logger.debug("UI refreshed for minute counter updates")
            }
        }
        logger.debug("UI refresh timer scheduled for every 30 seconds")
    }
    
    private func setupLocationObserver() {
        // Observe location manager's nearest station updates
        locationManager.$nearestStation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newNearestStation in
                guard let self = self else { return }
                if let station = newNearestStation {
                    let previousStation = self.nearestStation
                    self.nearestStation = station
                    self.logger.info("Location manager found new nearest station: \(station.name)")
                    print("🔧 WatchViewModel: Location manager found new nearest station: \(station.name)")
                    
                    // If the nearest station actually changed, update departures
                    if previousStation?.name != station.name {
                        self.logger.info("Nearest station changed from '\(previousStation?.name ?? "none")' to '\(station.name)' - updating departures")
                        Task {
                            await self.updateDepartures()
                        }
                    }
                    
                    // Update widgets when nearest station changes
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
            .store(in: &cancellables)
    }
    
    private func startLocationServices() {
        logger.info("Starting location services for nearest station detection")
        print("🔧 WatchViewModel: Starting location services")
        
        // Start location updates if needed
        if useNearestStationForWidget {
            locationManager.startLocationUpdates()
            // Also request immediate location update
            locationManager.requestLocation()
        }
    }
    
    private func loadWidgetSettings() {
        let settings = sharedDataManager.loadWidgetSettings()
        let previousUseNearestStation = useNearestStationForWidget
        useNearestStationForWidget = settings.useNearestStation
        
        // Update nearest station from location manager if available
        if let locationNearestStation = locationManager.nearestStation {
            nearestStation = locationNearestStation
        } else {
            // Fallback to saved nearest station
            nearestStation = sharedDataManager.loadNearestStation()
        }
        
        logger.info("Widget settings loaded - useNearestStation: \(useNearestStationForWidget)")
        print("🔧 WatchViewModel: Widget settings loaded - useNearestStation: \(useNearestStationForWidget)")
        
        // Start/stop location updates based on settings change
        if useNearestStationForWidget != previousUseNearestStation {
            if useNearestStationForWidget {
                logger.info("Starting location updates for nearest station")
                locationManager.startLocationUpdates()
                // Also request immediate location update
                locationManager.requestLocation()
            } else {
                logger.info("Stopping location updates - nearest station disabled")
                locationManager.stopLocationUpdates()
            }
        }
        
        if let nearest = nearestStation {
            logger.info("Nearest station: \(nearest.name)")
            print("🔧 WatchViewModel: Nearest station: \(nearest.name)")
        } else {
            print("🔧 WatchViewModel: No nearest station found")
            // If we need nearest station but don't have one, request location
            if useNearestStationForWidget {
                locationManager.requestLocation()
            }
        }
    }
    
    private func scheduleNextUpdate() {
        timer?.invalidate()
        
        let updateInterval = calculateOptimalUpdateInterval()
        logger.info("Scheduling next API update in \(updateInterval) seconds")
        
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.updateDepartures()
                // Schedule next update after this one completes
                self.scheduleNextUpdate()
            }
        }
    }
    
    private func calculateOptimalUpdateInterval() -> TimeInterval {
        let cachedDepartures = sharedDataManager.loadNextDepartures()
        let now = Date()
        
        // Find the next departure
        let nextDeparture = cachedDepartures
            .filter { $0.nextDeparture > now }
            .sorted { $0.nextDeparture < $1.nextDeparture }
            .first
        
        guard let departure = nextDeparture else {
            // No departures found - check every 2 hours
            logger.debug("No upcoming departures - scheduling update in 2 hours")
            return 7200 // 2 hours
        }
        
        let minutesUntilDeparture = departure.nextDeparture.timeIntervalSince(now) / 60
        
        // Adaptive frequency based on next departure
        switch minutesUntilDeparture {
        case ...10:
            // Very soon - every 2 minutes for real-time delays
            return 120
        case 11...30:
            // Soon - every 5 minutes
            return 300
        case 31...120:
            // Within 2 hours - every 15 minutes
            return 900
        case 121...360:
            // Within 6 hours - every 30 minutes
            return 1800
        default:
            // More than 6 hours away - every 2 hours
            return 7200
        }
    }
    
    func refreshLocation() {
        guard useNearestStationForWidget else { return }
        logger.info("Manual location refresh requested")
        locationManager.requestLocation()
    }
    
    func refreshLocationAndDepartures() async {
        logger.info("Manual refresh: updating location and departures")
        
        // First refresh location if using nearest station
        if useNearestStationForWidget {
            locationManager.requestLocation()
            
            // Give location manager a moment to update
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        // Then update departures with potentially updated nearest station
        await updateDepartures()
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
            let favoriteStations = try await transportAPI.fetchStations()
            logger.info("Found \(favoriteStations.count) favorite stations")
            
            // Add nearest station if it's not already in favorites and if we use nearest station
            var allStationsToFetch = favoriteStations
            if useNearestStationForWidget, 
               let nearest = nearestStation,
               !favoriteStations.contains(where: { $0.name == nearest.name }) {
                // Create a station object for the nearest station
                let nearestStationForAPI = Station(
                    id: nearest.id,
                    name: nearest.name,
                    latitude: nearest.latitude,
                    longitude: nearest.longitude,
                    uic_ref: nearest.uic_ref
                )
                allStationsToFetch.append(nearestStationForAPI)
                logger.info("Added nearest station '\(nearest.name)' to departure fetch list")
            }
            
            var updatedDepartures: [DepartureInfo] = []
            let today = Date()
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
            
            for station in allStationsToFetch {
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