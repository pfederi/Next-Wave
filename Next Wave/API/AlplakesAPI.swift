import Foundation

/// Alplakes API für Wassertemperatur und Vorhersagen
/// API Dokumentation: https://alplakes-api.eawag.ch/docs
actor AlplakesAPI {
    static let shared = AlplakesAPI()
    
    private let baseURL = "https://alplakes-api.eawag.ch"
    
    // Cache für Temperaturdaten
    private var cachedTemperatures: [String: LakeTemperatureData] = [:]
    private var lastFetchTime: Date?
    private let cacheValidityDuration: TimeInterval = 10800 // 3 Stunden
    
    private init() {}
    
    // MARK: - Models
    
    struct LakeTemperatureData: Codable {
        let lakeName: String
        let temperature: Double?  // Oberflächentemperatur in °C
        let forecast: [TemperatureForecast]?
        let depth: Double  // Tiefe in Metern
        let lastUpdated: Date
        
        struct TemperatureForecast: Codable {
            let time: Date
            let temperature: Double  // in °C
        }
    }
    
    // API Response Models
    private struct AlplakesProfileResponse: Codable {
        let time: String
        let depth: DepthData
        let variables: Variables
        
        struct DepthData: Codable {
            let data: [Double]
            let unit: String
            let description: String
        }
        
        struct Variables: Codable {
            let T: TemperatureData
            
            struct TemperatureData: Codable {
                let data: [Double?]
                let unit: String
                let description: String
            }
        }
    }
    
    private struct AlplakesPointResponse: Codable {
        let time: [String]
        let depth: DepthInfo
        let variables: Variables
        
        struct DepthInfo: Codable {
            let data: Double
            let unit: String
        }
        
        struct Variables: Codable {
            let T: TemperatureData
            
            struct TemperatureData: Codable {
                let data: [Double?]
                let unit: String
            }
        }
    }
    
    // MARK: - Lake Name Mapping
    
    /// Mappt Next Wave See-Namen auf Alplakes API Namen
    private lazy var lakeMapping: [String: String] = {
        guard let url = Bundle.main.url(forResource: "alplakes-lake-mapping", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let mapping = try? JSONDecoder().decode([String: String].self, from: data) else {
            print("⚠️ [Alplakes] Failed to load lake mapping, using fallback")
            return [
                "Zürichsee": "upperzurich",
                "Vierwaldstättersee": "lucernealpnachersee",
                "Thunersee": "thun",
                "Brienzersee": "brienz",
                "Zugersee": "zug",
                "Walensee": "walensee",
                "Bielersee": "biel",
                "Neuenburgersee": "neuchatel",
                "Murtensee": "murten",
                "Genfersee": "geneva",
                "Lago Maggiore": "maggiore",
                "Luganersee": "upperlugano",
                "Hallwilersee": "hallwil",
                "Ägerisee": "aegeri",
                "Bodensee": "upperconstance"
            ]
        }
        return mapping
    }()
    
    // MARK: - Public Methods
    
    /// Holt aktuelle Temperatur und Vorhersage für einen See
    func getTemperature(for lakeName: String) async throws -> LakeTemperatureData? {
        // Prüfe Cache
        if let cached = cachedTemperatures[lakeName],
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheValidityDuration {
            print("🌊 [Alplakes] Using cached data for \(lakeName)")
            return cached
        }
        
        guard let alplakesName = lakeMapping[lakeName] else {
            print("⚠️ [Alplakes] No mapping found for lake: \(lakeName)")
            return nil
        }
        
        do {
            // 1. Hole aktuelles Temperaturprofil
            let currentTemp = try await getCurrentTemperature(lake: alplakesName)
            
            // 2. Hole Vorhersage
            let forecast = try await getTemperatureForecast(lake: alplakesName)
            
            let data = LakeTemperatureData(
                lakeName: lakeName,
                temperature: currentTemp,
                forecast: forecast,
                depth: 0.0,
                lastUpdated: Date()
            )
            
            // Cache speichern
            cachedTemperatures[lakeName] = data
            lastFetchTime = Date()
            
            print("✅ [Alplakes] Successfully fetched temperature for \(lakeName): \(currentTemp ?? 0)°C")
            return data
            
        } catch {
            print("⚠️ [Alplakes] Failed to fetch temperature for \(lakeName): \(error)")
            throw error
        }
    }
    
    /// Holt alle Temperaturen für alle unterstützten Seen
    func getAllTemperatures() async throws -> [LakeTemperatureData] {
        var results: [LakeTemperatureData] = []
        
        for lakeName in lakeMapping.keys.sorted() {
            if let data = try await getTemperature(for: lakeName) {
                results.append(data)
            }
        }
        
        return results
    }
    
    // MARK: - Private Methods
    
    /// Holt die aktuelle Oberflächentemperatur
    private func getCurrentTemperature(lake: String) async throws -> Double? {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let timeString = formatter.string(from: now)
        
        let endpoint = "/simulations/1d/profile/simstrat/\(lake)/\(timeString)"
        let url = URL(string: baseURL + endpoint)!
        
        // Configure URLRequest with HTTP caching
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 15.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(AlplakesProfileResponse.self, from: data)
        
        // Oberflächentemperatur ist die letzte im Array (tiefste Tiefe = 0m)
        return result.variables.T.data.last ?? nil
    }
    
    /// Holt Temperaturvorhersage für die nächsten 2 Tage
    private func getTemperatureForecast(lake: String) async throws -> [LakeTemperatureData.TemperatureForecast] {
        let now = Date()
        let twoDaysLater = now.addingTimeInterval(2 * 24 * 60 * 60)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        
        let startString = formatter.string(from: now)
        let endString = formatter.string(from: twoDaysLater)
        
        let endpoint = "/simulations/1d/point/simstrat/\(lake)/\(startString)/\(endString)/0"
        let url = URL(string: baseURL + endpoint)!
        
        // Configure URLRequest with HTTP caching
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 15.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return []  // Kein Fehler werfen, nur leeres Array zurückgeben
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(AlplakesPointResponse.self, from: data)
        
        // Parse Zeitstempel und erstelle Vorhersage-Array
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var forecasts: [LakeTemperatureData.TemperatureForecast] = []
        
        for (index, timeString) in result.time.enumerated() {
            if let date = isoFormatter.date(from: timeString),
               let temp = result.variables.T.data[safe: index],
               let tempValue = temp {
                forecasts.append(
                    LakeTemperatureData.TemperatureForecast(
                        time: date,
                        temperature: tempValue
                    )
                )
            }
        }
        
        return forecasts
    }
    
    /// Preload Methode die beim App-Start aufgerufen werden kann
    func preloadData() async {
        print("🌊 [Alplakes] Preloading temperature data...")
        do {
            _ = try await getAllTemperatures()
            print("✅ [Alplakes] Temperature data preload completed")
        } catch {
            print("⚠️ [Alplakes] Failed to preload temperature data: \(error)")
        }
    }
    
    /// Cache invalidieren (z.B. bei Pull-to-Refresh)
    func invalidateCache() {
        cachedTemperatures.removeAll()
        lastFetchTime = nil
        print("🌊 [Alplakes] Cache invalidated")
    }
    
    /// Clear cache
    func clearCache() {
        invalidateCache()
        print("🗑️ [Alplakes] Water temperature cache cleared")
    }
}

// MARK: - Array Extension for Safe Access

private extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

