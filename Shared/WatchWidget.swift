import WidgetKit
import SwiftUI

#if os(watchOS)

@main
struct NextWaveWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextWaveWatchWidget()
    }
}

#endif

// MARK: - Watch Widget Entry and Provider

struct SimpleWatchEntry: TimelineEntry {
    let date: Date
    let departure: DepartureInfo?
}

struct WatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleWatchEntry {
        SimpleWatchEntry(date: Date(), departure: DepartureInfo(
            stationName: "Brienz",
            nextDeparture: Date().addingTimeInterval(15 * 60),
            routeName: "BLS",
            direction: "Interlaken"
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleWatchEntry) -> ()) {
        let entry = placeholder(in: context)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleWatchEntry>) -> ()) {
        let now = Date()
        var entries: [SimpleWatchEntry] = []
        
        // Always ensure we have at least one entry to prevent timeline errors
        defer {
            if entries.isEmpty {
                // Fallback: create a single entry with no departure data
                let entry = SimpleWatchEntry(date: now, departure: nil)
                entries.append(entry)
                print("🚨 Watch Widget: Creating fallback timeline with single empty entry")
            }
            
            print("🔍 Watch Widget: Creating timeline with \(entries.count) entries")
            
            // Use .after policy to ensure regular updates, but allow manual reloads
            let nextUpdate = Date().addingTimeInterval(300) // 5 minutes
            let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
            completion(timeline)
        }
        
        print("🔍 Watch Widget getTimeline called at \(now)")
        
        // Use the improved logic from SharedDataManager
        let nextDeparture = SharedDataManager.shared.getNextDepartureForWidget()
        
        if let nextDeparture = nextDeparture {
            print("🔍 Watch Widget: Creating timeline with departure for: \(nextDeparture.stationName)")
            
            // Create entries every 5 minutes for the next hour
            for i in 0..<13 { // 13 entries = next 60 minutes (every 5 minutes)
                let entryDate = now.addingTimeInterval(TimeInterval(i * 5 * 60))
                let entry = SimpleWatchEntry(date: entryDate, departure: nextDeparture)
                entries.append(entry)
            }
        } else {
            print("🔍 Watch Widget: No departure found - creating empty timeline")
            // Even without departures, create entries to keep widget responsive
            for i in 0..<13 {
                let entryDate = now.addingTimeInterval(TimeInterval(i * 5 * 60))
                let entry = SimpleWatchEntry(date: entryDate, departure: nil)
                entries.append(entry)
            }
        }
    }
}

// MARK: - Watch Widget Views

struct WatchWidgetEntryView: View {
    var entry: WatchProvider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    private var departureTimeText: String {
        guard let departure = entry.departure else { return "--:--" }
        
        let now = Date()
        let calendar = Calendar.current
        
        let minutesUntil = Int(departure.nextDeparture.timeIntervalSince(now) / 60)
        if minutesUntil <= 0 {
            return "now"
        }
        
        if !calendar.isDate(departure.nextDeparture, inSameDayAs: now) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "tmrw \(formatter.string(from: departure.nextDeparture))"
        }
        
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
                    } else if departureTimeText.starts(with: "tmrw") {
                        let timeOnly = String(departureTimeText.dropFirst(5))
                        Text("tmrw")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundColor(.purple)
                        Text(timeOnly)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundColor(.purple)
                    } else {
                        let timeOnly = String(departureTimeText.dropFirst(3))
                        Image(systemName: "ferry.fill")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundColor(.cyan)
                        Text(timeOnly)
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundColor(.cyan)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .accessoryInline:
                Text("\(departure.stationName) → \(departure.direction) \(departureTimeText)")
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
                    Text(departureTimeText)
                        .font(.subheadline)
                        .foregroundColor(departureTimeText == "now" ? .green : 
                                       departureTimeText.starts(with: "tmrw") ? .purple : .cyan)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            @unknown default:
                Text(departureTimeText)
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
            @unknown default:
                Text("--")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Watch Widget Definition

struct NextWaveWatchWidget: Widget {
    let kind: String = "NextWaveWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchProvider()) { entry in
            WatchWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("NextWave Watch")
        .description("Shows your next boat departure on Apple Watch")
        .supportedFamilies([
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

// MARK: - Watch Widget Previews

#if DEBUG && os(watchOS)
@available(watchOS 9.0, *)
struct NextWaveWatchWidget_Previews: PreviewProvider {
    static var previews: some View {
        WatchWidgetEntryView(entry: SimpleWatchEntry(
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