import WidgetKit
import SwiftUI
import NextWaveShared
import CoreLocation

struct Provider: TimelineProvider {
    init() {
        print("📱 Initializing Widget Provider")
        AppGroup.initialize()
        print("📱 Loading initial favorites...")
        let initialFavorites = FavoriteStationsManager.shared.favorites
        print("📱 Found \(initialFavorites.count) initial favorites")
    }
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            favoriteStations: [],
            nextDepartures: [:]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        print("📱 Getting widget snapshot")
        // For previews, use placeholder data
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        
        // Otherwise, get real data
        Task {
            let entry = await getTimelineEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        print("📱 Getting widget timeline")
        Task {
            let entry = await getTimelineEntry()
            
            // Update more frequently if we have no data
            let updateInterval = entry.nextDepartures.isEmpty ? 5 : 15
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: updateInterval, to: .now) ?? .now
            print("📱 Next update scheduled in \(updateInterval) minutes")
            
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
    
    private func getTimelineEntry() async -> SimpleEntry {
        print("\n📱 Building widget timeline entry...")
        
        // Load favorites
        let favorites = FavoriteStationsManager.shared.favorites
        print("📱 Found \(favorites.count) favorites")
        
        // Get departures
        var departures: [String: Date] = [:]
        for favorite in favorites {
            print("📱 Fetching departure for \(favorite.name)...")
            if let departure = await WidgetViewModel.shared.getNextDeparture(for: favorite.id) {
                departures[favorite.id] = departure
                print("✅ Got departure for \(favorite.name): \(departure)")
            } else {
                print("❌ No departure found for \(favorite.name)")
            }
        }
        
        print("📱 Timeline entry complete with \(favorites.count) favorites and \(departures.count) departures\n")
        
        return SimpleEntry(
            date: .now,
            favoriteStations: favorites,
            nextDepartures: departures
        )
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let favoriteStations: [FavoriteStation]
    let nextDepartures: [String: Date]
}

struct NextWaveWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            Text("Unsupported widget size")
        }
    }
}

struct SmallWidgetView: View {
    let entry: Provider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let favorite = entry.favoriteStations.first {
                Text("Favorite Spot")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(favorite.name)
                    .font(.headline)
                    .lineLimit(1)
                
                if let departure = entry.nextDepartures[favorite.id] {
                    HStack {
                        Image(systemName: "water.waves")
                        Text(timeString(from: departure))
                    }
                    .font(.caption)
                }
            } else {
                Text("No favorite stations")
                    .font(.caption)
            }
        }
        .padding()
        .containerBackground(.background, for: .widget)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct MediumWidgetView: View {
    let entry: Provider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !entry.favoriteStations.isEmpty {
                Text("Favorite Spots")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(entry.favoriteStations.prefix(3)) { favorite in
                    HStack {
                        Text(favorite.name)
                            .font(.subheadline)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if let departure = entry.nextDepartures[favorite.id] {
                            HStack {
                                Image(systemName: "water.waves")
                                Text(timeString(from: departure))
                            }
                            .font(.caption)
                        }
                    }
                }
            } else {
                Text("No favorite stations")
                    .font(.caption)
            }
        }
        .padding()
        .containerBackground(.background, for: .widget)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

@main
struct NextWaveWidget: Widget {
    let kind: String = "NextWaveWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            NextWaveWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Next Wave")
        .description("Shows your favorite spots and nearest station.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
} 