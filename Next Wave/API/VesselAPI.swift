import Foundation

struct VesselDeployment: Codable {
    let shipName: String
    let courseNumber: String
}

struct VesselResponse: Codable {
    let dailyDeployments: [DailyDeployment]
    let lastUpdated: String
    let debug: DebugInfo
    
    struct DailyDeployment: Codable {
        let date: String
        let routes: [VesselDeployment]
    }
    
    struct DebugInfo: Codable {
        let daysProcessed: Int
        let firstDay: String
        let lastDay: String
    }
    
    var isDataCurrent: Bool {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        guard let updateDate = formatter.date(from: lastUpdated) else {
            return false
        }
        
        return Date().timeIntervalSince(updateDate) < 24 * 60 * 60
    }
}

class VesselAPI {
    static let shared = VesselAPI()
    private let baseURL = "https://vesseldata-api.vercel.app/api"
    private let cacheTimeout: TimeInterval = 15 * 60 // 15 Minuten Cache
    
    private var cachedResponse: VesselResponse?
    private var lastFetchTime: Date?
    
    // Cache für Schiffsnamen: [datum_kursnummer: schiffname]
    private var shipNameCache: [String: String] = [:]
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private init() {}
    
    func fetchShipData() async throws -> VesselResponse {
        if let cached = cachedResponse,
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheTimeout {
            return cached
        }
        
        guard let url = URL(string: "\(baseURL)/ships") else {
            throw URLError(.badURL)
        }
        
        let (data, urlResponse) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = urlResponse as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        let vesselResponse = try decoder.decode(VesselResponse.self, from: data)
        
        if vesselResponse.isDataCurrent {
            cachedResponse = vesselResponse
            lastFetchTime = Date()
        }
        
        return vesselResponse
    }
    
    func findShipName(for courseNumber: String, date: Date) async -> String? {
        // Cache-Key erstellen
        let dateString = dateFormatter.string(from: date)
        let cacheKey = "\(dateString)_\(courseNumber)"
        
        // Wenn im Cache, direkt zurückgeben
        if let cachedName = shipNameCache[cacheKey] {
            return cachedName
        }
        
        // Sonst von API holen und cachen
        do {
            let response = try await fetchShipData()
            
            guard let deployment = response.dailyDeployments.first(where: { $0.date == dateString }) else {
                return nil
            }
            
            if let match = deployment.routes.first(where: { 
                $0.courseNumber.trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "^0+", with: "", options: .regularExpression) == courseNumber 
            }) {
                // Im Cache speichern
                shipNameCache[cacheKey] = match.shipName
                return match.shipName
            }
            
            return nil
            
        } catch {
            return nil
        }
    }
} 