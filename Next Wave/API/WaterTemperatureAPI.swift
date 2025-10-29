import Foundation

class WaterTemperatureAPI {
    static let shared = WaterTemperatureAPI()
    
    // Vercel API URL - anpassen an deine Deployment URL
    private let baseURL = "https://vesseldata-api.vercel.app/api/water-temperature"
    
    // MARK: - Mock Data für Tests (setze auf false nach Vercel-Deployment)
    private let useMockData = false
    
    private init() {}
    
    struct LakeTemperature: Codable {
        let name: String
        let temperature: Double?
        let waterLevel: String?
    }
    
    struct WaterTemperatureResponse: Codable {
        let lakes: [LakeTemperature]
        let lastUpdated: String
        let debug: DebugInfo?
        
        struct DebugInfo: Codable {
            let currentSwissTime: String?
            let lakesCount: Int?
        }
    }
    
    // Cache für Wassertemperaturen
    private var cachedData: WaterTemperatureResponse?
    private var lastFetchTime: Date?
    private let cacheValidityDuration: TimeInterval = 86400 // 24 Stunden (1 Tag)
    
    // Mock-Daten für lokale Tests
    private func getMockData() -> [LakeTemperature] {
        print("🌊 Using MOCK water temperature data (set useMockData = false after Vercel deployment)")
        return [
            LakeTemperature(name: "Zürichsee", temperature: 14, waterLevel: "405.96 m.ü.M."),
            LakeTemperature(name: "Vierwaldstättersee", temperature: 13, waterLevel: "433.53 m.ü.M."),
            LakeTemperature(name: "Genfersee", temperature: 15, waterLevel: nil),
            LakeTemperature(name: "Bodensee", temperature: 14, waterLevel: nil),
            LakeTemperature(name: "Thunersee", temperature: 13, waterLevel: "557.77 m.ü.M."),
            LakeTemperature(name: "Brienzersee", temperature: 12, waterLevel: "563.68 m.ü.M."),
            LakeTemperature(name: "Zugersee", temperature: 14, waterLevel: "413.58 m.ü.M."),
            LakeTemperature(name: "Walensee", temperature: 13, waterLevel: "418.51 m.ü.M."),
            LakeTemperature(name: "Bielersee", temperature: 14, waterLevel: "429.18 m.ü.M."),
            LakeTemperature(name: "Neuenburgersee", temperature: 14, waterLevel: nil),
            LakeTemperature(name: "Murtensee", temperature: 14, waterLevel: "429.36 m.ü.M."),
            LakeTemperature(name: "Lago Maggiore", temperature: 16, waterLevel: "193.47 m.ü.M."),
            LakeTemperature(name: "Luganersee", temperature: 16, waterLevel: nil),
            LakeTemperature(name: "Sempachersee", temperature: 14, waterLevel: "503.78 m.ü.M."),
            LakeTemperature(name: "Hallwilersee", temperature: 14, waterLevel: "448.58 m.ü.M."),
            LakeTemperature(name: "Greifensee", temperature: 13, waterLevel: "435.14 m.ü.M."),
            LakeTemperature(name: "Pfäffikersee", temperature: 13, waterLevel: "536.80 m.ü.M."),
            LakeTemperature(name: "Ägerisee", temperature: 14, waterLevel: "723.64 m.ü.M."),
            LakeTemperature(name: "Baldeggersee", temperature: 14, waterLevel: nil),
            LakeTemperature(name: "Sarnersee", temperature: 13, waterLevel: "469.37 m.ü.M."),
            LakeTemperature(name: "Alpnachersee", temperature: 13, waterLevel: nil),
            LakeTemperature(name: "Sihlsee", temperature: 12, waterLevel: nil),
            LakeTemperature(name: "Lauerzersee", temperature: 14, waterLevel: "447.14 m.ü.M."),
            LakeTemperature(name: "Türlersee", temperature: 13, waterLevel: nil),
            LakeTemperature(name: "Katzensee", temperature: 13, waterLevel: nil),
            LakeTemperature(name: "Lützelsee", temperature: 13, waterLevel: nil),
            LakeTemperature(name: "Silsersee", temperature: 8, waterLevel: "1796.57 m.ü.M."),
            LakeTemperature(name: "Silvaplanersee", temperature: 8, waterLevel: "1790.66 m.ü.M."),
            LakeTemperature(name: "St. Moritzersee", temperature: 9, waterLevel: "1767.93 m.ü.M."),
            LakeTemperature(name: "Lac de Joux", temperature: 13, waterLevel: "1004.12 m.ü.M."),
            LakeTemperature(name: "Burgäschisee", temperature: 14, waterLevel: nil),
            LakeTemperature(name: "Mettmenhaslisee", temperature: 13, waterLevel: nil)
        ]
    }
    
    // Ruft Wassertemperaturen ab
    func getWaterTemperatures() async throws -> [LakeTemperature] {
        // Mock-Daten für Tests verwenden
        if useMockData {
            return getMockData()
        }
        
        // Prüfe, ob wir gecachte Daten haben, die noch gültig sind
        if let cached = cachedData,
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheValidityDuration {
            print("🌊 Using cached water temperature data")
            return cached.lakes
        }
        
        guard let url = URL(string: baseURL) else {
            throw URLError(.badURL)
        }
        
        do {
            print("🌊 Fetching water temperatures from API...")
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            if httpResponse.statusCode != 200 {
                print("⚠️ Water temperature API returned status code: \(httpResponse.statusCode)")
                throw URLError(.badServerResponse)
            }
            
            let result = try JSONDecoder().decode(WaterTemperatureResponse.self, from: data)
            
            // Cache die Daten
            cachedData = result
            lastFetchTime = Date()
            
            print("✅ Successfully fetched water temperatures for \(result.lakes.count) lakes")
            return result.lakes
            
        } catch {
            print("⚠️ Failed to fetch water temperatures: \(error)")
            throw error
        }
    }
    
    // Hilfsmethode, um die Temperatur für einen bestimmten See zu finden
    func getTemperature(for lakeName: String) async throws -> LakeTemperature? {
        let temperatures = try await getWaterTemperatures()
        return temperatures.first { $0.name.lowercased() == lakeName.lowercased() }
    }
    
    // Preload Methode die beim App-Start aufgerufen werden kann
    func preloadData() async {
        print("🌊 Preloading water temperature data...")
        do {
            _ = try await getWaterTemperatures()
            print("✅ Water temperature data preload completed")
        } catch {
            print("⚠️ Failed to preload water temperature data: \(error)")
        }
    }
    
    // Cache invalidieren (z.B. bei Pull-to-Refresh)
    func invalidateCache() {
        cachedData = nil
        lastFetchTime = nil
        print("🌊 Water temperature cache invalidated")
    }
}

