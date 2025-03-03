import SwiftUI
import CoreLocation

struct FavoriteStationTileView: View, Equatable {
    let station: FavoriteStation
    let onTap: () -> Void
    @ObservedObject var viewModel: LakeStationsViewModel
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
                
                // Wetter-Informationen
                if let weather = weatherInfo {
                    Divider()
                    
                    VStack(spacing: 4) {
                        // Wenn es keine Abfahrten für heute gibt, aber für morgen, oder wenn das Wetter ein Vorhersagedatum hat
                        if ((nextDeparture == nil && hasTomorrowDepartures) || weather.forecastDate != nil) {
                            HStack {
                                Text("Weather forecast for tomorrow")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.gray)
                                Spacer()
                            }
                            .padding(.bottom, 4)
                        }
                        
                        HStack(alignment: .center, spacing: 8) {
                            // Wetter-Icon und Beschreibung
                            AsyncImage(url: WeatherAPI.shared.getWeatherIconURL(icon: weather.weatherIcon)) { image in
                                image.resizable().frame(width: 32, height: 32)
                            } placeholder: {
                                Image(systemName: "cloud").frame(width: 32, height: 32)
                            }
                            
                            Text(weather.weatherDescription.capitalized)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("text-color"))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            // Temperatur
                            HStack(spacing: 4) {
                                Image(systemName: "thermometer")
                                    .foregroundColor(Color.gray)
                                    .frame(width: 20, height: 20)
                                
                                Text(String(format: "%.1f°C", weather.temperature))
                                    .font(.system(size: 14))
                                    .foregroundColor(Color("text-color"))
                            }
                            
                            // Wind-Information
                            HStack(spacing: 4) {
                                Image(systemName: "wind")
                                    .foregroundColor(Color.gray)
                                    .frame(width: 20, height: 20)
                                
                                Text(String(format: "%.1f kn %@", weather.windSpeedKnots, weather.windDirectionText))
                                    .font(.system(size: 14))
                                    .foregroundColor(Color("text-color"))
                            }
                        }
                    }
                    .padding(.top, 4)
                } else if isLoadingWeather {
                    Divider()
                    HStack {
                        Text("Loading weather...")
                            .font(.system(size: 14))
                            .foregroundColor(Color("text-color"))
                        Spacer()
                    }
                    .padding(.top, 4)
                } else if let error = weatherError {
                    Divider()
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(error)
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
            await loadWeather()
            
            // Start timer for periodic updates
            timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
                Task {
                    await refreshDeparture()
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
        
        print("Loading weather for station: \(station.name)")
        print("Station coordinates: lat=\(station.latitude ?? 0), lon=\(station.longitude ?? 0)")
        print("Station UIC ref: \(station.uic_ref ?? "none")")
        
        // Versuche, die Koordinaten direkt aus der FavoriteStation zu verwenden
        if let latitude = station.latitude, let longitude = station.longitude {
            print("Using direct coordinates: \(latitude), \(longitude)")
            let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            await fetchWeather(for: location)
        } 
        // Wenn keine direkten Koordinaten verfügbar sind, versuche die Station anhand der UIC-Referenz zu finden
        else if let uicRef = station.uic_ref {
            print("Searching for station with UIC ref: \(uicRef)")
            // Suche in allen Lakes nach einer Station mit der gleichen UIC-Referenz
            for lake in viewModel.lakes {
                if let matchingStation = lake.stations.first(where: { $0.uic_ref == uicRef }) {
                    if let coordinates = matchingStation.coordinates {
                        print("Found matching station with coordinates: \(coordinates.latitude), \(coordinates.longitude)")
                        let location = CLLocationCoordinate2D(
                            latitude: coordinates.latitude,
                            longitude: coordinates.longitude
                        )
                        await fetchWeather(for: location)
                        return
                    }
                }
            }
            print("No coordinates found for station with UIC ref: \(uicRef)")
            weatherError = "No coordinates found for station"
        } else {
            print("Searching for station by name: \(station.name)")
            // Versuche, die Station anhand des Namens zu finden
            for lake in viewModel.lakes {
                if let matchingStation = lake.stations.first(where: { $0.name == station.name }) {
                    if let coordinates = matchingStation.coordinates {
                        print("Found matching station with coordinates: \(coordinates.latitude), \(coordinates.longitude)")
                        let location = CLLocationCoordinate2D(
                            latitude: coordinates.latitude,
                            longitude: coordinates.longitude
                        )
                        await fetchWeather(for: location)
                        return
                    }
                }
            }
            print("No coordinates available for station: \(station.name)")
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
            print("Weather error: \(error)")
        }
        
        isLoadingWeather = false
    }
} 