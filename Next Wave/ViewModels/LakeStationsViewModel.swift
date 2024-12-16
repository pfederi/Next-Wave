import Foundation

class LakeStationsViewModel: ObservableObject {
    @Published var lakes: [Lake] = []
    @Published var selectedLake: Lake?
    @Published var selectedStation: Lake.Station?
    @Published var departures: [Journey] = []
    @Published var isTestMode: Bool = false
    @Published var journeyDetails: [String: [Journey.Stop]] = [:]
    @Published var expandedLakeId: String?
    @Published var selectedDate: Date = Date()
    @Published var isLoading = false
    private var isInitialLoad = true
    
    private let transportAPI = TransportAPI()
    
    init() {
        loadLakes()
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
    
    // Helper struct für JSON Dekodierung
    private struct LakesResponse: Codable {
        let lakes: [Lake]
    }
    
    func selectStation(_ station: Lake.Station) {
        selectedStation = station
        if let uicRef = station.uic_ref {
            Task {
                if !isInitialLoad {
                    isLoading = true
                }
                do {
                    let journeys = try await transportAPI.getStationboard(stationId: uicRef, for: selectedDate)
                    if !isInitialLoad {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                    DispatchQueue.main.async {
                        self.departures = journeys
                        self.isLoading = false
                        self.isInitialLoad = false
                    }
                } catch {
                    print("Error fetching departures: \(error)")
                    self.isLoading = false
                }
            }
        }
    }
    
    @MainActor
    func refreshDepartures() async {
        guard let station = selectedStation,
              let uicRef = station.uic_ref else { return }
        
        if !isInitialLoad {
            isLoading = true
        }
        do {
            let journeys = try await transportAPI.getStationboard(stationId: uicRef, for: selectedDate)
            if !isInitialLoad {
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
            self.departures = journeys
            self.isLoading = false
            self.isInitialLoad = false
        } catch {
            print("Error refreshing departures: \(error)")
            self.isLoading = false
        }
    }
        
    func loadJourneyDetails(for journey: Journey) {
        Task {
            do {
                let details = try await transportAPI.getJourneyDetails(for: journey)
                DispatchQueue.main.async {
                    self.journeyDetails[journey.id] = details.passList
                }
            } catch {
                print("Error loading journey details: \(error)")
            }
        }
    }
} 