import Foundation
import CoreLocation

class WeatherAPI {
    static let shared = WeatherAPI()
    
    private let apiKey = APIConfig.openWeatherMapAPIKey
    private let oneCallURL = "https://api.openweathermap.org/data/3.0/onecall"
    
    // Speichert historische Luftdruckwerte für jede Station
    private var pressureHistory: [String: [(timestamp: Date, pressure: Int)]] = [:]
    
    private init() {}
    
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
        let forecastDate: Date? // Datum der Vorhersage, nil für aktuelle Daten
        
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
    
    // Struktur für die One Call API 3.0 Antwort
    struct OneCallResponse: Codable {
        let lat: Double
        let lon: Double
        let timezone: String
        let timezone_offset: Int
        let current: CurrentWeather
        let minutely: [MinutelyForecast]?
        let hourly: [HourlyForecast]?
        let daily: [DailyForecast]?
        let alerts: [Alert]?
        
        struct CurrentWeather: Codable {
            let dt: Int
            let sunrise: Int
            let sunset: Int
            let temp: Double
            let feels_like: Double
            let pressure: Int
            let humidity: Int
            let dew_point: Double
            let uvi: Double
            let clouds: Int
            let visibility: Int
            let wind_speed: Double
            let wind_deg: Int
            let wind_gust: Double?
            let weather: [Weather]
            let rain: Rain?
            let snow: Snow?
            
            struct Rain: Codable {
                let oneHour: Double?
                
                enum CodingKeys: String, CodingKey {
                    case oneHour = "1h"
                }
            }
            
            struct Snow: Codable {
                let oneHour: Double?
                
                enum CodingKeys: String, CodingKey {
                    case oneHour = "1h"
                }
            }
        }
        
        struct MinutelyForecast: Codable {
            let dt: Int
            let precipitation: Double
        }
        
        struct HourlyForecast: Codable {
            let dt: Int
            let temp: Double
            let feels_like: Double
            let pressure: Int
            let humidity: Int
            let dew_point: Double
            let uvi: Double
            let clouds: Int
            let visibility: Int
            let wind_speed: Double
            let wind_deg: Int
            let wind_gust: Double?
            let weather: [Weather]
            let pop: Double
            let rain: CurrentWeather.Rain?
            let snow: CurrentWeather.Snow?
        }
        
        struct DailyForecast: Codable {
            let dt: Int
            let sunrise: Int
            let sunset: Int
            let moonrise: Int
            let moonset: Int
            let moon_phase: Double
            let summary: String
            let temp: Temperature
            let feels_like: FeelsLike
            let pressure: Int
            let humidity: Int
            let dew_point: Double
            let wind_speed: Double
            let wind_deg: Int
            let wind_gust: Double?
            let weather: [Weather]
            let clouds: Int
            let pop: Double
            let rain: Double?
            let snow: Double?
            let uvi: Double
            
            struct Temperature: Codable {
                let day: Double
                let min: Double
                let max: Double
                let night: Double
                let eve: Double
                let morn: Double
            }
            
            struct FeelsLike: Codable {
                let day: Double
                let night: Double
                let eve: Double
                let morn: Double
            }
        }
        
        struct Weather: Codable {
            let id: Int
            let main: String
            let description: String
            let icon: String
        }
        
        struct Alert: Codable {
            let sender_name: String
            let event: String
            let start: Int
            let end: Int
            let description: String
            let tags: [String]?
        }
    }
    
    // Ruft aktuelle Wetterdaten und Vorhersagen ab
    func getWeatherData(for location: CLLocationCoordinate2D, stationId: String = "default") async throws -> (current: WeatherInfo, tomorrow: WeatherInfo?) {
        var components = URLComponents(string: oneCallURL)
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(location.latitude)),
            URLQueryItem(name: "lon", value: String(location.longitude)),
            URLQueryItem(name: "appid", value: apiKey),
            URLQueryItem(name: "units", value: "metric"),
            URLQueryItem(name: "exclude", value: "minutely") // Wir brauchen keine minütlichen Daten
        ]
        
        guard let url = components?.url else {
            print("Failed to construct URL with components: \(String(describing: components))")
            throw URLError(.badURL)
        }
        
        print("Making One Call API request to: \(url.absoluteString)")
        
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
                let oneCallResponse = try JSONDecoder().decode(OneCallResponse.self, from: data)
                
                // Aktuelle Wetterdaten
                var currentWeatherInfo = WeatherInfo(
                    temperature: oneCallResponse.current.temp,
                    tempMin: oneCallResponse.daily?.first?.temp.min ?? oneCallResponse.current.temp,
                    tempMax: oneCallResponse.daily?.first?.temp.max ?? oneCallResponse.current.temp,
                    windSpeed: oneCallResponse.current.wind_speed,
                    windDirection: oneCallResponse.current.wind_deg,
                    windGust: oneCallResponse.current.wind_gust,
                    pressure: oneCallResponse.current.pressure,
                    weatherDescription: oneCallResponse.current.weather.first?.description ?? "Unknown",
                    weatherIcon: oneCallResponse.current.weather.first?.icon ?? "01d",
                    forecastDate: nil
                )
                
                // Berechne den Luftdrucktrend für aktuelle Daten
                currentWeatherInfo.pressureTrend = calculatePressureTrend(for: stationId, currentPressure: oneCallResponse.current.pressure)
                
                // Vorhersage für morgen (zweiter Tag in der täglichen Vorhersage)
                var tomorrowWeatherInfo: WeatherInfo? = nil
                
                if let dailyForecasts = oneCallResponse.daily, dailyForecasts.count > 1 {
                    let tomorrowForecast = dailyForecasts[1]
                    let tomorrowDate = Date(timeIntervalSince1970: TimeInterval(tomorrowForecast.dt))
                    
                    tomorrowWeatherInfo = WeatherInfo(
                        temperature: tomorrowForecast.temp.day,
                        tempMin: tomorrowForecast.temp.min,
                        tempMax: tomorrowForecast.temp.max,
                        windSpeed: tomorrowForecast.wind_speed,
                        windDirection: tomorrowForecast.wind_deg,
                        windGust: tomorrowForecast.wind_gust,
                        pressure: tomorrowForecast.pressure,
                        weatherDescription: tomorrowForecast.weather.first?.description ?? "Unknown",
                        weatherIcon: tomorrowForecast.weather.first?.icon ?? "01d",
                        pressureTrend: .stable, // Für Vorhersagen verwenden wir einen stabilen Trend
                        forecastDate: tomorrowDate
                    )
                }
                
                return (currentWeatherInfo, tomorrowWeatherInfo)
            } catch {
                print("JSON decoding error: \(error)")
                throw error
            }
        } catch {
            print("Network error: \(error)")
            throw error
        }
    }
    
    // Hilfsmethode für aktuelle Wetterdaten
    func getWeather(for location: CLLocationCoordinate2D, stationId: String = "default") async throws -> WeatherInfo {
        let (current, _) = try await getWeatherData(for: location, stationId: stationId)
        return current
    }
    
    // Hilfsmethode für Wettervorhersage für morgen
    func getForecast(for location: CLLocationCoordinate2D, stationId: String = "default") async throws -> WeatherInfo {
        let (_, tomorrow) = try await getWeatherData(for: location, stationId: stationId)
        
        guard let tomorrowWeather = tomorrow else {
            throw URLError(.cannotParseResponse)
        }
        
        return tomorrowWeather
    }
    
    func getWeatherIconURL(icon: String) -> URL? {
        return URL(string: "https://openweathermap.org/img/wn/\(icon)@2x.png")
    }
} 