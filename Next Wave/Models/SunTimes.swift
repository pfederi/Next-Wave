import Foundation

struct SunTimes {
    let sunrise: Date
    let sunset: Date
    let civilTwilightBegin: Date  // Morgendämmerung beginnt
    let civilTwilightEnd: Date    // Abenddämmerung endet
}

class SunTimeService {
    static let shared = SunTimeService()
    private var cache: [String: SunTimes] = [:]
    private let maxRetries = 3
    
    // Zentrale Koordinaten der Schweiz (ungefähr Mitte Vierwaldstättersee)
    private let swissLatitude = 47.0136
    private let swissLongitude = 8.4324
    
    private let zurichTimeZone = TimeZone(identifier: "Europe/Zurich")!
    
    private init() {}
    
    func getSunTimes(date: Date) async throws -> SunTimes {
        // Create cache key from date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = zurichTimeZone
        let cacheKey = dateFormatter.string(from: date)
        
        // Return cached value if available
        if let cachedTimes = cache[cacheKey] {
            return cachedTimes
        }
        
        // Format date for API
        let formattedDate = dateFormatter.string(from: date)
        
        var lastError: Error?
        for attempt in 1...maxRetries {
            do {
                // Create URL with fixed Swiss coordinates
                let urlString = "https://api.sunrise-sunset.org/json?lat=\(swissLatitude)&lng=\(swissLongitude)&date=\(formattedDate)&formatted=0"
                guard let url = URL(string: urlString) else {
                    throw URLError(.badURL)
                }
                
        
                
                // Configure URLSession with timeout
                let config = URLSessionConfiguration.default
                config.timeoutIntervalForRequest = 10
                config.timeoutIntervalForResource = 20
                let session = URLSession(configuration: config)
                
                // Make request
                let (data, response) = try await session.data(from: url)
                
                // Check HTTP response
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                guard httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                
                // Try to decode the response
                let sunTimeResponse = try JSONDecoder().decode(SunTimeResponse.self, from: data)
                
                guard sunTimeResponse.status.lowercased() == "ok" else {
                    throw URLError(.badServerResponse)
                }
                
                // Convert UTC times to local time
                let sunTimes = SunTimes(
                    sunrise: sunTimeResponse.results.sunrise.toLocalTime(),
                    sunset: sunTimeResponse.results.sunset.toLocalTime(),
                    civilTwilightBegin: sunTimeResponse.results.civil_twilight_begin.toLocalTime(),
                    civilTwilightEnd: sunTimeResponse.results.civil_twilight_end.toLocalTime()
                )
                
                // Cache the result
                cache[cacheKey] = sunTimes
                
                return sunTimes
                
            } catch {
                lastError = error
                
                if attempt < maxRetries {
                    // Wait before retrying (exponential backoff)
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                }
            }
        }
        
        // If we get here, all retries failed
        throw lastError ?? URLError(.unknown)
    }
}

private struct SunTimeResponse: Codable {
    let results: SunTimeResults
    let status: String
}

private struct SunTimeResults: Codable {
    let sunrise: Date
    let sunset: Date
    let civil_twilight_begin: Date
    let civil_twilight_end: Date
    
    private enum CodingKeys: String, CodingKey {
        case sunrise, sunset
        case civil_twilight_begin
        case civil_twilight_end
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)! // UTC
        
        let sunriseString = try container.decode(String.self, forKey: .sunrise)
        guard let sunrise = dateFormatter.date(from: sunriseString) else {
            throw DecodingError.dataCorruptedError(forKey: .sunrise, in: container, debugDescription: "Invalid date format")
        }
        self.sunrise = sunrise
        
        let sunsetString = try container.decode(String.self, forKey: .sunset)
        guard let sunset = dateFormatter.date(from: sunsetString) else {
            throw DecodingError.dataCorruptedError(forKey: .sunset, in: container, debugDescription: "Invalid date format")
        }
        self.sunset = sunset
        
        let twilightBeginString = try container.decode(String.self, forKey: .civil_twilight_begin)
        guard let civilTwilightBegin = dateFormatter.date(from: twilightBeginString) else {
            throw DecodingError.dataCorruptedError(forKey: .civil_twilight_begin, in: container, debugDescription: "Invalid date format")
        }
        self.civil_twilight_begin = civilTwilightBegin
        
        let twilightEndString = try container.decode(String.self, forKey: .civil_twilight_end)
        guard let civilTwilightEnd = dateFormatter.date(from: twilightEndString) else {
            throw DecodingError.dataCorruptedError(forKey: .civil_twilight_end, in: container, debugDescription: "Invalid date format")
        }
        self.civil_twilight_end = civilTwilightEnd
    }
}

private extension Date {
    func toLocalTime() -> Date {
        let zurichTimeZone = TimeZone(identifier: "Europe/Zurich")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zurichTimeZone
        
        // Konvertiere die UTC-Zeit in die Zürich-Zeit
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self)
        return calendar.date(from: components) ?? self
    }
} 