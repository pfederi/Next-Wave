import SwiftUI
import Charts

struct WaterLevelSectionView: View {
    let history: [WaterLevelHistoryAPI.WaterLevelPoint]

    private var stats: WaterLevelStats { WaterLevelStats(history: history) }

    /// Lake levels sit around ~400 m with a range of only a few centimetres over
    /// 40 days. Swift Charts' automatic y-domain would include the zero baseline
    /// of the `AreaMark` and flatten the curve into an invisible sliver, so pin
    /// the domain to the actual data range plus a little padding.
    private var yDomain: ClosedRange<Double> {
        guard let lo = stats.min, let hi = stats.max else { return 0...1 }
        let pad = Swift.max((hi - lo) * 0.15, 0.02)
        return (lo - pad)...(hi + pad)
    }

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
            .chartYScale(domain: yDomain)
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

    /// Whole centimetres, rounded — matches the convention used by
    /// `calculateWaterLevelDifference` in `Lake.swift`.
    private var deltaCm: Int? {
        stats.deltaSinceYesterday.map { Int(round($0 * 100)) }
    }

    private func deltaText(_ cm: Int) -> String {
        if cm > 0 {
            return "+\(cm) cm"
        } else if cm < 0 {
            return "\(cm) cm"
        } else {
            return "±0 cm"
        }
    }

    private var deltaTile: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Since yesterday")
                .font(.caption)
                .foregroundColor(.secondary)
            if let cm = deltaCm {
                HStack(spacing: 2) {
                    Image(systemName: cm >= 0 ? "water.waves.and.arrow.trianglehead.up" : "water.waves.and.arrow.trianglehead.down")
                        .font(.caption)
                    Text(deltaText(cm))
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
