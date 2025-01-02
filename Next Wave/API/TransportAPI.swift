import Foundation

class TransportAPI {
    enum APIError: Error {
        case invalidURL
        case invalidResponse
        case noJourneyFound
        case networkError(String)
        case timeout
        
        var userMessage: String {
            switch self {
            case .invalidURL:
                return "Invalid URL - Please contact support"
            case .invalidResponse:
                return "The OpenTransport API is currently not available. Please try again later."
            case .noJourneyFound:
                return "No connections found"
            case .networkError(let message):
                return "Connection problem: \(message)"
            case .timeout:
                return "The OpenTransport API (transport.opendata.ch) is not responding (Timeout).\n\nPossible reasons:\n• Server is overloaded\n• Server maintenance\n• Temporary API disruption\n\nPlease try again in a few minutes."
            }
        }
    }
    
    func getStationboard(stationId: String, for date: Date = Date()) async throws -> [Journey] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        let urlString = "https://transport.opendata.ch/v1/stationboard?id=\(stationId)&limit=50&date=\(dateString)"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError("No connection to the server possible")
            }
            
            if httpResponse.statusCode != 200 {
                throw APIError.invalidResponse
            }
            
            let decoder = JSONDecoder()
            let stationboard = try decoder.decode(StationboardResponse.self, from: data)
            let filteredJourneys = stationboard.stationboard.filter { journey in
                if journey.category == "BAT",
                   let passList = journey.passList,
                   !passList.isEmpty {
                    return true
                }
                return false
            }
            return filteredJourneys
        } catch let error as URLError {
            switch error.code {
            case .timedOut, .cannotConnectToHost, .cannotFindHost:
                throw APIError.timeout
            case .notConnectedToInternet:
                throw APIError.networkError("No internet connection. Please check your connection and try again.")
            default:
                throw APIError.networkError("Network error: \(error.localizedDescription)")
            }
        } catch {
            throw APIError.networkError("Unexpected error: \(error.localizedDescription)")
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