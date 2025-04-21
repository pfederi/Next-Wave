import Foundation

class SharedDataManager {
    static let shared = SharedDataManager()
    
    private let userDefaults = UserDefaults(suiteName: "group.com.federi.Next-Wave")
    private let nextDeparturesKey = "nextDepartures"
    
    private init() {}
    
    func saveNextDepartures(_ departures: [DepartureInfo]) {
        if let encoded = try? JSONEncoder().encode(departures) {
            userDefaults?.set(encoded, forKey: nextDeparturesKey)
        }
    }
    
    func loadNextDepartures() -> [DepartureInfo] {
        guard let data = userDefaults?.data(forKey: nextDeparturesKey),
              let departures = try? JSONDecoder().decode([DepartureInfo].self, from: data) else {
            return []
        }
        return departures
    }
} 