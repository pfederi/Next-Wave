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
        let hasEnoughDays = dailyDeployments.count >= 1
        
        // Optional: Prüfe ob lastUpdated parsebar ist
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let updateDate = formatter.date(from: lastUpdated) {
            let isToday = Calendar.current.isDate(updateDate, inSameDayAs: Date())
            return isToday && hasEnoughDays
        }
        
        // Fallback: Wenn wir 3 Tage haben, sind die Daten wahrscheinlich aktuell
        return hasEnoughDays
    }
}

actor VesselAPI {
    static let shared = VesselAPI()
    private let baseURL = "https://api.nextwaveapp.ch"
    
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
            
            // Use URLRequest with cache policy to respect server cache headers
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData // Always fetch fresh data
            
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = urlResponse as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            // Check if data came from cache
            if let cachedResponse = URLCache.shared.cachedResponse(for: request) {
                print("📦 Data came from URLCache (size: \(cachedResponse.data.count) bytes)")
            } else {
                print("🌐 Data fetched from network")
            }
            
            let decoder = JSONDecoder()
            let vesselResponse = try decoder.decode(VesselResponse.self, from: data)
            
            print("✅ Received vessel data: \(vesselResponse.dailyDeployments.count) days")
            print("   Days: \(vesselResponse.dailyDeployments.map { $0.date }.joined(separator: ", "))")
            
            // Log total routes per day
            for deployment in vesselResponse.dailyDeployments {
                print("   \(deployment.date): \(deployment.routes.count) routes")
            }
            
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
            }
            
            return result
        } catch {
            // Bei Fehler Task entfernen damit es nochmal versucht werden kann
            initialFetchTask = nil
            throw error
        }
    }
    
    // Synchrone Methode um Schiffsnamen aus dem Cache zu holen (ohne async/await)
    func getCachedShipName(for courseNumber: String, date: Date) -> String? {
        let dateString = dateFormatter.string(from: date)
        let cacheKey = "\(dateString)_\(courseNumber)"
        
        // Prüfe zuerst den shipNameCache
        if let cachedName = shipNameCache[cacheKey] {
            return cachedName
        }
        
        // Prüfe dann die gecachte Response
        if let cached = cachedResponse,
           let lastFetch = lastFetchDate,
           Calendar.current.isDate(lastFetch, inSameDayAs: Date()),
           cached.isDataCurrent {
            if let deployment = cached.dailyDeployments.first(where: { $0.date == dateString }) {
                if let match = deployment.routes.first(where: { 
                    $0.courseNumber.trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(of: "^0+", with: "", options: .regularExpression) == courseNumber 
                }) {
                    // Cache für nächstes Mal
                    shipNameCache[cacheKey] = match.shipName
                    return match.shipName
                }
            }
        }
        
        return nil
    }
    
    func findShipName(for courseNumber: String, date: Date) async -> String? {
        // Cache-Key erstellen
        let dateString = dateFormatter.string(from: date)
        let cacheKey = "\(dateString)_\(courseNumber)"
        
        // Wenn im Cache, direkt zurückgeben (ohne API-Call!)
        if let cachedName = shipNameCache[cacheKey] {
            return cachedName
        }
        
        // Prüfe ob wir bereits gecachte Response-Daten haben
        if let cached = cachedResponse,
           let lastFetch = lastFetchDate,
           Calendar.current.isDate(lastFetch, inSameDayAs: Date()),
           cached.isDataCurrent {
            // Suche direkt in den gecachten Daten ohne neuen API-Call
            if let deployment = cached.dailyDeployments.first(where: { $0.date == dateString }) {
                if let match = deployment.routes.first(where: { 
                    $0.courseNumber.trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(of: "^0+", with: "", options: .regularExpression) == courseNumber 
                }) {
                    // Im Cache speichern für schnelleren Zugriff
                    shipNameCache[cacheKey] = match.shipName
                    return match.shipName
                }
            }
            // Kurs nicht gefunden in gecachten Daten
            return nil
        }
        
        // Nur wenn keine gecachten Daten vorhanden sind, API aufrufen
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
    
    // Manuelles Cache-Löschen für Debugging/Testing
    func clearCache() {
        cachedResponse = nil
        lastFetchDate = nil
        shipNameCache.removeAll()
        initialFetchTask = nil
        
        // URLSession Cache auch löschen
        URLCache.shared.removeAllCachedResponses()
    }
} 