import Foundation

/// Wassertemperatur und 2-Tage-Vorhersage von Alplakes (Eawag), über next-wave-api.
/// Alplakes limitiert Anfragen pro Client, deshalb fragt nur der Server Alplakes ab
/// (alle 3 Stunden, See für See) und die App holt alle Seen mit einer einzigen Anfrage.
actor AlplakesAPI {
    static let shared = AlplakesAPI()

    private let url = URL(string: "https://api.nextwaveapp.ch/lake-temperatures")!

    // Cache für Temperaturdaten (alle Seen aus einer Antwort)
    private var cachedTemperatures: [String: LakeTemperatureData] = [:]
    private var lastFetchTime: Date?
    private let cacheValidityDuration: TimeInterval = 3600 // 1 Stunde, der Server aktualisiert alle 3 Stunden

    // Laufende Anfrage, damit parallele Aufrufe (ein Task pro See) nur eine Anfrage auslösen
    private var inFlight: Task<[String: LakeTemperatureData], Error>?

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

    // API Response Model (next-wave-api /lake-temperatures)
    private struct LakeTemperaturesResponse: Decodable {
        let lakes: [Lake]

        struct Lake: Decodable {
            let name: String
            let temperature: Double?
            let forecast: [Forecast]
        }

        struct Forecast: Decodable {
            let time: String
            let temperature: Double
        }
    }

    // MARK: - Public Methods

    /// Holt aktuelle Temperatur und Vorhersage für einen See (nil, wenn Alplakes den See nicht abdeckt)
    func getTemperature(for lakeName: String) async throws -> LakeTemperatureData? {
        if let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheValidityDuration {
            return cachedTemperatures[lakeName]
        }

        let task = inFlight ?? Task { try await fetchAll() }
        inFlight = task
        defer { inFlight = nil }

        do {
            let temperatures = try await task.value
            cachedTemperatures = temperatures
            lastFetchTime = Date()
            return temperatures[lakeName]
        } catch {
            print("⚠️ [Alplakes] Failed to fetch lake temperatures: \(error)")
            throw error
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

    // MARK: - Private Methods

    private func fetchAll() async throws -> [String: LakeTemperatureData] {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15.0

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let result = try JSONDecoder().decode(LakeTemperaturesResponse.self, from: data)

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = Date()

        var temperatures: [String: LakeTemperatureData] = [:]
        for lake in result.lakes {
            let forecast = lake.forecast.compactMap { f in
                isoFormatter.date(from: f.time).map { LakeTemperatureData.TemperatureForecast(time: $0, temperature: f.temperature) }
            }
            temperatures[lake.name] = LakeTemperatureData(
                lakeName: lake.name,
                temperature: lake.temperature,
                forecast: forecast,
                depth: 0.0,
                lastUpdated: now
            )
        }

        print("✅ [Alplakes] Fetched temperatures for \(temperatures.count) lakes")
        return temperatures
    }
}
