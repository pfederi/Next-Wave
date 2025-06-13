import WidgetKit
import SwiftUI

// Import the shared watch widget components
// This file should be included in the Watch Widget Extension target

// This is the main bundle for the Watch Widget Extension
// It uses shared components from the main app

// MARK: - Local Definitions for Watch Widget Extension

struct DepartureInfo: Codable {
    let stationName: String
    let nextDeparture: Date
    let routeName: String
    let direction: String
}

struct FavoriteStation: Codable {
    let id: String
    let name: String
    let latitude: Double?
    let longitude: Double?
    let uic_ref: String?
}

class SharedDataManager {
    static let shared = SharedDataManager()
    
    private let userDefaults = UserDefaults(suiteName: "group.com.federi.Next-Wave")
    private let nextDeparturesKey = "nextDepartures"
    private let favoriteStationsKey = "favoriteStations"
    private let nearestStationKey = "nearestStation"
    private let widgetSettingsKey = "widgetSettings"
    
    private init() {}
    
    func loadNextDepartures() -> [DepartureInfo] {
        guard let data = userDefaults?.data(forKey: nextDeparturesKey),
              let departures = try? JSONDecoder().decode([DepartureInfo].self, from: data) else {
            return []
        }
        return departures
    }
    
    func loadFavoriteStations() -> [FavoriteStation] {
        guard let data = userDefaults?.data(forKey: favoriteStationsKey),
              let stations = try? JSONDecoder().decode([FavoriteStation].self, from: data) else {
            return []
        }
        return stations
    }
    
    func loadNearestStation() -> FavoriteStation? {
        guard let data = userDefaults?.data(forKey: nearestStationKey),
              let station = try? JSONDecoder().decode(FavoriteStation.self, from: data) else {
            return nil
        }
        return station
    }
    
    struct WidgetSettings: Codable {
        let useNearestStation: Bool
    }
    
    func loadWidgetSettings() -> WidgetSettings {
        guard let data = userDefaults?.data(forKey: widgetSettingsKey),
              let settings = try? JSONDecoder().decode(WidgetSettings.self, from: data) else {
            return WidgetSettings(useNearestStation: false)
        }
        return settings
    }
    
    func getNextDepartureForWidget() -> DepartureInfo? {
        let settings = loadWidgetSettings()
        let allDepartures = loadNextDepartures()
        let now = Date()
        
        if settings.useNearestStation {
            if let nearestStation = loadNearestStation() {
                let nextDeparture = allDepartures
                    .filter { $0.stationName == nearestStation.name }
                    .filter { $0.nextDeparture > now }
                    .sorted { $0.nextDeparture < $1.nextDeparture }
                    .first
                    
                if let departure = nextDeparture {
                    return departure
                }
            }
        }
        
        // Fallback to first favorite
        let favoriteStations = loadFavoriteStations()
        guard let firstStation = favoriteStations.first else { return nil }
        
        return allDepartures
            .filter { $0.stationName == firstStation.name }
            .filter { $0.nextDeparture > now }
            .sorted { $0.nextDeparture < $1.nextDeparture }
            .first
    }
}

// MARK: - Bundle Definition

@main  
struct NextWaveWatchWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        NextWaveWatchComplication()  // Keep only the complication widget since it supports all needed features
    }
}

// MARK: - Widget Entry

struct SimpleWatchEntry: TimelineEntry {
    let date: Date
    let departure: DepartureInfo?
}

// MARK: - Widget Provider

struct SimpleWatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleWatchEntry {
        SimpleWatchEntry(date: Date(), departure: DepartureInfo(
            stationName: "Brienz",
            nextDeparture: Date().addingTimeInterval(15 * 60),
            routeName: "BLS",
            direction: "Interlaken"
        ))
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleWatchEntry) -> ()) {
        completion(placeholder(in: context))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleWatchEntry>) -> ()) {
        let now = Date()
        let nextDeparture = SharedDataManager.shared.getNextDepartureForWidget()
        
        print("🔍 Watch Widget: getTimeline called, found departure: \(nextDeparture?.stationName ?? "none")")
        
        let entry = SimpleWatchEntry(date: now, departure: nextDeparture)
        let timeline = Timeline(entries: [entry], policy: .after(now.addingTimeInterval(300)))
        completion(timeline)
    }
}

// MARK: - Watch Complication Widget

struct NextWaveWatchComplication: Widget {
    let kind: String = "NextWaveWatchComplication"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SimpleWatchProvider()) { entry in
            SimpleWatchWidgetView(entry: entry)
        }
        .configurationDisplayName("NextWave")
        .description("Shows your next boat departure")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Simple Watch Widget

struct SimpleWatchWidget: Widget {
    let kind: String = "NextWaveWatchWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SimpleWatchProvider()) { entry in
            SimpleWatchWidgetView(entry: entry)
        }
        .configurationDisplayName("NextWave")
        .description("Shows your next boat departure")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Widget View

struct SimpleWatchWidgetView: View {
    var entry: SimpleWatchProvider.Entry
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        if let departure = entry.departure {
            switch widgetFamily {
            case .accessoryCircular:
                VStack(spacing: 0) {
                    Image(systemName: "ferry.fill")
                        .font(.system(.caption2, weight: .medium))
                        .foregroundColor(.cyan)
                    Text(formatTime(departure.nextDeparture))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundColor(.cyan)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
            case .accessoryInline:
                Text("\(departure.stationName) → \(departure.direction) \(formatTime(departure.nextDeparture))")
                    .font(.system(.caption, design: .rounded))
                    
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "ferry.fill")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        Text(departure.stationName)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    Text("→ \(departure.direction)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatTime(departure.nextDeparture))
                        .font(.subheadline)
                        .foregroundColor(.cyan)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
            default:
                Text(formatTime(departure.nextDeparture))
                    .foregroundColor(.cyan)
            }
        } else {
            switch widgetFamily {
            case .accessoryCircular:
                Text("--")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundColor(.secondary)
                    
            case .accessoryInline:
                Text("No departures")
                    .font(.caption)
                    
            case .accessoryRectangular:
                VStack(alignment: .leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "ferry.fill")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        Text("NextWave")
                            .font(.headline)
                    }
                    Text("No departures found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
            default:
                Text("--")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        
        let minutesUntil = Int(date.timeIntervalSince(now) / 60)
        if minutesUntil <= 0 {
            return "now"
        }
        
        if !calendar.isDate(date, inSameDayAs: now) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "tmrw \(formatter.string(from: date))"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "at \(formatter.string(from: date))"
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 16.0, *)
struct SimpleWatchWidget_Previews: PreviewProvider {
    static var previews: some View {
        SimpleWatchWidgetView(entry: SimpleWatchEntry(
            date: Date(),
            departure: DepartureInfo(
                stationName: "Spiez",
                nextDeparture: Date().addingTimeInterval(25 * 60),
                routeName: "BLS",
                direction: "Thun"
            )
        ))
        .previewContext(WidgetPreviewContext(family: .accessoryCircular))
    }
}
#endif 