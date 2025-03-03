import Foundation
import CoreLocation

class WeatherAPI {
    static let shared = WeatherAPI()
    
    private let apiKey = APIConfig.openWeatherMapAPIKey
    private let baseURL = "https://api.openweathermap.org/data/2.5/weather"
    
    // Speichert historische Luftdruckwerte für jede Station
    private var pressureHistory: [String: [(timestamp: Date, pressure: Int)]] = [:]
    
    private init() {}
    
    struct WeatherData: Codable {
        let main: Main
        let wind: Wind
        let weather: [Weather]
        
        struct Main: Codable {
            let temp: Double
            let temp_min: Double
            let temp_max: Double
            let pressure: Int
        }
        
        struct Wind: Codable {
            let speed: Double
            let deg: Int
            let gust: Double?
        }
        
        struct Weather: Codable {
            let id: Int
            let main: String
            let description: String
            let icon: String
        }
    }
    
    struct WeatherInfo {
        let temperature: Double // in Celsius
        let tempMin: Double // in Celsius
        let tempMax: Double // in Celsius
        let windSpeed: Double // in m/s
        let windDirection: Int // in degrees
        let windGust: Double? // in m/s, optional da nicht immer verfügbar
        let pressure: Int // in hPa
        let weatherDescription: String
        let weatherIcon: String
        var pressureTrend: PressureTrend = .stable // Standardwert, wird später aktualisiert
        
        enum PressureTrend {
            case rising
            case falling
            case stable
        }
        
        // Umrechnung von m/s in Knoten (1 m/s = 1.94384 kn)
        var windSpeedKnots: Double {
            return windSpeed * 1.94384
        }
        
        // Umrechnung der Windböen von m/s in Knoten
        var windGustKnots: Double? {
            guard let gust = windGust else { return nil }
            return gust * 1.94384
        }
        
        var windDirectionText: String {
            switch windDirection {
            case 0..<23, 338..<360:
                return "N"
            case 23..<68:
                return "NE"
            case 68..<113:
                return "E"
            case 113..<158:
                return "SE"
            case 158..<203:
                return "S"
            case 203..<248:
                return "SW"
            case 248..<293:
                return "W"
            case 293..<338:
                return "NW"
            default:
                return "N/A"
            }
        }
    }
    
    // Berechnet den Luftdrucktrend basierend auf historischen Daten
    private func calculatePressureTrend(for stationId: String, currentPressure: Int) -> WeatherInfo.PressureTrend {
        guard var history = pressureHistory[stationId], !history.isEmpty else {
            // Wenn keine Historie vorhanden ist, speichern wir den aktuellen Wert und geben "stabil" zurück
            pressureHistory[stationId] = [(Date(), currentPressure)]
            return .stable
        }
        
        // Füge den aktuellen Wert zur Historie hinzu
        history.append((Date(), currentPressure))
        
        // Entferne Einträge, die älter als 6 Stunden sind
        let sixHoursAgo = Date().addingTimeInterval(-6 * 60 * 60)
        history = history.filter { $0.timestamp > sixHoursAgo }
        
        // Aktualisiere die Historie
        pressureHistory[stationId] = history
        
        // Wenn wir nur einen Eintrag haben, können wir keinen Trend berechnen
        if history.count < 2 {
            return .stable
        }
        
        // Sortiere nach Zeitstempel
        let sortedHistory = history.sorted { $0.timestamp < $1.timestamp }
        
        // Vergleiche den ältesten mit dem neuesten Wert
        let oldestPressure = sortedHistory.first!.pressure
        let newestPressure = sortedHistory.last!.pressure
        
        // Berechne den Unterschied
        let difference = newestPressure - oldestPressure
        
        // Definiere einen Schwellenwert für signifikante Änderungen (z.B. 2 hPa)
        let threshold = 2
        
        if difference > threshold {
            return .rising
        } else if difference < -threshold {
            return .falling
        } else {
            return .stable
        }
    }
    
    func getWeather(for location: CLLocationCoordinate2D, stationId: String = "default") async throws -> WeatherInfo {
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(location.latitude)),
            URLQueryItem(name: "lon", value: String(location.longitude)),
            URLQueryItem(name: "appid", value: apiKey),
            URLQueryItem(name: "units", value: "metric")
        ]
        
        guard let url = components?.url else {
            print("Failed to construct URL with components: \(String(describing: components))")
            throw URLError(.badURL)
        }
        
        print("Making weather request to: \(url.absoluteString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type")
                throw URLError(.badServerResponse)
            }
            
            if httpResponse.statusCode != 200 {
                let responseString = String(data: data, encoding: .utf8) ?? "No response body"
                print("Server returned status code \(httpResponse.statusCode): \(responseString)")
                throw URLError(.badServerResponse)
            }
            
            do {
                let weatherData = try JSONDecoder().decode(WeatherData.self, from: data)
                
                var weatherInfo = WeatherInfo(
                    temperature: weatherData.main.temp,
                    tempMin: weatherData.main.temp_min,
                    tempMax: weatherData.main.temp_max,
                    windSpeed: weatherData.wind.speed,
                    windDirection: weatherData.wind.deg,
                    windGust: weatherData.wind.gust,
                    pressure: weatherData.main.pressure,
                    weatherDescription: weatherData.weather.first?.description ?? "Unknown",
                    weatherIcon: weatherData.weather.first?.icon ?? "01d"
                )
                
                // Berechne den Luftdrucktrend
                weatherInfo.pressureTrend = calculatePressureTrend(for: stationId, currentPressure: weatherData.main.pressure)
                
                return weatherInfo
            } catch {
                print("JSON decoding error: \(error)")
                throw error
            }
        } catch {
            print("Network error: \(error)")
            throw error
        }
    }
    
    func getWeatherIconURL(icon: String) -> URL? {
        return URL(string: "https://openweathermap.org/img/wn/\(icon)@2x.png")
    }
} 