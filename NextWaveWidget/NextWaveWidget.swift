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
            let entry = SimpleEntry(date: Date(), departure: nextDeparture)
            entries.append(entry)
            
            // Calculate VERY aggressive update time for better responsiveness
            let minutesUntilDeparture = Int(nextDeparture.nextDeparture.timeIntervalSince(Date()) / 60)
            let updateInterval: TimeInterval
            
            if minutesUntilDeparture <= 2 {
                updateInterval = 15 // Update every 15 seconds if departure is very soon
            } else if minutesUntilDeparture <= 5 {
                updateInterval = 30 // Update every 30 seconds if departure is soon
            } else if minutesUntilDeparture <= 15 {
                updateInterval = 60 // Update every minute if departure is within 15 min
            } else {
                updateInterval = 120 // Update every 2 minutes otherwise
            }
            
            print("Widget: Setting update interval to \(updateInterval) seconds (departure in \(minutesUntilDeparture) min)")
            
            // Use .atEnd policy for more aggressive updates
            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
            
            // Schedule next update
            DispatchQueue.main.asyncAfter(deadline: .now() + updateInterval) {
                WidgetCenter.shared.reloadTimelines(ofKind: "NextWaveWidget")
            }
        } else {
            print("Widget: No departure found for first favorite station")
            // Very frequent fallback updates when no favorites are set
            let fallbackEntry = SimpleEntry(date: Date(), departure: nil)
            entries.append(fallbackEntry)
            
            // Check every 15 seconds if no favorites are set
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
            
            // Schedule next update
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                WidgetCenter.shared.reloadTimelines(ofKind: "NextWaveWidget")
            }
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
        let timeInterval = departure.nextDeparture.timeIntervalSince(Date())
        return max(0, Int(timeInterval / 60))
    }
    
    private var formattedTimeUntilDeparture: String {
        let minutes = minutesUntilDeparture
        if minutes > 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(remainingMinutes)min"
            }
        } else {
            return "\(minutes)min"
        }
    }

    var body: some View {
        if let departure = entry.departure {
            switch widgetFamily {
            case .accessoryCircular:
                VStack(spacing: 0) {
                    if minutesUntilDeparture > 60 {
                        let hours = minutesUntilDeparture / 60
                        let remainingMinutes = minutesUntilDeparture % 60
                        Text("\(hours)h")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundColor(.cyan)
                            .multilineTextAlignment(.center)
                        if remainingMinutes > 0 {
                            Text("\(remainingMinutes)min")
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                                .foregroundColor(.cyan)
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        Text("\(minutesUntilDeparture)")
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundColor(.cyan)
                            .multilineTextAlignment(.center)
                        Text("min")
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                            .foregroundColor(.cyan)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .multilineTextAlignment(.center)
            case .accessoryCorner:
                Text(formattedTimeUntilDeparture)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundColor(.cyan)
                    .multilineTextAlignment(.trailing)
            case .accessoryInline:
                Text("\(departure.stationName) → \(departure.direction) in \(formattedTimeUntilDeparture)")
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
                    Text("in \(formattedTimeUntilDeparture)")
                        .font(.subheadline)
                        .foregroundColor(.cyan)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            @unknown default:
                Text(formattedTimeUntilDeparture)
                    .foregroundColor(.cyan)
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
