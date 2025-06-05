import Foundation

class TransportAPI {
    private let baseURL = "https://transport.opendata.ch/v1"
    private let logger = WatchLogger.shared
    
    func fetchStations() async throws -> [Station] {
        logger.debug("Loading favorite stations")
        // Use favorite stations from SharedDataManager
        let favorites = SharedDataManager.shared.loadFavoriteStations()
        logger.info("Loaded \(favorites.count) favorite stations")
        return favorites.map { Station(
            id: $0.id,
            name: $0.name,
            latitude: $0.latitude,
            longitude: $0.longitude,
            uic_ref: $0.uic_ref
        ) }
    }
    
    func fetchJourneys(for stationId: String, date: Date) async throws -> [Journey] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        // Extract UIC reference from stationId if it contains underscore
        let uicRef: String
        if stationId.contains("_") {
            uicRef = String(stationId.split(separator: "_").last ?? "")
        } else {
            uicRef = stationId
        }
        
        guard let url = URL(string: "\(baseURL)/stationboard?id=\(uicRef)&limit=100&date=\(dateString)") else {
            logger.error("Failed to create URL for station \(stationId)")
            throw URLError(.badURL)
        }
        
        logger.debug("Fetching journeys from: \(url.absoluteString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response type for station \(stationId)")
                throw URLError(.badServerResponse)
            }
            
            logger.debug("Received response with status code: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                logger.error("Bad response (\(httpResponse.statusCode)) for station \(stationId)")
                throw URLError(.badServerResponse)
            }
            
            let decoder = JSONDecoder()
            let result = try decoder.decode(StationboardResponse.self, from: data)
            
            // Filter for boat journeys with passList (same as iOS)
            let filteredJourneys = result.stationboard.filter { journey in
                if journey.category == "BAT",
                   let passList = journey.passList,
                   !passList.isEmpty {
                    return true
                }
                return false
            }
            
            logger.info("Successfully decoded \(filteredJourneys.count) boat departures for station \(stationId)")
            return filteredJourneys
        } catch {
            logger.error("Failed to fetch journeys for station \(stationId): \(error.localizedDescription)")
            throw error
        }
    }
}

// Models
struct Station: Codable {
    let id: String
    let name: String
    let latitude: Double?
    let longitude: Double?
    let uic_ref: String?
    
    init(id: String, name: String, latitude: Double? = nil, longitude: Double? = nil, uic_ref: String? = nil) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.uic_ref = uic_ref
    }
}

struct Journey: Codable {
    let name: String?
    let to: String?
    let stop: Stop
    let category: String?
    let number: String?
    let passList: [Stop]?
    
    struct Stop: Codable {
        let departure: String?
        let station: StationInfo
        
        struct StationInfo: Codable {
            let id: String
            let name: String?
        }
    }
    
    var fullName: String {
        if let category = category, let number = number {
            return "\(category)\(number)"
        }
        return name ?? "Unknown"
    }
    
    // Better direction logic using passList like iOS
    var bestDirection: String {
        // First, try to get next station from passList
        if let passList = passList,
           passList.count > 1,
           let nextStation = passList.dropFirst().first {
            return nextStation.station.name ?? "Unknown"
        }
        
        // Fallback to 'to' field
        if let to = to, !to.isEmpty {
            return to
        }
        
        // Final fallback
        return name ?? "Departure"
    }
}

struct StationboardResponse: Codable {
    let stationboard: [Journey]
} 