//
//  NextWaveWidget.swift
//  NextWaveWidget
//
//  Created by Patrick Federi on 07.04.2025.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> DepartureEntry {
        DepartureEntry(date: Date(), departures: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (DepartureEntry) -> ()) {
        let entry = DepartureEntry(date: Date(), departures: [])
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DepartureEntry>) -> ()) {
        let departures = SharedDataManager.shared.loadNextDepartures()
        let entry = DepartureEntry(date: Date(), departures: departures)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct DepartureEntry: TimelineEntry {
    let date: Date
    let departures: [DepartureInfo]
}

struct NextWaveWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularWidgetView(entry: entry)
        case .accessoryRectangular:
            RectangularWidgetView(entry: entry)
        default:
            Text("Unsupported")
        }
    }
}

struct CircularWidgetView: View {
    let entry: DepartureEntry
    
    var body: some View {
        if let firstDeparture = entry.departures.first {
            VStack {
                Text(firstDeparture.stationName)
                    .font(.caption2)
                    .lineLimit(1)
                Text(firstDeparture.nextDeparture, style: .time)
                    .font(.caption)
            }
        } else {
            Text("Keine Abfahrten")
                .font(.caption2)
        }
    }
}

struct RectangularWidgetView: View {
    let entry: DepartureEntry
    
    var body: some View {
        VStack(alignment: .leading) {
            ForEach(entry.departures.prefix(2), id: \.stationName) { departure in
                HStack {
                    Text(departure.stationName)
                        .font(.caption2)
                        .lineLimit(1)
                    Spacer()
                    Text(departure.nextDeparture, style: .time)
                        .font(.caption)
                }
            }
        }
    }
}

struct NextWaveWidget: Widget {
    let kind: String = "NextWaveWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            NextWaveWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Next Wave Abfahrten")
        .description("Zeigt die nächsten Abfahrten Ihrer Lieblingsstationen an.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

#Preview(as: .accessoryCircular) {
    NextWaveWidget()
} timeline: {
    DepartureEntry(date: Date(), departures: [
        DepartureInfo(stationName: "Zürich HB", nextDeparture: Date(), routeName: "S3", direction: "Wetzikon")
    ])
}
