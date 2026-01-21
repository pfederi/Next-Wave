import Foundation

/// API für Wasserpegel und Temperatur-Fallback von MeteoNews
actor MeteoNewsAPI {
    static let shared = MeteoNewsAPI()
    
    // Vercel API URL - anpassen an deine Deployment URL
    private let baseURL = "https://vesseldata-api.vercel.app/api/water-temperature"
    
    // MARK: - Mock Data für Tests (setze auf false nach Vercel-Deployment)
    private let useMockData = false
    
    private init() {}
    
    struct LakeWaterLevel: Codable {
        let name: String
        let waterLevel: String?
        let temperature: Double? // Fallback für Seen ohne Alplakes-Daten
        
        enum CodingKeys: String, CodingKey {
            case name
            case waterLevel
            case temperature
        }
    }
    
    struct WaterLevelResponse: Codable {
        let lakes: [LakeWaterLevel]
        let lastUpdated: String
        let debug: DebugInfo?
        
        struct DebugInfo: Codable {
            let currentSwissTime: String?
            let lakesCount: Int?
        }
    }
    
    // Cache für Wasserpegel
    private var cachedData: WaterLevelResponse?
    private var lastFetchTime: Date?
    private var lastFetchDay: Date? // Speichert den Tag des letzten Abrufs
    private let cacheValidityDuration: TimeInterval = 86400 // 24 Stunden (1 Tag)
    
    // Mock-Daten für lokale Tests
    private func getMockData() -> [LakeWaterLevel] {
        print("🌊 Using MOCK water level data (set useMockData = false after Vercel deployment)")
        return [
            LakeWaterLevel(name: "Zürichsee", waterLevel: "405.96 m.ü.M.", temperature: 14),
            LakeWaterLevel(name: "Vierwaldstättersee", waterLevel: "433.53 m.ü.M.", temperature: 13),
            LakeWaterLevel(name: "Genfersee", waterLevel: nil, temperature: 15),
            LakeWaterLevel(name: "Bodensee", waterLevel: nil, temperature: 14),
            LakeWaterLevel(name: "Thunersee", waterLevel: "557.77 m.ü.M.", temperature: 13),
            LakeWaterLevel(name: "Brienzersee", waterLevel: "563.68 m.ü.M.", temperature: 12),
            LakeWaterLevel(name: "Zugersee", waterLevel: "413.58 m.ü.M.", temperature: 14),
            LakeWaterLevel(name: "Walensee", waterLevel: "418.51 m.ü.M.", temperature: 13),
            LakeWaterLevel(name: "Bielersee", waterLevel: "429.18 m.ü.M.", temperature: 14),
            LakeWaterLevel(name: "Neuenburgersee", waterLevel: nil, temperature: 14),
            LakeWaterLevel(name: "Murtensee", waterLevel: "429.36 m.ü.M.", temperature: 14),
            LakeWaterLevel(name: "Lago Maggiore", waterLevel: "193.47 m.ü.M.", temperature: 16),
            LakeWaterLevel(name: "Luganersee", waterLevel: nil, temperature: 16),
            LakeWaterLevel(name: "Sempachersee", waterLevel: "503.78 m.ü.M.", temperature: 14),
            LakeWaterLevel(name: "Hallwilersee", waterLevel: "448.58 m.ü.M.", temperature: 14),
            LakeWaterLevel(name: "Greifensee", waterLevel: "435.14 m.ü.M.", temperature: 13),
            LakeWaterLevel(name: "Pfäffikersee", waterLevel: "536.80 m.ü.M.", temperature: 13),
            LakeWaterLevel(name: "Ägerisee", waterLevel: "723.64 m.ü.M.", temperature: 14),
            LakeWaterLevel(name: "Baldeggersee", waterLevel: nil, temperature: 14),
            LakeWaterLevel(name: "Sarnersee", waterLevel: "469.37 m.ü.M.", temperature: 13),
            LakeWaterLevel(name: "Alpnachersee", waterLevel: nil, temperature: 13),
            LakeWaterLevel(name: "Sihlsee", waterLevel: nil, temperature: 12),
            LakeWaterLevel(name: "Lauerzersee", waterLevel: "447.14 m.ü.M.", temperature: 14),
            LakeWaterLevel(name: "Türlersee", waterLevel: nil, temperature: 13),
            LakeWaterLevel(name: "Katzensee", waterLevel: nil, temperature: 13),
            LakeWaterLevel(name: "Lützelsee", waterLevel: nil, temperature: 13),
            LakeWaterLevel(name: "Silsersee", waterLevel: "1796.57 m.ü.M.", temperature: 8),
            LakeWaterLevel(name: "Silvaplanersee", waterLevel: "1790.66 m.ü.M.", temperature: 8),
            LakeWaterLevel(name: "St. Moritzersee", waterLevel: "1767.93 m.ü.M.", temperature: 9),
            LakeWaterLevel(name: "Lac de Joux", waterLevel: "1004.12 m.ü.M.", temperature: 13),
            LakeWaterLevel(name: "Burgäschisee", waterLevel: nil, temperature: 14),
            LakeWaterLevel(name: "Mettmenhaslisee", waterLevel: nil, temperature: 13)
        ]
    }
    
    // Ruft Wasserpegel ab
    func getWaterLevels() async throws -> [LakeWaterLevel] {
        // Mock-Daten für Tests verwenden
        if useMockData {
            return getMockData()
        }
        
        // Prüfe, ob ein neuer Tag begonnen hat - wenn ja, Cache invalidieren
        if let lastDay = lastFetchDay {
            let calendar = Calendar.current
            if !calendar.isDate(lastDay, inSameDayAs: Date()) {
                print("🌊 [MeteoNews] New day detected - invalidating cache")
                invalidateCache()
            }
        }
        
        // Prüfe, ob wir gecachte Daten haben, die noch gültig sind
        if let cached = cachedData,
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheValidityDuration {
            print("🌊 [MeteoNews] Using cached water level data (age: \(String(format: "%.1f", Date().timeIntervalSince(lastFetch) / 3600))h)")
            return cached.lakes
        }
        
        guard let url = URL(string: baseURL) else {
            throw URLError(.badURL)
        }
        
        // Configure URLRequest with HTTP caching
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData // Immer frische Daten vom Server holen
        request.timeoutInterval = 15.0
        
        do {
            print("🌊 [MeteoNews] Fetching fresh water levels from API...")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            if httpResponse.statusCode != 200 {
                print("⚠️ [MeteoNews] Water level API returned status code: \(httpResponse.statusCode)")
                throw URLError(.badServerResponse)
            }
            
            let result = try JSONDecoder().decode(WaterLevelResponse.self, from: data)
            
            // Cache die Daten
            cachedData = result
            lastFetchTime = Date()
            lastFetchDay = Date()
            
            print("✅ [MeteoNews] Successfully fetched water levels for \(result.lakes.count) lakes")
            return result.lakes
            
        } catch {
            print("⚠️ [MeteoNews] Failed to fetch water levels: \(error)")
            throw error
        }
    }
    
    // Hilfsmethode, um den Wasserpegel für einen bestimmten See zu finden
    func getWaterLevel(for lakeName: String) async throws -> LakeWaterLevel? {
        let levels = try await getWaterLevels()
        return levels.first { $0.name.lowercased() == lakeName.lowercased() }
    }
    
    // Preload Methode die beim App-Start aufgerufen werden kann
    func preloadData() async {
        print("🌊 [MeteoNews] Preloading water level data...")
        do {
            _ = try await getWaterLevels()
            print("✅ [MeteoNews] Water level data preload completed")
        } catch {
            print("⚠️ [MeteoNews] Failed to preload water level data: \(error)")
        }
    }
    
    // Cache invalidieren (z.B. bei Pull-to-Refresh)
    func invalidateCache() {
        cachedData = nil
        lastFetchTime = nil
        lastFetchDay = nil
        print("🌊 [MeteoNews] Water level cache invalidated")
    }
    
    // Clear cache
    func clearCache() {
        invalidateCache()
        print("🗑️ [MeteoNews] Water level cache cleared")
    }
}

