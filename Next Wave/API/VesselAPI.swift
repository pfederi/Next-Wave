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
        
        // Prüfe ob die Daten vom gleichen Tag sind
        // Daten sind aktuell wenn sie von heute sind und mindestens 3 Tage abdecken
        let isToday = Calendar.current.isDate(updateDate, inSameDayAs: Date())
        let hasEnoughDays = dailyDeployments.count >= 3
        return isToday && hasEnoughDays
    }
}

class VesselAPI {
    static let shared = VesselAPI()
    private let baseURL = "https://vesseldata-api.vercel.app/api"
    
    private var cachedResponse: VesselResponse?
    private var lastFetchDate: Date?
    
    // Cache für Schiffsnamen: [datum_kursnummer: schiffname]
    private var shipNameCache: [String: String] = [:]
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private init() {}
    
    func fetchShipData() async throws -> VesselResponse {
        // Prüfe ob wir bereits aktuelle 3-Tages-Daten vom heutigen Tag haben
        if let cached = cachedResponse,
           let lastFetch = lastFetchDate,
           Calendar.current.isDate(lastFetch, inSameDayAs: Date()),
           cached.isDataCurrent {
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
        
        // Cache die Daten wenn sie aktuell sind (von heute und >= 3 Tage)
        if vesselResponse.isDataCurrent {
            cachedResponse = vesselResponse
            lastFetchDate = Date()
            // Leere den shipNameCache wenn wir neue Daten erhalten
            shipNameCache.removeAll()
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
            
            // Suche in allen verfügbaren Tagen (jetzt 3 Tage statt nur 1)
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