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
    
    init(scheduleViewModel: ScheduleViewModel? = nil) {
        self.scheduleViewModel = scheduleViewModel
        Task {
            await loadLakes()
            // Load water temperatures immediately after lakes are loaded
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
        
        // Load temperature and forecasts from Alplakes (priority)
        do {
            var alplakesCount = 0
            var fallbackCount = 0
            
            for i in 0..<lakes.count {
                let lakeName = lakes[i].name
                var updatedLake = lakes[i]
                
                // Try Alplakes first
                if let data = try await AlplakesAPI.shared.getTemperature(for: lakeName) {
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
                
                lakes[i] = updatedLake
            }
            
            print("✅ [Temperature] \(alplakesCount) from Alplakes (with forecast), \(fallbackCount) from MeteoNews (fallback)")
        } catch {
            print("⚠️ [Alplakes] Failed to load temperatures: \(error)")
            if let urlError = error as? URLError {
                print("⚠️ URLError code: \(urlError.code.rawValue)")
            }
        }
    }
    
    private struct LakesResponse: Codable {
        let lakes: [Lake]
    }
    
    private func getCacheKey(for station: Lake.Station, date: Date) -> String {
        let dateString = cacheFormatter.string(from: date)
        return "\(station.id)_\(dateString)"
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
        selectedStation = lakes.flatMap { $0.stations }.first { $0.id == id }
        if selectedStation != nil {
            selectedDate = Date() // Reset to current date
            Task {
                await refreshDepartures()
            }
        }
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
} 