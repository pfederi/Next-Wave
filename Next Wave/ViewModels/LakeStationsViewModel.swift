import Foundation

@MainActor
class LakeStationsViewModel: ObservableObject, @unchecked Sendable {
    @Published var lakes: [Lake] = []
    @Published var selectedLake: Lake?
    @Published var selectedStation: Lake.Station? {
        didSet {
            if selectedStation?.id != oldValue?.id {
                hasAttemptedLoad = false    // Reset load attempt
                scrolledToNext = false      // Reset scroll state
            }
        }
    }
    @Published var departures: [Journey] = []
    @Published var isTestMode: Bool = false
    @Published var journeyDetails: [String: [Journey.Stop]] = [:]
    @Published var expandedLakeId: String?
    @Published var selectedDate: Date = Date()
    @Published var isLoading = false
    @Published var hasAttemptedLoad = false
    @Published var scrolledToNext = false  // Remove private(set)
    private var isInitialLoad = true
    
    private let transportAPI = TransportAPI()
    
    private var departuresCache: [String: [Journey]] = [:]  // [stationId_date: departures]
    private let cacheFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private let scheduleViewModel: ScheduleViewModel
    
    private var midnightTimer: Timer?
    
    init(scheduleViewModel: ScheduleViewModel) {
        self.scheduleViewModel = scheduleViewModel
        loadLakes()
        scheduleMidnightRefresh()
    }
    
    deinit {
        midnightTimer?.invalidate()
    }
    
    private func scheduleMidnightRefresh() {
        // Cancel existing timer if any
        midnightTimer?.invalidate()
        
        // Calculate time until next midnight
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
              let nextMidnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow) else {
            return
        }
        
        let timeInterval = nextMidnight.timeIntervalSinceNow
        
        // Schedule timer
        midnightTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.selectedDate = Date()  // Reset to current date
                if self.selectedStation != nil {
                    await self.refreshDepartures()
                }
                // Schedule next midnight refresh
                self.scheduleMidnightRefresh()
            }
        }
    }
    
    private func loadLakes() {
        guard let url = Bundle.main.url(forResource: "lakes", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("Could not find lakes.json")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let response = try decoder.decode(LakesResponse.self, from: data)
            self.lakes = response.lakes
        } catch {
            print("Error decoding lakes data: \(error)")
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
        
        // Check cache for current day
        let cacheKey = getCacheKey(for: station, date: selectedDate)
        if Calendar.current.isDateInToday(selectedDate),
           let cachedDepartures = departuresCache[cacheKey] {
            self.departures = []  // Clear first
            try? await Task.sleep(nanoseconds: 100_000_000)  // Wait a bit
            self.departures = cachedDepartures  // Then set cached data
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
            
            // Cache if it's today
            if Calendar.current.isDateInToday(selectedDate) {
                departuresCache[cacheKey] = journeys
            }
            
            self.departures = journeys
            self.isLoading = false
            self.isInitialLoad = false
            self.hasAttemptedLoad = true
        } catch {
            print("Error refreshing departures: \(error)")
            self.isLoading = false
            self.hasAttemptedLoad = true
        }
    }
    
    func loadJourneyDetails(for journey: Journey) {
        Task { @MainActor in
            do {
                let details = try await transportAPI.getJourneyDetails(for: journey)
                self.journeyDetails[journey.id] = details.passList
            } catch {
                print("Error loading journey details: \(error)")
            }
        }
    }
    
    func selectStation(_ station: Lake.Station) {
        self.selectedStation = station
        self.departures = []  // Clear departures immediately
        scheduleViewModel.nextWaves = []  // Clear waves immediately
        Task {
            await refreshDepartures()
        }
    }
} 