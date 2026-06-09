import SwiftUI
import WidgetKit
import ActivityKit

@available(iOS 16.2, *)
struct WaveLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WaveActivityAttributes.self) { context in
            // Lock Screen / banner
            WaveLockScreenView(attributes: context.attributes)
                .widgetURL(context.attributes.deepLinkURL)
                .padding()
                .activityBackgroundTint(Color.black.opacity(0.4))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.stationName).font(.caption).lineLimit(1)
                    } icon: {
                        waveGlyph(context.attributes.waveIconName)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(to: context.attributes.waveTime)
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .frame(maxWidth: 90)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 4) {
                        Text("→ \(context.attributes.destinationName)").lineLimit(1)
                        if let ship = context.attributes.shipName {
                            Spacer()
                            Text(ship).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    .font(.caption)
                }
            } compactLeading: {
                waveGlyph(context.attributes.waveIconName)
            } compactTrailing: {
                countdown(to: context.attributes.waveTime)
                    .frame(maxWidth: 56)
            } minimal: {
                countdown(to: context.attributes.waveTime)
                    .frame(maxWidth: 44)
            }
            .widgetURL(context.attributes.deepLinkURL)
        }
    }
}

@available(iOS 16.2, *)
private func countdown(to date: Date) -> some View {
    // Self-updating, clamped so it never shows negative time.
    Text(timerInterval: Date()...max(date, Date().addingTimeInterval(1)),
         countsDown: true)
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
}

@ViewBuilder
private func waveGlyph(_ iconName: String?) -> some View {
    if let iconName {
        Image(iconName).resizable().scaledToFit().frame(width: 18, height: 14)
    } else {
        Image(systemName: "water.waves").foregroundStyle(.blue)
    }
}

@available(iOS 16.2, *)
struct WaveLockScreenView: View {
    let attributes: WaveActivityAttributes

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "water.waves").foregroundStyle(.blue)
                    Text(attributes.stationName).font(.headline).lineLimit(1)
                }
                Text("→ \(attributes.destinationName)")
                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                if let ship = attributes.shipName {
                    HStack(spacing: 4) {
                        if let icon = attributes.waveIconName {
                            Image(icon).resizable().scaledToFit().frame(width: 16, height: 12)
                        }
                        Text(ship).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                countdown(to: attributes.waveTime)
                    .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                Text("to wave").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
