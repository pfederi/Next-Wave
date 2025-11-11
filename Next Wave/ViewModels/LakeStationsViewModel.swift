import Foundation
import CoreLocation

@MainActor
class LakeStationsViewModel: ObservableObject, @unchecked Sendable {
    @Published var lakes: [Lake] = []
    @Published var selectedLake: Lake?
    @Published var selectedStation: Lake.Station? {
        didSet {
            if selectedStation?.id != oldValue?.id {
                hasAttemptedLoad = false
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
        print("🌊 [Alplakes] Starting to load water temperatures and forecasts...")
        
        // Load water levels from old API (MeteoNews)
        do {
            let temperatures = try await WaterTemperatureAPI.shared.getWaterTemperatures()
            print("🌊 [MeteoNews] Received \(temperatures.count) lake water levels")
            
            // Update lakes with water levels only
            for i in 0..<lakes.count {
                let lakeName = lakes[i].name
                if let temp = temperatures.first(where: { $0.name.lowercased() == lakeName.lowercased() }) {
                    var updatedLake = lakes[i]
                    updatedLake.waterLevel = temp.waterLevel
                    lakes[i] = updatedLake
                }
            }
        } catch {
            print("⚠️ [MeteoNews] Failed to load water levels: \(error)")
        }
        
        // Load temperature and forecasts from Alplakes
        do {
            var updatedCount = 0
            for i in 0..<lakes.count {
                let lakeName = lakes[i].name
                
                if let data = try await AlplakesAPI.shared.getTemperature(for: lakeName) {
                    var updatedLake = lakes[i]
                    updatedLake.waterTemperature = data.temperature
                    
                    // Convert forecast data to Lake.TemperatureForecast
                    if let forecast = data.forecast {
                        updatedLake.temperatureForecast = forecast.map { f in
                            Lake.TemperatureForecast(time: f.time, temperature: f.temperature)
                        }
                    }
                    
                    lakes[i] = updatedLake
                    updatedCount += 1
                    
                    let forecastInfo = data.forecast != nil ? " (+ \(data.forecast!.count) forecasts)" : ""
                    print("🌊 [Alplakes] Updated \(lakeName): \(data.temperature ?? 0)°C\(forecastInfo)")
                }
            }
            
            print("✅ [Alplakes] Updated \(updatedCount)/\(lakes.count) lakes with temperatures and forecasts")
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
              let uicRef = station.uic_ref else { return }
        
        isLoading = true
        error = nil
        
        let cacheKey = getCacheKey(for: station, date: selectedDate)
        if Calendar.current.isDateInToday(selectedDate),
           let cachedDepartures = departuresCache[cacheKey] {
            self.departures = []
            try? await Task.sleep(nanoseconds: 100_000_000)
            self.departures = cachedDepartures
            self.isLoading = false
            self.isInitialLoad = false
            self.hasAttemptedLoad = true
            return
        }
        
        do {
            let journeys = try await transportAPI.getStationboard(stationId: uicRef, for: selectedDate)
            if !isInitialLoad {
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
            
            if Calendar.current.isDateInToday(selectedDate) {
                departuresCache[cacheKey] = journeys
            }
            
            self.departures = journeys
            self.isLoading = false
            self.isInitialLoad = false
            self.hasAttemptedLoad = true
            self.error = nil
        } catch let apiError as TransportAPI.APIError {
            self.error = apiError.userMessage
            self.departures = []
            self.isLoading = false
            self.hasAttemptedLoad = true
        } catch {
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
        self.selectedStation = station
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