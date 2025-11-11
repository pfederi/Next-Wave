import Foundation

/// API für Wasserpegel-Daten von MeteoNews
class WaterLevelAPI {
    static let shared = WaterLevelAPI()
    
    // Vercel API URL - anpassen an deine Deployment URL
    private let baseURL = "https://vesseldata-api.vercel.app/api/water-temperature"
    
    // MARK: - Mock Data für Tests (setze auf false nach Vercel-Deployment)
    private let useMockData = false
    
    private init() {}
    
    struct LakeWaterLevel: Codable {
        let name: String
        let waterLevel: String?
        
        // Für Kompatibilität mit alter API - ignorieren wir die Temperatur
        private enum CodingKeys: String, CodingKey {
            case name
            case waterLevel
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
    private let cacheValidityDuration: TimeInterval = 86400 // 24 Stunden (1 Tag)
    
    // Mock-Daten für lokale Tests
    private func getMockData() -> [LakeWaterLevel] {
        print("🌊 Using MOCK water level data (set useMockData = false after Vercel deployment)")
        return [
            LakeWaterLevel(name: "Zürichsee", waterLevel: "405.96 m.ü.M."),
            LakeWaterLevel(name: "Vierwaldstättersee", waterLevel: "433.53 m.ü.M."),
            LakeWaterLevel(name: "Genfersee", waterLevel: nil),
            LakeWaterLevel(name: "Bodensee", waterLevel: nil),
            LakeWaterLevel(name: "Thunersee", waterLevel: "557.77 m.ü.M."),
            LakeWaterLevel(name: "Brienzersee", waterLevel: "563.68 m.ü.M."),
            LakeWaterLevel(name: "Zugersee", waterLevel: "413.58 m.ü.M."),
            LakeWaterLevel(name: "Walensee", waterLevel: "418.51 m.ü.M."),
            LakeWaterLevel(name: "Bielersee", waterLevel: "429.18 m.ü.M."),
            LakeWaterLevel(name: "Neuenburgersee", waterLevel: nil),
            LakeWaterLevel(name: "Murtensee", waterLevel: "429.36 m.ü.M."),
            LakeWaterLevel(name: "Lago Maggiore", waterLevel: "193.47 m.ü.M."),
            LakeWaterLevel(name: "Luganersee", waterLevel: nil),
            LakeWaterLevel(name: "Sempachersee", waterLevel: "503.78 m.ü.M."),
            LakeWaterLevel(name: "Hallwilersee", waterLevel: "448.58 m.ü.M."),
            LakeWaterLevel(name: "Greifensee", waterLevel: "435.14 m.ü.M."),
            LakeWaterLevel(name: "Pfäffikersee", waterLevel: "536.80 m.ü.M."),
            LakeWaterLevel(name: "Ägerisee", waterLevel: "723.64 m.ü.M."),
            LakeWaterLevel(name: "Baldeggersee", waterLevel: nil),
            LakeWaterLevel(name: "Sarnersee", waterLevel: "469.37 m.ü.M."),
            LakeWaterLevel(name: "Alpnachersee", waterLevel: nil),
            LakeWaterLevel(name: "Sihlsee", waterLevel: nil),
            LakeWaterLevel(name: "Lauerzersee", waterLevel: "447.14 m.ü.M."),
            LakeWaterLevel(name: "Türlersee", waterLevel: nil),
            LakeWaterLevel(name: "Katzensee", waterLevel: nil),
            LakeWaterLevel(name: "Lützelsee", waterLevel: nil),
            LakeWaterLevel(name: "Silsersee", waterLevel: "1796.57 m.ü.M."),
            LakeWaterLevel(name: "Silvaplanersee", waterLevel: "1790.66 m.ü.M."),
            LakeWaterLevel(name: "St. Moritzersee", waterLevel: "1767.93 m.ü.M."),
            LakeWaterLevel(name: "Lac de Joux", waterLevel: "1004.12 m.ü.M."),
            LakeWaterLevel(name: "Burgäschisee", waterLevel: nil),
            LakeWaterLevel(name: "Mettmenhaslisee", waterLevel: nil)
        ]
    }
    
    // Ruft Wasserpegel ab
    func getWaterLevels() async throws -> [LakeWaterLevel] {
        // Mock-Daten für Tests verwenden
        if useMockData {
            return getMockData()
        }
        
        // Prüfe, ob wir gecachte Daten haben, die noch gültig sind
        if let cached = cachedData,
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheValidityDuration {
            print("🌊 [MeteoNews] Using cached water level data")
            return cached.lakes
        }
        
        guard let url = URL(string: baseURL) else {
            throw URLError(.badURL)
        }
        
        do {
            print("🌊 [MeteoNews] Fetching water levels from API...")
            let (data, response) = try await URLSession.shared.data(from: url)
            
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
        print("🌊 [MeteoNews] Water level cache invalidated")
    }
}

