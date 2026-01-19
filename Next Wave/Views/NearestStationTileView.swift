import SwiftUI
import CoreLocation

struct NearestStationTileView: View {
    let station: Lake.Station
    let distance: Double
    let onTap: () -> Void
    @ObservedObject var viewModel: LakeStationsViewModel
    @EnvironmentObject var appSettings: AppSettings
    @State private var nextDeparture: Date?
    @State private var timer: Timer?
    @State private var noWavesMessage: String = NoWavesMessageService.shared.getMessage()
    @State private var noServiceMessage: String = NoWavesMessageService.shared.getNoServiceMessage()
    @State private var hasTomorrowDepartures: Bool = true
    @State private var isLoading: Bool = true
    
    // Wetter-Daten
    @State private var weatherInfo: WeatherAPI.WeatherInfo?
    @State private var isLoadingWeather: Bool = true
    @State private var weatherError: String?
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    private let distanceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter
    }()
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            Text(station.name)
                                .font(.headline)
                                .foregroundColor(Color("text-color"))
                            Text("(\(distanceFormatter.string(from: NSNumber(value: distance)) ?? "0.0") km)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if isLoading {
                            Text("Loading...")
                                .font(.subheadline)
                                .foregroundColor(Color("text-color"))
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
                        .font(.system(size: 16, weight: .semibold))
                }
                
                // Wetteranzeige nur anzeigen, wenn showWeatherInfo aktiviert ist
                if appSettings.showWeatherInfo, let weather = weatherInfo {
                    Divider()
                    
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
                                
                                Text(String(format: "%.1f°", waterTemp))
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
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
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
            // First check cache - if data is available, use it immediately
            let cacheKey = viewModel.getCacheKey(for: station.id, date: Date())
            let hasCachedData = viewModel.hasCachedData(for: cacheKey)
            
            if hasCachedData {
                // Use cached data immediately - no API call needed
                await refreshDeparture()
            } else {
                // No cached data - wait for background loading if it's in progress
                if viewModel.isBackgroundLoadingInProgress() {
                    // Wait up to 3 seconds for background loading to complete
                    for _ in 0..<6 {
                        try? await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5 seconds
                        if viewModel.hasCachedData(for: cacheKey) {
                            // Background loading provided the data
                            await refreshDeparture()
                            break
                        }
                        if !viewModel.isBackgroundLoadingInProgress() {
                            // Background loading finished, check cache one more time
                            if viewModel.hasCachedData(for: cacheKey) {
                                await refreshDeparture()
                            } else {
                                // Still no data - load it now
                                await refreshDeparture()
                            }
                            break
                        }
                    }
                } else {
                    // Background loading not in progress - load immediately
            await refreshDeparture()
                }
            }
            
            // Lade Wetterdaten nur, wenn die Einstellung aktiviert ist
            if appSettings.showWeatherInfo {
                await loadWeather()
            }
            
            // Start timer for periodic updates on main thread
            await MainActor.run {
                // Invalidate any existing timer first
                timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
                Task { @MainActor in
                    await refreshDeparture()
                    if appSettings.showWeatherInfo {
                        await loadWeather()
                        }
                    }
                }
            }
        }
        .onChange(of: appSettings.showWeatherInfo) { oldValue, newValue in
            // Wenn die Einstellung aktiviert wird, lade die Wetterdaten
            if newValue {
                Task {
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
        // Check cache first before showing loading
        let cacheKey = viewModel.getCacheKey(for: station.id, date: Date())
        let hasCachedData = viewModel.hasCachedData(for: cacheKey)
        
        // Only show loading if we don't have cached data and no departure time yet
        if !hasCachedData && nextDeparture == nil {
        isLoading = true
        }
        
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
        
        isLoading = false
    }
    
    @MainActor
    private func loadWeather() async {
        isLoadingWeather = true
        
        if let coordinates = station.coordinates {
            let location = CLLocationCoordinate2D(
                latitude: coordinates.latitude,
                longitude: coordinates.longitude
            )
            
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
        } else {
            weatherError = "No coordinates available"
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