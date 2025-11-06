import SwiftUI
import CoreLocation

struct FavoriteStationTileView: View, Equatable {
    let station: FavoriteStation
    let onTap: () -> Void
    @ObservedObject var viewModel: LakeStationsViewModel
    @EnvironmentObject var appSettings: AppSettings
    @State private var nextDeparture: Date?
    @State private var timer: Timer?
    @State private var errorMessage: String?
    @State private var noWavesMessage: String = NoWavesMessageService.shared.getMessage()
    @State private var noServiceMessage: String = NoWavesMessageService.shared.getNoServiceMessage()
    @State private var hasTomorrowDepartures: Bool = true
    @State private var isLoading: Bool = true
    
    // Wetter-Daten
    @State private var weatherInfo: WeatherAPI.WeatherInfo?
    @State private var isLoadingWeather: Bool = true
    @State private var weatherError: String?
    
    // Implementiere Equatable, um unnötige Neuzeichnungen zu vermeiden
    static func == (lhs: FavoriteStationTileView, rhs: FavoriteStationTileView) -> Bool {
        return lhs.station.id == rhs.station.id
    }
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Hauptinformationen
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(station.name)
                            .font(.headline)
                            .foregroundColor(Color("text-color"))
                        
                        if isLoading {
                            Text("Loading...")
                                .font(.subheadline)
                                .foregroundColor(Color("text-color"))
                        } else if let error = errorMessage {
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.red)
                        } else if let departure = nextDeparture {
                            if departure > Date() {
                                HStack(spacing: 4) {
                                    Image(systemName: "water.waves")
                                        .foregroundColor(.blue)
                                    Text("Next wave: \(timeFormatter.string(from: departure))")
                                        .foregroundColor(Color("text-color"))
                                }
                                .font(.subheadline)
                            } else {
                                Text(noWavesMessage)
                                    .font(.subheadline)
                                    .foregroundColor(Color("text-color"))
                            }
                        } else {
                            if hasTomorrowDepartures {
                                Text(noWavesMessage)
                                    .font(.subheadline)
                                    .foregroundColor(Color("text-color"))
                            } else {
                                Text(noServiceMessage)
                                    .font(.subheadline)
                                    .foregroundColor(Color("text-color"))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14, weight: .semibold))
                }
                
                // Wetteranzeige nur anzeigen, wenn showWeatherInfo aktiviert ist
                if appSettings.showWeatherInfo, let weather = weatherInfo {
                    Divider()
                    
                    // Wettervorhersage für morgen anzeigen, wenn keine Wellen mehr für heute, aber Wellen für morgen verfügbar sind
                    // oder wenn die Wetterdaten ein Vorhersagedatum haben
                    if (nextDeparture == nil && hasTomorrowDepartures) || weather.forecastDate != nil {
                        HStack {
                            Text("Weather forecast for tomorrow")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("text-color"))
                            Spacer()
                        }
                    }
                    
                    VStack(spacing: 8) {
                        HStack(alignment: .center, spacing: 4) {
                            // Wetter-Icon
                            Image(systemName: weather.weatherIcon)
                                .font(.system(size: 12))
                                .foregroundColor(Color("text-color"))
                            
                            Text("|")
                                .foregroundColor(.gray)
                                .font(.system(size: 11))
                            
                            // Lufttemperatur Icon
                            Image(systemName: "thermometer.medium")
                                .font(.system(size: 11))
                                .foregroundColor(Color("text-color"))
                            
                            // Temperatur
                            if weather.forecastDate != nil {
                                // Wenn es eine Wettervorhersage ist, zeige Morgen- und Nachmittagstemperatur
                                if let morning = weather.morningTemp, let afternoon = weather.afternoonTemp {
                                    Text(String(format: "%.0f° / %.0f°", morning, afternoon))
                                        .font(.system(size: 11))
                                        .foregroundColor(Color("text-color"))
                                } else {
                                    // Fallback auf Min/Max wenn keine spezifischen Zeiten verfügbar sind
                                    Text(String(format: "%.0f° / %.0f°", weather.tempMin, weather.tempMax))
                                        .font(.system(size: 11))
                                        .foregroundColor(Color("text-color"))
                                }
                            } else {
                                // Für aktuelle Wetterdaten zeige nur die aktuelle Temperatur
                                Text(String(format: "%.1f°", weather.temperature))
                                    .font(.system(size: 11))
                                    .foregroundColor(Color("text-color"))
                            }
                            
                            Text("|")
                                .foregroundColor(.gray)
                                .font(.system(size: 11))
                            
                            // Wassertemperatur
                            if let lake = viewModel.lakes.first(where: { lake in
                                lake.stations.contains(where: { $0.name == station.name })
                            }), let waterTemp = lake.waterTemperature {
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color("text-color"))
                                
                                Text(String(format: "%.0f°", waterTemp))
                                    .font(.system(size: 11))
                                    .foregroundColor(Color("text-color"))
                                
                                Text("|")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 11))
                            }
                            
                            // Wind-Information
                            Image(systemName: "wind")
                                .font(.system(size: 11))
                                .foregroundColor(Color("text-color"))
                            
                            if weather.forecastDate != nil, let maxWind = weather.maxWindSpeedKnots {
                                // Für Wettervorhersage die maximale Windgeschwindigkeit anzeigen
                                Text(String(format: "max %.0f kn", maxWind))
                                    .font(.system(size: 11))
                                    .foregroundColor(Color("text-color"))
                            } else {
                                // Für aktuelle Wetterdaten die aktuelle Windgeschwindigkeit mit Richtung anzeigen
                                Text(String(format: "%.0f kn %@", weather.windSpeedKnots, weather.windDirectionText))
                                    .font(.system(size: 11))
                                    .foregroundColor(Color("text-color"))
                            }
                            
                            // Neoprenanzug-Dicke
                            if let lake = viewModel.lakes.first(where: { lake in
                                lake.stations.contains(where: { $0.name == station.name })
                            }), let waterTemp = lake.waterTemperature,
                               let thickness = getWetsuitThickness(for: waterTemp, airTemp: weather.feelsLike) {
                                
                                Text("|")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 11))
                                
                                Image(systemName: "figure.arms.open")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color("text-color"))
                                
                                Text("\(thickness)mm")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color("text-color"))
                            }
                            
                            // Wasserpegel-Differenz
                            if let lake = viewModel.lakes.first(where: { lake in
                                lake.stations.contains(where: { $0.name == station.name })
                            }), let waterLevelDiff = lake.waterLevelDifference {
                                Text("|")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 11))
                                
                                // Icon basierend auf Wasserpegel-Richtung
                                let isHigher = waterLevelDiff.hasPrefix("+")
                                let iconName = isHigher ? "water.waves.and.arrow.trianglehead.up" : "water.waves.and.arrow.trianglehead.down"
                                
                                Image(systemName: iconName)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color("text-color"))
                                
                                Text("\(waterLevelDiff) cm")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color("text-color"))
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(.top, 4)
                } else if appSettings.showWeatherInfo && isLoadingWeather {
                    Divider()
                    HStack {
                        Text("Loading weather...")
                            .font(.system(size: 14))
                            .foregroundColor(Color("text-color"))
                        Spacer()
                    }
                    .padding(.top, 4)
                } else if appSettings.showWeatherInfo && weatherError != nil {
                    Divider()
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(weatherError ?? "Unknown error")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            await refreshDeparture()
            // Lade Wetterdaten nur, wenn die Einstellung aktiviert ist
            if appSettings.showWeatherInfo {
                await loadWeather()
            }
            
            // Start timer for periodic updates
            timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
                Task { @MainActor in
                    await refreshDeparture()
                    if appSettings.showWeatherInfo {
                        await loadWeather()
                    }
                }
            }
        }
        .onChange(of: appSettings.showWeatherInfo) { oldValue, newValue in
            // Wenn die Einstellung aktiviert wird, lade die Wetterdaten
            if newValue {
                Task { @MainActor in
                    await loadWeather()
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    @MainActor
    private func refreshDeparture() async {
        isLoading = true
        let departure = await viewModel.getNextDepartureForToday(for: station.id)
        
        // Prüfe, ob sich der Wellen-Status geändert hat
        var statusChanged = (nextDeparture == nil && departure != nil) || 
                           (nextDeparture != nil && departure == nil)
        
        // Nur aktualisieren, wenn sich der Wert tatsächlich geändert hat
        if departure != nextDeparture {
            // Only update the nextDeparture if it's a future departure or nil
            if departure == nil || departure! > Date() {
                nextDeparture = departure
                
                // If no departures today, check if there are departures tomorrow
                if departure == nil {
                    let hasTomorrowDeps = await viewModel.hasDeparturesTomorrow(for: station.id)
                    if hasTomorrowDeps != hasTomorrowDepartures {
                        hasTomorrowDepartures = hasTomorrowDeps
                        statusChanged = true
                    }
                }
            } else {
                // If the departure is in the past, mark as no more departures
                nextDeparture = nil
                // Check if there are departures tomorrow
                let hasTomorrowDeps = await viewModel.hasDeparturesTomorrow(for: station.id)
                if hasTomorrowDeps != hasTomorrowDepartures {
                    hasTomorrowDepartures = hasTomorrowDeps
                    statusChanged = true
                }
            }
            
            // Wenn sich der Status geändert hat, lade die Wetterdaten neu
            if statusChanged {
                await loadWeather()
            }
        }
        
        errorMessage = nil
        isLoading = false
    }
    
    @MainActor
    private func loadWeather() async {
        isLoadingWeather = true
        

        
        // Versuche, die Koordinaten direkt aus der FavoriteStation zu verwenden
        if let latitude = station.latitude, let longitude = station.longitude {

            let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            await fetchWeather(for: location)
        } 
        // Wenn keine direkten Koordinaten verfügbar sind, versuche die Station anhand der UIC-Referenz zu finden
        else if let uicRef = station.uic_ref {
            // Suche in allen Lakes nach einer Station mit der gleichen UIC-Referenz
            for lake in viewModel.lakes {
                if let matchingStation = lake.stations.first(where: { $0.uic_ref == uicRef }) {
                    if let coordinates = matchingStation.coordinates {
                        let location = CLLocationCoordinate2D(
                            latitude: coordinates.latitude,
                            longitude: coordinates.longitude
                        )
                        await fetchWeather(for: location)
                        return
                    }
                }
            }
            weatherError = "No coordinates found for station"
        } else {
            // Versuche, die Station anhand des Namens zu finden
            for lake in viewModel.lakes {
                if let matchingStation = lake.stations.first(where: { $0.name == station.name }) {
                    if let coordinates = matchingStation.coordinates {
                        let location = CLLocationCoordinate2D(
                            latitude: coordinates.latitude,
                            longitude: coordinates.longitude
                        )
                        await fetchWeather(for: location)
                        return
                    }
                }
            }
            weatherError = "No coordinates available"
        }
        
        isLoadingWeather = false
    }
    
    @MainActor
    private func fetchWeather(for location: CLLocationCoordinate2D) async {
        do {
            // Hole sowohl aktuelle als auch Vorhersagedaten in einem Aufruf
            let (current, tomorrow) = try await WeatherAPI.shared.getWeatherData(for: location, stationId: station.id)
            
            // Wenn keine Wellen mehr für heute, aber Wellen für morgen verfügbar sind,
            // zeigen wir die Wettervorhersage für morgen an
            if nextDeparture == nil && hasTomorrowDepartures {
                if let tomorrowWeather = tomorrow {
                    weatherInfo = tomorrowWeather
                } else {
                    // Fallback auf aktuelle Daten, falls keine Vorhersage verfügbar ist
                    weatherInfo = current
                    weatherError = "No forecast available, showing current weather"
                }
            } else {
                // Ansonsten zeigen wir die aktuellen Wetterdaten an
                weatherInfo = current
            }
            
            weatherError = nil
        } catch {
            weatherError = "Failed to load weather"
        }
        
        isLoadingWeather = false
    }
    
    private func getWetsuitThickness(for waterTemp: Double, airTemp: Double? = nil) -> String? {
        // Regel: Wenn Lufttemperatur + Wassertemperatur < 30 °C, eine Stufe dicker wählen
        var adjustedWaterTemp = waterTemp
        
        if let air = airTemp, (air + waterTemp) < 30 {
            adjustedWaterTemp = waterTemp - 3
        }
        
        switch adjustedWaterTemp {
        case 23...:
            return nil
        case 18..<23:
            return "0.5-2"
        case 15..<18:
            return "3/2"
        case 12..<15:
            return "4/3"
        case 10..<12:
            return "5/4"
        case 1..<10:
            return "6/5"
        default:
            return "6/5"
        }
    }
} 