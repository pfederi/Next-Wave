import Foundation
import CoreLocation

class WeatherAPI {
    static let shared = WeatherAPI()
    
    // OpenWeather API URLs
    private let baseURL = "https://api.openweathermap.org/data/2.5"
    private let apiKey: String = Config.openWeatherApiKey
    
    // Speichert historische Luftdruckwerte für jede Station
    private var pressureHistory: [String: [(timestamp: Date, pressure: Int)]] = [:]
    
    private init() {}
    
    // Preload Methode die beim App-Start aufgerufen wird
    func preloadData() async {
        print("🌤️ Preloading weather data for favorite stations...")
        
        // Lade Wetter für alle Favoriten-Stationen parallel
        let favorites = FavoriteStationsManager.shared.favorites
        
        await withTaskGroup(of: Void.self) { group in
            for favorite in favorites {
                guard let lat = favorite.latitude, let lon = favorite.longitude else { continue }
                
                group.addTask {
                    let location = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    do {
                        _ = try await self.getWeatherData(for: location, stationId: favorite.id)
                        print("✅ Weather preloaded for \(favorite.name)")
                    } catch {
                        print("⚠️ Failed to preload weather for \(favorite.name): \(error)")
                    }
                }
            }
        }
        
        print("✅ Weather data preload completed")
    }
    
    struct WeatherInfo {
        let temperature: Double // in Celsius
        let feelsLike: Double // in Celsius, gefühlte Temperatur (inkl. Windchill)
        let tempMin: Double // in Celsius
        let tempMax: Double // in Celsius
        let morningTemp: Double? // in Celsius, für Morgen (ca. 8-10 Uhr)
        let afternoonTemp: Double? // in Celsius, für Nachmittag (ca. 14-16 Uhr)
        let windSpeed: Double // in m/s
        let maxWindSpeed: Double? // maximale Windgeschwindigkeit in m/s für den Tag
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
        
        // Maximale Windgeschwindigkeit in Knoten
        var maxWindSpeedKnots: Double? {
            guard let maxWind = maxWindSpeed else { return nil }
            return maxWind * 1.94384
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
    
    // Struktur für die OpenWeather API Antwort
    private struct ForecastResponse: Codable {
        struct Weather: Codable {
            let id: Int
            let main: String
            let description: String
            let icon: String
        }
        
        struct Main: Codable {
            let temp: Double
            let feels_like: Double
            let temp_min: Double
            let temp_max: Double
            let pressure: Int
            let humidity: Int
        }
        
        struct Wind: Codable {
            let speed: Double
            let deg: Int
            let gust: Double?
        }
        
        struct ForecastItem: Codable {
            let dt: Int
            let main: Main
            let weather: [Weather]
            let wind: Wind
            let dt_txt: String
        }
        
        let list: [ForecastItem]
    }
    
    // Konvertiert den OpenWeather Wettercode in eine Beschreibung und ein Icon
    private func weatherDescriptionAndIcon(from code: Int) -> (description: String, icon: String) {
        // OpenWeather Wettercodes: https://openweathermap.org/weather-conditions
        switch code {
        case 200...232: // Thunderstorm
            return ("Thunderstorm", "cloud.bolt.fill")
        case 300...321: // Drizzle
            return ("Drizzle", "cloud.drizzle.fill")
        case 500...504: // Rain
            return ("Rain", "cloud.rain.fill")
        case 511: // Freezing rain
            return ("Freezing rain", "cloud.sleet.fill")
        case 520...531: // Shower rain
            return ("Shower rain", "cloud.heavyrain.fill")
        case 600...622: // Snow
            return ("Snow", "cloud.snow.fill")
        case 701...781: // Atmosphere (mist, smoke, haze, etc.)
            return ("Foggy", "cloud.fog.fill")
        case 800: // Clear sky
            return ("Clear sky", "sun.max.fill")
        case 801: // Few clouds
            return ("Few clouds", "cloud.sun.fill")
        case 802: // Scattered clouds
            return ("Scattered clouds", "cloud.fill")
        case 803, 804: // Broken/overcast clouds
            return ("Cloudy", "smoke.fill")
        default:
            return ("Unknown", "cloud.fill")
        }
    }
    
    // Ruft aktuelle Wetterdaten und Vorhersagen ab
    func getWeatherData(for location: CLLocationCoordinate2D, stationId: String = "default") async throws -> (current: WeatherInfo, tomorrow: WeatherInfo?) {
        var components = URLComponents(string: "\(baseURL)/forecast")
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(location.latitude)),
            URLQueryItem(name: "lon", value: String(location.longitude)),
            URLQueryItem(name: "appid", value: apiKey),
            URLQueryItem(name: "units", value: "metric")
        ]
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        
        // Configure URLRequest with HTTP caching
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 15.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            if httpResponse.statusCode != 200 {
                throw URLError(.badServerResponse)
            }
            
            let forecast = try JSONDecoder().decode(ForecastResponse.self, from: data)
            guard let currentForecast = forecast.list.first,
                  let currentWeather = currentForecast.weather.first else {
                throw URLError(.cannotParseResponse)
            }
            
            let (weatherDescription, weatherIcon) = weatherDescriptionAndIcon(from: currentWeather.id)
            
            // Wetterdaten in WeatherInfo-Struktur umwandeln
            var currentWeatherInfo = WeatherInfo(
                temperature: currentForecast.main.temp,
                feelsLike: currentForecast.main.feels_like,
                tempMin: currentForecast.main.temp_min,
                tempMax: currentForecast.main.temp_max,
                morningTemp: nil,
                afternoonTemp: nil,
                windSpeed: currentForecast.wind.speed,
                maxWindSpeed: nil,
                windDirection: currentForecast.wind.deg,
                windGust: currentForecast.wind.gust,
                pressure: currentForecast.main.pressure,
                weatherDescription: weatherDescription,
                weatherIcon: weatherIcon,
                forecastDate: nil
            )
            
            // Berechne den Luftdrucktrend für aktuelle Daten
            currentWeatherInfo.pressureTrend = calculatePressureTrend(for: stationId, currentPressure: currentForecast.main.pressure)
            
            // Vorhersage für morgen (etwa 24h später)
            var tomorrowWeatherInfo: WeatherInfo? = nil
            if let tomorrowForecast = forecast.list.first(where: { item in
                let itemDate = Date(timeIntervalSince1970: Double(item.dt))
                return Calendar.current.isDate(itemDate, inSameDayAs: Date().addingTimeInterval(24 * 3600))
            }), let tomorrowWeather = tomorrowForecast.weather.first {
                // Versuche, Daten für Morgen (8-10 Uhr) und Nachmittag (14-16 Uhr) zu finden
                var morningTemp: Double? = nil
                var afternoonTemp: Double? = nil
                
                // Maximale Windgeschwindigkeit für morgen finden
                var maxWindSpeed: Double = tomorrowForecast.wind.speed
                
                // Datum für morgen erstellen
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
                
                // Zeitkomponenten für morgen
                var morningComponents = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
                morningComponents.hour = 9 // 9 Uhr morgens
                let morningDate = Calendar.current.date(from: morningComponents)!
                
                var afternoonComponents = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
                afternoonComponents.hour = 15 // 15 Uhr nachmittags
                let afternoonDate = Calendar.current.date(from: afternoonComponents)!
                
                // Durchsuche alle Vorhersagen, um die nächsten zu den gewünschten Uhrzeiten zu finden
                for item in forecast.list {
                    let itemDate = Date(timeIntervalSince1970: Double(item.dt))
                    
                    // Prüfe, ob das Datum zu morgen gehört
                    if Calendar.current.isDate(itemDate, inSameDayAs: tomorrow) {
                        // Berechne Zeitdifferenz zwischen Vorhersage und Zielzeiten
                        let morningDiff = abs(itemDate.timeIntervalSince(morningDate))
                        let afternoonDiff = abs(itemDate.timeIntervalSince(afternoonDate))
                        
                        // Wenn die Differenz weniger als 3 Stunden beträgt, verwende diese Daten
                        if morningDiff < 3 * 3600 && (morningTemp == nil || morningDiff < abs(morningDate.timeIntervalSince(itemDate))) {
                            morningTemp = item.main.temp
                        }
                        
                        if afternoonDiff < 3 * 3600 && (afternoonTemp == nil || afternoonDiff < abs(afternoonDate.timeIntervalSince(itemDate))) {
                            afternoonTemp = item.main.temp
                        }
                        
                        // Prüfe, ob die Windgeschwindigkeit höher ist als die bisher höchste
                        if item.wind.speed > maxWindSpeed {
                            maxWindSpeed = item.wind.speed
                        }
                    }
                }
                
                let (tomorrowDescription, tomorrowIcon) = weatherDescriptionAndIcon(from: tomorrowWeather.id)
                tomorrowWeatherInfo = WeatherInfo(
                    temperature: tomorrowForecast.main.temp,
                    feelsLike: tomorrowForecast.main.feels_like,
                    tempMin: tomorrowForecast.main.temp_min,
                    tempMax: tomorrowForecast.main.temp_max,
                    morningTemp: morningTemp,
                    afternoonTemp: afternoonTemp,
                    windSpeed: tomorrowForecast.wind.speed,
                    maxWindSpeed: maxWindSpeed,
                    windDirection: tomorrowForecast.wind.deg,
                    windGust: tomorrowForecast.wind.gust,
                    pressure: tomorrowForecast.main.pressure,
                    weatherDescription: tomorrowDescription,
                    weatherIcon: tomorrowIcon,
                    pressureTrend: .stable,
                    forecastDate: Date(timeIntervalSince1970: Double(tomorrowForecast.dt))
                )
            }
            
            return (currentWeatherInfo, tomorrowWeatherInfo)
        } catch {
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
        guard let forecast = tomorrow else {
            throw URLError(.cannotParseResponse)
        }
        return forecast
    }
    
    func getWeatherIconURL(icon: String) -> URL? {
        return URL(string: "https://openweathermap.org/img/wn/\(icon)@2x.png")
    }
    
    // Neue Methode für Wetterdaten zu einem bestimmten Zeitpunkt
    func getWeatherForTime(location: CLLocationCoordinate2D, time: Date) async throws -> WeatherInfo {
        var components = URLComponents(string: "\(baseURL)/forecast")
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(location.latitude)),
            URLQueryItem(name: "lon", value: String(location.longitude)),
            URLQueryItem(name: "appid", value: apiKey),
            URLQueryItem(name: "units", value: "metric")
        ]
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        
        // Configure URLRequest with HTTP caching
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 15.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        
        let forecast = try JSONDecoder().decode(ForecastResponse.self, from: data)
        
        // Finde den nächstgelegenen Zeitpunkt
        let targetTimestamp = time.timeIntervalSince1970
        let closestForecast = forecast.list.min { item1, item2 in
            abs(Double(item1.dt) - targetTimestamp) < abs(Double(item2.dt) - targetTimestamp)
        }
        
        guard let forecast = closestForecast,
              let weather = forecast.weather.first else {
            throw URLError(.cannotParseResponse)
        }
        
        let (weatherDescription, weatherIcon) = weatherDescriptionAndIcon(from: weather.id)
        
        return WeatherInfo(
            temperature: forecast.main.temp,
            feelsLike: forecast.main.feels_like,
            tempMin: forecast.main.temp_min,
            tempMax: forecast.main.temp_max,
            morningTemp: nil,
            afternoonTemp: nil,
            windSpeed: forecast.wind.speed,
            maxWindSpeed: nil,
            windDirection: forecast.wind.deg,
            windGust: forecast.wind.gust,
            pressure: forecast.main.pressure,
            weatherDescription: weatherDescription,
            weatherIcon: weatherIcon,
            forecastDate: Date(timeIntervalSince1970: Double(forecast.dt))
        )
    }
    
    private func findClosestHourIndex(for date: Date, in times: [Double]) -> Int {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        return hour
    }
    
    private func getWeatherDescription(temperature: Double, windSpeed: Double) -> String {
        if windSpeed > 20 {
            return "Windy"
        } else if temperature < 5 {
            return "Cold"
        } else if temperature > 25 {
            return "Hot"
        } else {
            return "Pleasant"
        }
    }
    
    private func getWeatherIcon(temperature: Double, windSpeed: Double) -> String {
        if windSpeed > 20 {
            return "50d" // windy
        } else if temperature < 5 {
            return "13d" // cold
        } else if temperature > 25 {
            return "01d" // hot/sunny
        } else {
            return "02d" // partly cloudy
        }
    }
} 