import Foundation
import CoreLocation

class StationManager {
    static let shared = StationManager()
    
    private var allStations: [StationData] = []
    private let logger = WatchLogger.shared
    
    private init() {
        loadStationsFromJSON()
    }
    
    private func loadStationsFromJSON() {
        // Load stations from the same JSON file as the iOS app
        guard let url = Bundle.main.url(forResource: "stations", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            logger.error("❌ Failed to load stations.json file - no stations available")
            allStations = []
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let response = try decoder.decode(LakesResponse.self, from: data)
            
            // Convert Lake.Station to StationData
            allStations = response.lakes.flatMap { lake in
                lake.stations.compactMap { station in
                    guard let coordinates = station.coordinates else {
                        return nil // Skip stations without coordinates
                    }
                    return StationData(
                        id: station.id,
                        name: station.name,
                        latitude: coordinates.latitude,
                        longitude: coordinates.longitude,
                        uic_ref: station.uic_ref
                    )
                }
            }
            
            logger.info("🗄️ Loaded \(allStations.count) ferry stations from JSON with coordinates")
            
        } catch {
            logger.error("❌ Failed to decode stations.json: \(error) - no stations available")
            allStations = []
        }
    }
    
    func findNearestStation(to location: CLLocation) -> (station: StationData, distance: Double)? {
        // Check if stations are available
        guard !allStations.isEmpty else {
            logger.debug("🗺️ No stations available for nearest station calculation")
            return nil
        }
        
        var nearestStation: StationData?
        var shortestDistance = Double.infinity
        
        for station in allStations {
            let stationLocation = CLLocation(
                latitude: station.latitude,
                longitude: station.longitude
            )
            
            let distance = location.distance(from: stationLocation) / 1000 // Convert to kilometers
            if distance < shortestDistance {
                shortestDistance = distance
                nearestStation = station
            }
        }
        
        if let station = nearestStation {
            return (station: station, distance: shortestDistance)
        }
        
        return nil
    }
    
    // Helper property to check if stations are available
    var hasStations: Bool {
        return !allStations.isEmpty
    }
}

struct StationData {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let uic_ref: String?
}

// MARK: - JSON Structures (same as iOS app)
private struct LakesResponse: Codable {
    let lakes: [Lake]
}

private struct Lake: Codable {
    let name: String
    let operators: [String]
    private let _stations: [Station]
    
    var stations: [Station] {
        _stations
    }
    
    enum CodingKeys: String, CodingKey {
        case name
        case operators
        case _stations = "stations"
    }
    
    struct Station: Codable {
        let name: String
        let uic_ref: String?
        let coordinates: Coordinates?
        
        var id: String {
            if let ref = uic_ref {
                return "\(name)_\(ref)"
            }
            return name
        }
        
        init(from decoder: Decoder) throws {
            if let container = try? decoder.singleValueContainer(),
               let stationName = try? container.decode(String.self) {
                self.name = stationName
                self.uic_ref = nil
                self.coordinates = nil
            } else {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.name = try container.decode(String.self, forKey: .name)
                self.uic_ref = try container.decode(String?.self, forKey: .uic_ref)
                self.coordinates = try container.decodeIfPresent(Coordinates.self, forKey: .coordinates)
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case name
            case uic_ref
            case coordinates
        }
        
        struct Coordinates: Codable {
            let latitude: Double
            let longitude: Double
        }
    }
} 