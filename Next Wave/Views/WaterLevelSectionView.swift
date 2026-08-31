import SwiftUI
import Charts

struct WaterLevelSectionView: View {
    let history: [WaterLevelHistoryAPI.WaterLevelPoint]
    let lakeName: String

    private var stats: WaterLevelStats { WaterLevelStats(history: history) }

    /// The long-term reference level, not a median computed from `history` —
    /// the 40-day table is too thin right after launch for a real median to
    /// mean anything, so this reuses the same reference value the existing
    /// "+7cm" badges elsewhere in the app already rely on.
    private var referenceLevel: Double? {
        Lake.referenceLevelMeters(for: lakeName)
    }

    private var deltaToReference: Double? {
        guard let current = stats.current, let referenceLevel else { return nil }
        return current - referenceLevel
    }

    /// Lake levels sit around ~400 m with a range of only a few centimetres over
    /// 40 days. Swift Charts' automatic y-domain would include the zero baseline
    /// and flatten the curve into an invisible sliver, so pin the domain to the
    /// actual data range (plus the median line, so it's never clipped out) with
    /// a little padding.
    private var yDomain: ClosedRange<Double> {
        guard let lo = stats.min, let hi = stats.max else { return 0...1 }
        let expandedLo = referenceLevel.map { Swift.min(lo, $0) } ?? lo
        let expandedHi = referenceLevel.map { Swift.max(hi, $0) } ?? hi
        let pad = Swift.max((expandedHi - expandedLo) * 0.15, 0.02)
        return (expandedLo - pad)...(expandedHi + pad)
    }

    var body: some View {
        Group {
            if !history.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Water Level")
                        .font(.title2)

                    content
                }
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart {
                ForEach(history, id: \.date) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Level", point.levelM))
                        .foregroundStyle(Color.accentColor)
                }
                if let referenceLevel {
                    RuleMark(y: .value("Median", referenceLevel))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
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
                statTile(title: "Median", value: referenceLevel)
                deltaTile(title: "vs. median", delta: deltaToReference)
                deltaTile(title: "Since yesterday", delta: stats.deltaSinceYesterday)
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
    private func deltaText(_ cm: Int) -> String {
        if cm > 0 {
            return "+\(cm) cm"
        } else if cm < 0 {
            return "\(cm) cm"
        } else {
            return "±0 cm"
        }
    }

    private func deltaTile(title: LocalizedStringKey, delta: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            if let delta {
                let cm = Int(round(delta * 100))
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
    WaterLevelSectionView(
        history: (0..<40).map { offset in
            WaterLevelHistoryAPI.WaterLevelPoint(
                date: Calendar.current.date(byAdding: .day, value: -offset, to: Date())!,
                levelM: 405.0 + Double.random(in: -0.3...0.3)
            )
        },
        lakeName: "Zürichsee"
    )
    .padding()
}
