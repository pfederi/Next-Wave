import Foundation

class LakeStationsViewModel: ObservableObject {
    @Published var lakes: [Lake] = []
    @Published var selectedLake: Lake?
    @Published var selectedStation: Lake.Station?
    @Published var departures: [Journey] = []
    @Published var isTestMode: Bool = false
    @Published var journeyDetails: [String: [Journey.Stop]] = [:]
    @Published var expandedLakeId: String?
    
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
                do {
                    let journeys = try await transportAPI.getStationboard(stationId: uicRef)
                    DispatchQueue.main.async {
                        self.departures = journeys
                    }
                } catch {
                    print("Error fetching departures: \(error)")
                }
            }
        }
    }
    
    @MainActor
    func refreshDepartures() async {
        if let station = selectedStation,
           let uicRef = station.uic_ref {
            do {
                let journeys = try await transportAPI.getStationboard(stationId: uicRef)
                self.departures = journeys
            } catch {
                print("Error refreshing departures: \(error)")
            }
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