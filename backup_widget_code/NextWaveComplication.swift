//
//  NextWaveComplication.swift
//  NextWaveComplication
//
//  Created by Patrick Federi on 03.06.2025.
//

import WidgetKit
import SwiftUI

struct SimpleProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), text: "Test 5min")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), text: "Test 5min")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let entry = SimpleEntry(date: Date(), text: "Test 5min")
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60)))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let text: String
}

struct SimpleWidgetView: View {
    var entry: SimpleProvider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        switch widgetFamily {
        case .accessoryCircular:
            Text("5min")
                .font(.system(.title3, design: .rounded))
        case .accessoryCorner:
            Text("5min")
                .font(.system(.body, design: .rounded))
        case .accessoryInline:
            Text("NextWave: Test → Destination in 5min")
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text("NextWave")
                    .font(.headline)
                Text("→ Test")
                    .font(.subheadline)
                Text("in 5 min")
                    .font(.caption)
            }
        @unknown default:
            Text("5min")
        }
    }
}

@main
struct NextWaveWidget: Widget {
    let kind: String = "NextWaveWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SimpleProvider()) { entry in
            SimpleWidgetView(entry: entry)
        }
        .configurationDisplayName("NextWave")
        .description("Shows next departure times")
        .supportedFamilies([
            .accessoryInline,
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular
        ])
    }
}
