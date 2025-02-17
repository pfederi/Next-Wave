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
    
    // Zentrale Koordinaten der Schweiz (ungefähr Mitte Vierwaldstättersee)
    private let swissLatitude = 47.0136
    private let swissLongitude = 8.4324
    
    private init() {}
    
    func getSunTimes(date: Date) async throws -> SunTimes {
        // Create cache key from date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let cacheKey = dateFormatter.string(from: date)
        
        // Return cached value if available
        if let cachedTimes = cache[cacheKey] {
            return cachedTimes
        }
        
        // Format date for API
        let formattedDate = dateFormatter.string(from: date)
        
        // Create URL with fixed Swiss coordinates
        let urlString = "https://api.sunrise-sunset.org/json?lat=\(swissLatitude)&lng=\(swissLongitude)&date=\(formattedDate)&formatted=0"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        // Make request
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(SunTimeResponse.self, from: data)
        
        // Convert UTC times to local time
        let sunTimes = SunTimes(
            sunrise: response.results.sunrise.toLocalTime(),
            sunset: response.results.sunset.toLocalTime(),
            civilTwilightBegin: response.results.civil_twilight_begin.toLocalTime(),
            civilTwilightEnd: response.results.civil_twilight_end.toLocalTime()
        )
        
        // Cache the result
        cache[cacheKey] = sunTimes
        
        return sunTimes
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
        let timezone = TimeZone.current
        let seconds = TimeInterval(timezone.secondsFromGMT(for: self))
        return Date(timeInterval: seconds, since: self)
    }
} 