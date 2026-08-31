import SwiftUI
import Charts

struct WaterLevelSectionView: View {
    let history: [WaterLevelHistoryAPI.WaterLevelPoint]

    private var stats: WaterLevelStats { WaterLevelStats(history: history) }

    var body: some View {
        Group {
            if !history.isEmpty {
                content
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Water Level")
                .font(.title2)

            Chart(history, id: \.date) { point in
                LineMark(x: .value("Date", point.date), y: .value("Level", point.levelM))
                    .foregroundStyle(Color.accentColor)
                AreaMark(x: .value("Date", point.date), y: .value("Level", point.levelM))
                    .foregroundStyle(Color.accentColor.opacity(0.15))
            }
            .frame(height: 120)

            if history.count < 7 {
                Text("Not enough data yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                statTile(title: "Current", value: stats.current)
                statTile(title: "Min", value: stats.min)
                statTile(title: "Max", value: stats.max)
                deltaTile
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
        )
    }

    private func statTile(title: LocalizedStringKey, value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value.map { String(format: "%.2f", $0) } ?? "–")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var deltaTile: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Since yesterday")
                .font(.caption)
                .foregroundColor(.secondary)
            if let delta = stats.deltaSinceYesterday {
                HStack(spacing: 2) {
                    Image(systemName: delta >= 0 ? "water.waves.and.arrow.trianglehead.up" : "water.waves.and.arrow.trianglehead.down")
                        .font(.caption)
                    Text(String(format: "%+.0f cm", delta * 100))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            } else {
                Text("–")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    WaterLevelSectionView(history: (0..<40).map { offset in
        WaterLevelHistoryAPI.WaterLevelPoint(
            date: Calendar.current.date(byAdding: .day, value: -offset, to: Date())!,
            levelM: 405.0 + Double.random(in: -0.3...0.3)
        )
    })
    .padding()
}
