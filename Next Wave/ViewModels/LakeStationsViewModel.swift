import Foundation
import CoreLocation

@MainActor
class LakeStationsViewModel: ObservableObject, @unchecked Sendable {
    @Published var lakes: [Lake] = []
    @Published var selectedLake: Lake?
    @Published var selectedStation: Lake.Station? {
        didSet {
            if selectedStation?.id != oldValue?.id {
                // Don't reset hasAttemptedLoad here - it's managed in selectStation()
                scrolledToNext = false
            }
        }
    }
    @Published var nearestStation: (station: Lake.Station, distance: Double)?
    @Published var departures: [Journey] = []
    @Published var isTestMode: Bool = false
    @Published var journeyDetails: [String: [Journey.Stop]] = [:]
    @Published var expandedLakeId: String?
    @Published var selectedDate: Date = Date()
    @Published var isLoading = false
    @Published var hasAttemptedLoad = false
    @Published var scrolledToNext = false
    @Published var error: String?
    private var isInitialLoad = true
    
    private let transportAPI = TransportAPI()
    
    private var departuresCache: [String: [Journey]] = [:]
    private let cacheFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private var scheduleViewModel: ScheduleViewModel?
    
    private var midnightTimer: Timer?
    
    private let locationManager = LocationManager()
    
    // Background loading state for favorites
    private var isBackgroundLoadingFavorites = false
    private var backgroundLoadingTask: Task<Void, Never>?
    
    init(scheduleViewModel: ScheduleViewModel? = nil) {
        self.scheduleViewModel = scheduleViewModel
        Task {
            await loadLakes()
            // Start loading favorite stations in background immediately after lakes are loaded
            // (don't wait for water temperatures)
            loadFavoriteStationsInBackground()
            
            // Load water temperatures in parallel
            await loadWaterTemperatures()
        }
        scheduleMidnightRefresh()
        
        // Setup location updates
        locationManager.onLocationUpdate = { [weak self] _ in
            self?.updateNearestStation()
        }
        locationManager.requestLocationPermission()
        locationManager.startUpdatingLocation()
        updateNearestStation() // Initial update
    }
    
    deinit {
        midnightTimer?.invalidate()
    }
    
    private func scheduleMidnightRefresh() {
        midnightTimer?.invalidate()
        
        let calendar = Calendar.current
        let now = Date()
        
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
              let nextMidnight = calendar.date(bySettingHour: 0, minute: 0, second: 1, of: tomorrow) else {
            return
        }
        
        let timeInterval = nextMidnight.timeIntervalSince(now)
        
        DispatchQueue.main.async { [weak self] in
            self?.midnightTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.selectedDate = Date()
                    if self.selectedStation != nil {
                        await self.refreshDepartures()
                    }
                    self.scheduleMidnightRefresh()
                }
            }
            RunLoop.current.add(self?.midnightTimer ?? Timer(), forMode: .common)
        }
    }
    
    func loadLakes() async {
        guard let url = Bundle.main.url(forResource: "stations", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let response = try decoder.decode(LakesResponse.self, from: data)
            self.lakes = response.lakes
        } catch {
        }
    }
    
    func loadWaterTemperatures() async {
        print("🌊 Starting to load water data...")
        let startTime = Date()
        
        // Load water levels and temperature fallback from MeteoNews API
        var meteoNewsData: [String: MeteoNewsAPI.LakeWaterLevel] = [:]
        do {
            let waterLevels = try await MeteoNewsAPI.shared.getWaterLevels()
            print("🌊 [MeteoNews] Received \(waterLevels.count) lake water levels and temperature fallbacks")
            
            // Store MeteoNews data for fallback and update water levels
            for i in 0..<lakes.count {
                let lakeName = lakes[i].name
                if let level = waterLevels.first(where: { $0.name.lowercased() == lakeName.lowercased() }) {
                    meteoNewsData[lakeName] = level
                    
                    var updatedLake = lakes[i]
                    updatedLake.waterLevel = level.waterLevel
                    lakes[i] = updatedLake
                }
            }
        } catch {
            print("⚠️ [MeteoNews] Failed to load water levels: \(error)")
        }
        
        // Load temperature and forecasts from Alplakes (priority) - PARALLEL!
        await withTaskGroup(of: (Int, String, AlplakesAPI.LakeTemperatureData?).self) { group in
            // Create parallel tasks for all lakes
            for i in 0..<lakes.count {
                let lakeName = lakes[i].name
                group.addTask {
                    do {
                        let data = try await AlplakesAPI.shared.getTemperature(for: lakeName)
                        return (i, lakeName, data)
                    } catch {
                        return (i, lakeName, nil)
                    }
                }
            }
            
            var alplakesCount = 0
            var fallbackCount = 0
            
            // Collect results as they come in
            for await (index, lakeName, data) in group {
                var updatedLake = lakes[index]
                
                if let data = data {
                    // Alplakes data available
                    updatedLake.waterTemperature = data.temperature
                    
                    // Convert forecast data to Lake.TemperatureForecast
                    if let forecast = data.forecast {
                        updatedLake.temperatureForecast = forecast.map { f in
                            Lake.TemperatureForecast(time: f.time, temperature: f.temperature)
                        }
                    }
                    
                    alplakesCount += 1
                    let forecastInfo = data.forecast != nil ? " (+ \(data.forecast!.count) forecasts)" : ""
                    print("🌊 [Alplakes] Updated \(lakeName): \(data.temperature ?? 0)°C\(forecastInfo)")
                    
                } else if let meteoNews = meteoNewsData[lakeName], let temp = meteoNews.temperature {
                    // Fallback to MeteoNews temperature (no forecast available)
                    updatedLake.waterTemperature = temp
                    updatedLake.temperatureForecast = nil
                    fallbackCount += 1
                    print("🌊 [MeteoNews Fallback] Updated \(lakeName): \(temp)°C (no forecast)")
                }
                
                lakes[index] = updatedLake
            }
            
            let duration = Date().timeIntervalSince(startTime)
            print("✅ [Temperature] \(alplakesCount) from Alplakes (with forecast), \(fallbackCount) from MeteoNews (fallback) in \(String(format: "%.2f", duration))s")
        }
    }
    
    private struct LakesResponse: Codable {
        let lakes: [Lake]
    }
    
    private func getCacheKey(for station: Lake.Station, date: Date) -> String {
        let dateString = cacheFormatter.string(from: date)
        return "\(station.id)_\(dateString)"
    }
    
    // Helper function to get cache key for a station ID
    func getCacheKey(for stationId: String, date: Date) -> String {
        let dateString = cacheFormatter.string(from: date)
        return "\(stationId)_\(dateString)"
    }
    
    // Check if cached data exists for a cache key
    func hasCachedData(for cacheKey: String) -> Bool {
        return departuresCache[cacheKey] != nil
    }
    
    func refreshDepartures() async {
        guard let station = selectedStation,
              let uicRef = station.uic_ref else { 
            print("⚠️ [ViewModel] refreshDepartures: No station or uic_ref")
            return 
        }
        
        print("🔄 [ViewModel] Starting refresh for station: \(station.name), date: \(selectedDate)")
        isLoading = true
        error = nil
        
        let cacheKey = getCacheKey(for: station, date: selectedDate)
        
        // Check cache for today's data
        if Calendar.current.isDateInToday(selectedDate),
           let cachedDepartures = departuresCache[cacheKey] {
            print("✅ [ViewModel] Using cached departures (\(cachedDepartures.count) items)")
            self.departures = cachedDepartures
            self.isLoading = false
            self.isInitialLoad = false
            self.hasAttemptedLoad = true
            return
        }
        
        // Fetch fresh data
        do {
            print("🌐 [ViewModel] Fetching fresh departures from API...")
            let journeys = try await transportAPI.getStationboard(stationId: uicRef, for: selectedDate)
            
            // Small delay only for non-initial loads to avoid jarring UI updates
            if !isInitialLoad {
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
            
            // Cache today's data
            if Calendar.current.isDateInToday(selectedDate) {
                departuresCache[cacheKey] = journeys
            }
            
            print("✅ [ViewModel] Successfully loaded \(journeys.count) departures")
            self.departures = journeys
            self.isLoading = false
            self.isInitialLoad = false
            self.hasAttemptedLoad = true
            self.error = nil
        } catch let apiError as TransportAPI.APIError {
            print("❌ [ViewModel] API Error: \(apiError.userMessage)")
            self.error = apiError.userMessage
            self.departures = []
            self.isLoading = false
            self.hasAttemptedLoad = true
        } catch {
            print("❌ [ViewModel] Unexpected error: \(error)")
            self.error = "Ein unerwarteter Fehler ist aufgetreten"
            self.departures = []
            self.isLoading = false
            self.hasAttemptedLoad = true
        }
    }
    
    func loadJourneyDetails(for journey: Journey) {
        Task { @MainActor in
            do {
                let details = try await transportAPI.getJourneyDetails(for: journey)
                self.journeyDetails[journey.id] = details.passList
            }
        }
    }
    
    func selectStation(_ station: Lake.Station) {
        print("🎯 [ViewModel] Selecting station: \(station.name)")
        
        // IMPORTANT: Set loading state FIRST to prevent empty screen flicker
        self.isLoading = true
        self.error = nil
        self.hasAttemptedLoad = false
        
        // Then update the selected station
        self.selectedStation = station
        
        // Clear old data
        self.departures = []
        
        if let scheduleViewModel {
            scheduleViewModel.nextWaves = []
        }
        
        Task {
            await refreshDepartures()
        }
    }
    
    func appWillEnterForeground() {
        scheduleMidnightRefresh()
        Task {
            // Always reload water temperatures when app enters foreground
            await loadWaterTemperatures()
            
            // Only refresh departures if a station is selected
            if selectedStation != nil {
                await refreshDepartures()
            }
        }
    }
    
    func selectStation(withId id: String) {
        print("🎯 [ViewModel] Selecting station with ID: \(id)")
        
        // Find the station by ID
        guard let station = lakes.flatMap({ $0.stations }).first(where: { $0.id == id }) else {
            print("⚠️ [ViewModel] Station with ID \(id) not found")
            return
        }
        
        print("✅ [ViewModel] Found station: \(station.name) with ID: \(station.id)")
        
        // Reset to current date
        selectedDate = Date()
        
        // Use the proper selectStation method to ensure all state is set correctly
        selectStation(station)
    }
    
    func getNextDepartureForToday(for stationId: String) async -> Date? {
        guard let station = lakes.flatMap({ $0.stations }).first(where: { $0.id == stationId }),
              let uicRef = station.uic_ref else { 
            return nil 
        }
        
        let now = Date()
        
        // Check cache first
        let cacheKey = getCacheKey(for: station, date: now)
        if let cachedDepartures = departuresCache[cacheKey] {
            // Find next departure from cache
            if let nextDeparture = cachedDepartures
                .compactMap({ journey -> Date? in
                    guard let departureStr = journey.stop.departure else { return nil }
                    return AppDateFormatter.parseFullTime(departureStr)
                })
                .first(where: { $0 > now }) {
                return nextDeparture
            }
        }
        
        do {
            let journeys = try await transportAPI.getStationboard(stationId: uicRef, for: now)
            
            // Update cache
            departuresCache[cacheKey] = journeys
            
            // Find next departure from fresh data
            if let nextDeparture = journeys
                .compactMap({ journey -> Date? in
                    guard let departureStr = journey.stop.departure else { return nil }
                    return AppDateFormatter.parseFullTime(departureStr)
                })
                .first(where: { $0 > now }) {
                return nextDeparture
            }
        } catch {
            // Silently handle error
        }
        
        return nil
    }
    
    func hasDeparturesTomorrow(for stationId: String) async -> Bool {
        guard let station = lakes.flatMap({ $0.stations }).first(where: { $0.id == stationId }),
              let uicRef = station.uic_ref else { 
            return false 
        }
        
        // Get tomorrow's date
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        
        // Check cache first
        let cacheKey = getCacheKey(for: station, date: tomorrow)
        if let cachedDepartures = departuresCache[cacheKey], !cachedDepartures.isEmpty {
            return true
        }
        
        do {
            let journeys = try await transportAPI.getStationboard(stationId: uicRef, for: tomorrow)
            
            // Update cache
            departuresCache[cacheKey] = journeys
            
            return !journeys.isEmpty
        } catch {
            // Silently handle error
        }
        
        return false
    }

    func getNextDeparture(for stationId: String) async -> Date? {
        // For the StationView, use the selected date
        if let station = selectedStation, station.id == stationId {
            guard let station = lakes.flatMap({ $0.stations }).first(where: { $0.id == stationId }),
                  let uicRef = station.uic_ref else { 
                return nil 
            }
            
            let now = Date()
            
            // Check cache first
            let cacheKey = getCacheKey(for: station, date: selectedDate)
            if Calendar.current.isDateInToday(selectedDate),
               let cachedDepartures = departuresCache[cacheKey] {
                // Find next departure from cache
                if let nextDeparture = cachedDepartures
                    .compactMap({ journey -> Date? in
                        guard let departureStr = journey.stop.departure else { return nil }
                        return AppDateFormatter.parseFullTime(departureStr)
                    })
                    .first(where: { $0 > now }) {
                    return nextDeparture
                }
            }
            
            do {
                let journeys = try await transportAPI.getStationboard(stationId: uicRef, for: selectedDate)
                
                // Update cache if it's today
                if Calendar.current.isDateInToday(selectedDate) {
                    departuresCache[cacheKey] = journeys
                }
                
                // Find next departure from fresh data
                if let nextDeparture = journeys
                    .compactMap({ journey -> Date? in
                        guard let departureStr = journey.stop.departure else { return nil }
                        return AppDateFormatter.parseFullTime(departureStr)
                    })
                    .first(where: { $0 > now }) {
                    return nextDeparture
                }
            } catch {
                // Silently handle error
            }
            
            return nil
        }
        
        // For Favorites and Nearest Station, always use today's date
        return await getNextDepartureForToday(for: stationId)
    }
    
    private func updateNearestStation() {
        guard let userLocation = locationManager.userLocation else { return }
        
        var nearestStation: Lake.Station?
        var shortestDistance = Double.infinity
        
        for lake in lakes {
            for station in lake.stations {
                guard let coordinates = station.coordinates else { continue }
                
                let stationLocation = CLLocation(
                    latitude: coordinates.latitude,
                    longitude: coordinates.longitude
                )
                
                let distance = userLocation.distance(from: stationLocation) / 1000 // Convert to kilometers
                if distance < shortestDistance {
                    shortestDistance = distance
                    nearestStation = station
                }
            }
        }
        
        if let station = nearestStation {
            self.nearestStation = (station: station, distance: shortestDistance)
            
            // Share nearest station with Widget/Watch
            let nearestFavoriteStation = FavoriteStation(
                id: station.id,
                name: station.name,
                latitude: station.coordinates?.latitude,
                longitude: station.coordinates?.longitude,
                uic_ref: station.uic_ref
            )
            SharedDataManager.shared.saveNearestStation(nearestFavoriteStation)
        }
    }
    
    func setScheduleViewModel(_ viewModel: ScheduleViewModel) {
        self.scheduleViewModel = viewModel
    }
    
    // Load favorite stations in background sequentially (top to bottom)
    func loadFavoriteStationsInBackground() {
        // Cancel any existing background loading task
        backgroundLoadingTask?.cancel()
        
        // Don't start if already loading or if a station is selected
        guard !isBackgroundLoadingFavorites, selectedStation == nil else {
            return
        }
        
        let favorites = FavoriteStationsManager.shared.favorites
        guard !favorites.isEmpty else {
            return
        }
        
        isBackgroundLoadingFavorites = true
        
        backgroundLoadingTask = Task { @MainActor in
            // OPTIMIZATION: Only load first 2 favorites immediately for fast app start
            // The rest will be loaded on-demand when tiles appear
            let priorityFavorites = Array(favorites.prefix(2))
            print("🔄 [Background] Loading priority favorites: \(priorityFavorites.map { $0.name }.joined(separator: ", "))")
            
            // Load priority favorites sequentially
            for favorite in priorityFavorites {
                // Check if task was cancelled
                if Task.isCancelled {
                    break
                }
                
                // Don't load if a station was selected (user navigated away)
                if selectedStation != nil {
                    break
                }
                
                guard let uicRef = favorite.uic_ref else {
                    continue
                }
                
                do {
                    let today = Date()
                    let cacheKey = "\(favorite.id)_\(cacheFormatter.string(from: today))"
                    
                    // Only load if not already cached
                    if departuresCache[cacheKey] == nil {
                        print("🔄 [Background] Loading departures for favorite: \(favorite.name)")
                        let journeys = try await transportAPI.getStationboard(stationId: uicRef, for: today)
                        
                        // Cache the data
                        departuresCache[cacheKey] = journeys
                        print("✅ [Background] Cached \(journeys.count) departures for \(favorite.name)")
                        
                        // Notify that data is available for this station
                        NotificationCenter.default.post(
                            name: NSNotification.Name("StationDataLoaded"),
                            object: nil,
                            userInfo: ["stationId": favorite.id]
                        )
                    } else {
                        print("✅ [Background] Using cached data for \(favorite.name)")
                    }
                } catch {
                    print("⚠️ [Background] Failed to load departures for \(favorite.name): \(error)")
                    // Continue with next favorite even if this one fails
                }
                
                // Small delay between stations to avoid overwhelming the API
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            }
            
            // After priority favorites, load remaining favorites with lower priority
            let remainingFavorites = Array(favorites.dropFirst(2))
            if !remainingFavorites.isEmpty {
                print("🔄 [Background] Loading remaining favorites: \(remainingFavorites.map { $0.name }.joined(separator: ", "))")
                
                // Add a longer delay before loading remaining favorites
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                for favorite in remainingFavorites {
                    // Check if task was cancelled
                    if Task.isCancelled {
                        break
                    }
                    
                    // Don't load if a station was selected (user navigated away)
                    if selectedStation != nil {
                        break
                    }
                    
                    guard let uicRef = favorite.uic_ref else {
                        continue
                    }
                    
                    do {
                        let today = Date()
                        let cacheKey = "\(favorite.id)_\(cacheFormatter.string(from: today))"
                        
                        // Only load if not already cached
                        if departuresCache[cacheKey] == nil {
                            print("🔄 [Background] Loading departures for: \(favorite.name)")
                            let journeys = try await transportAPI.getStationboard(stationId: uicRef, for: today)
                            
                            // Cache the data
                            departuresCache[cacheKey] = journeys
                            print("✅ [Background] Cached \(journeys.count) departures for \(favorite.name)")
                            
                            // Notify that data is available for this station
                            NotificationCenter.default.post(
                                name: NSNotification.Name("StationDataLoaded"),
                                object: nil,
                                userInfo: ["stationId": favorite.id]
                            )
                        } else {
                            print("✅ [Background] Using cached data for \(favorite.name)")
                        }
                    } catch {
                        print("⚠️ [Background] Failed to load departures for \(favorite.name): \(error)")
                    }
                    
                    // Longer delay for remaining favorites
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                }
            }
            
            isBackgroundLoadingFavorites = false
            print("✅ [Background] Finished loading all favorite stations")
        }
    }
    
    // Cancel background loading if needed
    func cancelBackgroundLoading() {
        backgroundLoadingTask?.cancel()
        backgroundLoadingTask = nil
        isBackgroundLoadingFavorites = false
    }
    
    // Check if background loading is in progress
    func isBackgroundLoadingInProgress() -> Bool {
        return isBackgroundLoadingFavorites
    }
} 