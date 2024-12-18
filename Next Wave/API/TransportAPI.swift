import Foundation

class TransportAPI {
    enum APIError: Error {
        case invalidURL
        case invalidResponse
        case noJourneyFound
    }
    
    func getStationboard(stationId: String, for date: Date = Date()) async throws -> [Journey] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        let urlString = "https://transport.opendata.ch/v1/stationboard?id=\(stationId)&limit=50&date=\(dateString)"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        do {
            let decoder = JSONDecoder()
            let stationboard = try decoder.decode(StationboardResponse.self, from: data)
            let filteredJourneys = stationboard.stationboard.filter { journey in
                if journey.category == "BAT",
                   let passList = journey.passList,
                   !passList.isEmpty {
                    // Debug: Print the pass list
                    print("Journey \(journey.name ?? "unknown") pass list:")
                    for stop in passList {
                        print("- \(stop.station.name ?? "unknown")")
                    }
                    return true
                }
                return false
            }
            print("Found \(filteredJourneys.count) BAT journeys")
            return filteredJourneys
        } catch {
            print("Error decoding response: \(error)")
            throw error
        }
    }
    
    func getJourneyDetails(for journey: Journey) async throws -> Journey {
        let urlString = "https://transport.opendata.ch/v1/connections?from=\(journey.stop.station.id)&to=\(journey.to ?? "")&time=\(journey.stop.departure ?? "")&transportations[]=ship"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        // Debug: Print the raw response
        if let jsonString = String(data: data, encoding: .utf8) {
            print("API Response for journey \(journey.id):")
            print(jsonString)
        }
        
        let decoder = JSONDecoder()
        let connectionResponse = try decoder.decode(ConnectionResponse.self, from: data)
        
        guard let firstConnection = connectionResponse.connections.first,
              let firstSection = firstConnection.sections.first,
              let detailedJourney = firstSection.journey else {
            throw APIError.noJourneyFound
        }
        
        return detailedJourney
    }
} 