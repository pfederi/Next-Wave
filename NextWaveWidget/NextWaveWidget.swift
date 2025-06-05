//
//  NextWaveWidget.swift
//  NextWaveWidget
//
//  Created by Patrick Federi on 04.06.2025.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), departure: DepartureInfo(
            stationName: "Brienz",
            nextDeparture: Date().addingTimeInterval(15 * 60),
            routeName: "BLS",
            direction: "Interlaken"
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = placeholder(in: context)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        var entries: [SimpleEntry] = []

        // Debug: Show what we have in UserDefaults
        let favoriteStations = SharedDataManager.shared.loadFavoriteStations()
        print("Widget: Found \(favoriteStations.count) favorite stations: \(favoriteStations.map { $0.name })")
        
        // Load the next departure from the first favorite station
        if let nextDeparture = SharedDataManager.shared.getNextDepartureForFirstFavorite() {
            print("Widget: Found next departure for station \(nextDeparture.stationName) at \(nextDeparture.nextDeparture)")
            
            let now = Date()
            let minutesUntilDeparture = Int(nextDeparture.nextDeparture.timeIntervalSince(now) / 60)
            
            // Simple approach: Create entries every minute for the next hour
            // This forces the widget to update every minute
            for i in 0..<61 { // 61 entries = next 60 minutes
                let entryDate = now.addingTimeInterval(TimeInterval(i * 60))
                let entry = SimpleEntry(date: entryDate, departure: nextDeparture)
                entries.append(entry)
            }
            
            print("Widget: Created 61 timeline entries for guaranteed minute updates")
            print("Widget: Departure in \(minutesUntilDeparture) minutes")
            
            // Use .atEnd to force more frequent reloads
            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
            
        } else {
            print("Widget: No departure found for first favorite station")
            
            let now = Date()
            // Even without departures, create entries to keep widget responsive
            for i in 0..<30 {
                let entryDate = now.addingTimeInterval(TimeInterval(i * 60))
                let entry = SimpleEntry(date: entryDate, departure: nil)
                entries.append(entry)
            }
            
            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let departure: DepartureInfo?
}

struct NextWaveWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    private var minutesUntilDeparture: Int {
        guard let departure = entry.departure else { return 0 }
        // Always calculate from current time, not entry.date
        let timeInterval = departure.nextDeparture.timeIntervalSince(Date())
        return max(0, Int(timeInterval / 60))
    }
    
    private var departureTimeText: String {
        guard let departure = entry.departure else { return "--:--" }
        
        let now = Date()
        let calendar = Calendar.current
        
        // Check if departure is in the next few minutes (show "now" for immediate departures)
        let minutesUntil = Int(departure.nextDeparture.timeIntervalSince(now) / 60)
        if minutesUntil <= 0 {
            return "now"
        }
        
        // Check if departure is tomorrow
        if !calendar.isDate(departure.nextDeparture, inSameDayAs: now) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "tmrw \(formatter.string(from: departure.nextDeparture))"
        }
        
        // Same day - show "at HH:MM"
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "at \(formatter.string(from: departure.nextDeparture))"
    }

    var body: some View {
        if let departure = entry.departure {
            switch widgetFamily {
            case .accessoryCircular:
                VStack(spacing: 0) {
                    if departureTimeText == "now" {
                        Text("now")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundColor(.green)
                            .multilineTextAlignment(.center)
                    } else if departureTimeText.starts(with: "tmrw") {
                        let timeOnly = String(departureTimeText.dropFirst(5)) // Remove "tmrw "
                        Text("tmrw")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundColor(.purple)
                            .multilineTextAlignment(.center)
                        Text(timeOnly)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundColor(.purple)
                            .multilineTextAlignment(.center)
                    } else {
                        let timeOnly = String(departureTimeText.dropFirst(3)) // Remove "at "
                        Image(systemName: "ferry.fill")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundColor(.cyan)
                        Text(timeOnly)
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundColor(.cyan)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .multilineTextAlignment(.center)
                .background(
                    Circle()
                        .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
                        .opacity(0.2)
                )
            case .accessoryCorner:
                Text(departureTimeText)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundColor(departureTimeText == "now" ? .green : 
                                   departureTimeText.starts(with: "tmrw") ? .purple : .cyan)
                    .multilineTextAlignment(.trailing)
            case .accessoryInline:
                Text("\(departure.stationName) → \(departure.direction) \(departureTimeText)")
                    .font(.system(.caption, design: .rounded))
                    .multilineTextAlignment(.trailing)
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
                        .multilineTextAlignment(.leading)
                    Text(departureTimeText)
                        .font(.subheadline)
                        .foregroundColor(departureTimeText == "now" ? .green : 
                                       departureTimeText.starts(with: "tmrw") ? .purple : .cyan)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            @unknown default:
                Text(departureTimeText)
                    .foregroundColor(departureTimeText == "now" ? .green : 
                                   departureTimeText.starts(with: "tmrw") ? .purple : .cyan)
                    .multilineTextAlignment(.trailing)
            }
        } else {
            switch widgetFamily {
            case .accessoryCircular:
                VStack(spacing: 0) {
                    Text("--")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Text("min")
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .multilineTextAlignment(.center)
            case .accessoryInline:
                // Show first favorite station name if available
                let favoriteStations = SharedDataManager.shared.loadFavoriteStations()
                if let firstStation = favoriteStations.first {
                    Text("\(firstStation.name) - no departures")
                        .font(.caption)
                        .multilineTextAlignment(.trailing)
                } else {
                    Text("Add favorites in iOS app")
                        .font(.caption)
                        .multilineTextAlignment(.trailing)
                }
            case .accessoryRectangular:
                let favoriteStations = SharedDataManager.shared.loadFavoriteStations()
                VStack(alignment: .leading) {
                    if let firstStation = favoriteStations.first {
                        HStack(spacing: 4) {
                            Image(systemName: "ferry.fill")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            Text(firstStation.name)
                                .font(.headline)
                        }
                        Text("No departures found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "ferry.fill")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            Text("NextWave")
                                .font(.headline)
                        }
                        Text("No favorites set")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            default:
                Text("--")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

@main
struct NextWaveWidget: Widget {
    let kind: String = "NextWaveWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
                NextWaveWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("NextWave")
        .description("Shows your next boat departure")
        .supportedFamilies([
            .accessoryInline,
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular
        ])
    }
}

#Preview(as: .accessoryRectangular) {
    NextWaveWidget()
} timeline: {
    SimpleEntry(date: .now, departure: DepartureInfo(
        stationName: "Brienz",
        nextDeparture: Date().addingTimeInterval(15 * 60),
        routeName: "BLS",
        direction: "Interlaken"
    ))
}
