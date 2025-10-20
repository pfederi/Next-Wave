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
        // Daten sind aktuell wenn wir mindestens 3 Tage haben
        // Der Server cached die Daten bereits für 6 Stunden, also vertrauen wir darauf
        let hasEnoughDays = dailyDeployments.count >= 3
        
        // Optional: Prüfe ob lastUpdated parsebar ist
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let updateDate = formatter.date(from: lastUpdated) {
            let isToday = Calendar.current.isDate(updateDate, inSameDayAs: Date())
            print("📊 isDataCurrent: isToday=\(isToday), hasEnoughDays=\(hasEnoughDays)")
            return isToday && hasEnoughDays
        }
        
        // Fallback: Wenn wir 3 Tage haben, sind die Daten wahrscheinlich aktuell
        print("📊 isDataCurrent: Using fallback, hasEnoughDays=\(hasEnoughDays)")
        return hasEnoughDays
    }
}

actor VesselAPI {
    static let shared = VesselAPI()
    private let baseURL = "https://vesseldata-api.vercel.app/api"
    
    private var cachedResponse: VesselResponse?
    private var lastFetchDate: Date?
    
    // Cache für Schiffsnamen: [datum_kursnummer: schiffname]
    private var shipNameCache: [String: String] = [:]
    
    // Einmaliger Fetch Task der beim ersten Zugriff erstellt wird
    private var initialFetchTask: Task<VesselResponse, Error>?
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private init() {}
    
    // Preload Methode die beim App-Start aufgerufen wird
    func preloadData() async {
        do {
            _ = try await fetchShipData()
            print("✅ Vessel data preloaded successfully")
        } catch {
            print("⚠️ Failed to preload vessel data: \(error)")
        }
    }
    
    func fetchShipData() async throws -> VesselResponse {
        // Prüfe ob wir bereits aktuelle 3-Tages-Daten vom heutigen Tag haben
        if let cached = cachedResponse,
           let lastFetch = lastFetchDate,
           Calendar.current.isDate(lastFetch, inSameDayAs: Date()),
           cached.isDataCurrent {
            print("📦 Using cached vessel data: \(cached.dailyDeployments.count) days")
            return cached
        }
        
        // Wenn wir hier sind, ist entweder kein Cache vorhanden oder es ist ein neuer Tag
        if let lastFetch = lastFetchDate,
           !Calendar.current.isDate(lastFetch, inSameDayAs: Date()) {
            print("📅 New day detected, invalidating cache and fetching fresh data")
            // Invalidiere den alten Task und Cache
            initialFetchTask = nil
            cachedResponse = nil
        }
        
        // Wenn bereits ein Fetch läuft, warte darauf
        if let existingTask = initialFetchTask {
            print("⏳ Waiting for existing fetch task...")
            return try await existingTask.value
        }
        
        // Erstelle EINEN Task der von allen geteilt wird
        let fetchTask = Task<VesselResponse, Error> {
            print("🔄 Fetching fresh vessel data from API...")
            
            guard let url = URL(string: "\(self.baseURL)/ships") else {
                throw URLError(.badURL)
            }
            
            let (data, urlResponse) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = urlResponse as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            let decoder = JSONDecoder()
            let vesselResponse = try decoder.decode(VesselResponse.self, from: data)
            
            print("✅ Received vessel data: \(vesselResponse.dailyDeployments.count) days")
            print("   Days: \(vesselResponse.dailyDeployments.map { $0.date }.joined(separator: ", "))")
            
            return vesselResponse
        }
        
        // Setze den Task SOFORT
        initialFetchTask = fetchTask
        
        do {
            let result = try await fetchTask.value
            
            // Cache die Daten wenn sie aktuell sind
            if result.isDataCurrent {
                cachedResponse = result
                lastFetchDate = Date()
                shipNameCache.removeAll()
                print("💾 Cached vessel data for future use")
            } else {
                print("⚠️ Data not current: days=\(result.dailyDeployments.count)")
            }
            
            return result
        } catch {
            // Bei Fehler Task entfernen damit es nochmal versucht werden kann
            initialFetchTask = nil
            throw error
        }
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