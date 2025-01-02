import Foundation

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
    
    private let scheduleViewModel: ScheduleViewModel
    
    private var midnightTimer: Timer?
    
    init(scheduleViewModel: ScheduleViewModel) {
        self.scheduleViewModel = scheduleViewModel
        loadLakes()
        scheduleMidnightRefresh()
    }
    
    init() {
        self.scheduleViewModel = ScheduleViewModel()
        self.selectedDate = Date()
        loadLakes()
        scheduleMidnightRefresh()
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
            print("Failed to calculate next midnight")
            return
        }
        
        let timeInterval = nextMidnight.timeIntervalSince(now)
        print("Scheduling midnight refresh in \(timeInterval) seconds")
        
        DispatchQueue.main.async { [weak self] in
            self?.midnightTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
                print("Midnight refresh triggered")
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
    
    private func loadLakes() {
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
        scheduleViewModel.nextWaves = []
        Task {
            await refreshDepartures()
        }
    }
    
    func appWillEnterForeground() {
        scheduleMidnightRefresh()
        if selectedStation != nil {
            Task {
                await refreshDepartures()
            }
        }
    }
} 