import SwiftUI

struct TemperatureForecastView: View {
    let lake: Lake
    @Environment(\.dismiss) var dismiss
    
    private var temperatureFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Current Temperature Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Aktuelle Temperatur")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if let temp = lake.waterTemperature {
                            HStack {
                                Image(systemName: "thermometer.medium")
                                    .font(.system(size: 60))
                                    .foregroundColor(.blue)
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(String(format: "%.1f°C", temp))
                                        .font(.system(size: 56, weight: .bold))
                                    
                                    Text("Wassertemperatur")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.blue.opacity(0.1))
                            )
                        } else {
                            Text("Keine Daten verfügbar")
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Forecast Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Vorhersage (nächste 2 Tage)")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                        
                        if let forecasts = lake.temperatureForecast, !forecasts.isEmpty {
                            // Group forecasts by day
                            let groupedForecasts = Dictionary(grouping: forecasts) { forecast in
                                Calendar.current.startOfDay(for: forecast.time)
                            }
                            
                            let sortedDays = groupedForecasts.keys.sorted()
                            
                            ForEach(sortedDays, id: \.self) { day in
                                if let dayForecasts = groupedForecasts[day] {
                                    DayForecastCard(
                                        date: day,
                                        forecasts: dayForecasts.sorted(by: { $0.time < $1.time })
                                    )
                                }
                            }
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                
                                Text("Keine Vorhersage verfügbar")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("Die Vorhersage wird in Kürze aktualisiert")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Data Source Info
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                            Text("Datenquelle: Alplakes API (Eawag)")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        
                        Text("Wissenschaftlich validierte Daten • Aktualisierung alle 3 Stunden")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                .padding(.vertical)
            }
            .navigationTitle(lake.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Day Forecast Card
struct DayForecastCard: View {
    let date: Date
    let forecasts: [Lake.TemperatureForecast]
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d. MMMM"
        formatter.locale = Locale(identifier: "de_CH")
        return formatter
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    private var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(date)
    }
    
    private var dayLabel: String {
        if isToday {
            return "Heute"
        } else if isTomorrow {
            return "Morgen"
        } else {
            return dateFormatter.string(from: date)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Day Header
            HStack {
                Text(dayLabel)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let minTemp = forecasts.map({ $0.temperature }).min(),
                   let maxTemp = forecasts.map({ $0.temperature }).max() {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(String(format: "%.1f°", minTemp))
                            .font(.caption)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "arrow.up")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text(String(format: "%.1f°", maxTemp))
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            // Hourly Forecasts in horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(forecasts, id: \.time) { forecast in
                        VStack(spacing: 6) {
                            Text(timeFormatter.string(from: forecast.time))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Image(systemName: "drop.fill")
                                .font(.system(size: 20))
                                .foregroundColor(temperatureColor(for: forecast.temperature))
                            
                            Text(String(format: "%.1f°", forecast.temperature))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .frame(width: 70)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(temperatureColor(for: forecast.temperature).opacity(0.1))
                        )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.1))
        )
    }
    
    private func temperatureColor(for temp: Double) -> Color {
        switch temp {
        case ..<10:
            return .blue
        case 10..<18:
            return .cyan
        case 18..<22:
            return .green
        case 22..<25:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Preview
struct TemperatureForecastView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleForecasts = [
            Lake.TemperatureForecast(time: Date(), temperature: 18.5),
            Lake.TemperatureForecast(time: Date().addingTimeInterval(10800), temperature: 19.2),
            Lake.TemperatureForecast(time: Date().addingTimeInterval(21600), temperature: 19.8),
            Lake.TemperatureForecast(time: Date().addingTimeInterval(32400), temperature: 20.1),
            Lake.TemperatureForecast(time: Date().addingTimeInterval(86400), temperature: 19.5),
            Lake.TemperatureForecast(time: Date().addingTimeInterval(97200), temperature: 20.3),
        ]
        
        let sampleLake = Lake(
            name: "Zürichsee",
            operators: ["ZSG"],
            stations: [],
            waterTemperature: 18.5,
            waterLevel: "405.96 m.ü.M.",
            temperatureForecast: sampleForecasts
        )
        
        TemperatureForecastView(lake: sampleLake)
    }
}

