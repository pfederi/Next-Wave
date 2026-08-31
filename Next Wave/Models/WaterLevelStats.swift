import Foundation

struct WaterLevelStats: Equatable {
    let current: Double?
    /// Internal only — not shown as a tile, still needed to scale the chart's y-axis.
    let min: Double?
    /// Internal only — not shown as a tile, still needed to scale the chart's y-axis.
    let max: Double?
    let deltaSinceYesterday: Double?

    init(history: [WaterLevelHistoryAPI.WaterLevelPoint]) {
        let sorted = history.sorted { $0.date < $1.date }
        current = sorted.last?.levelM
        let levels = history.map(\.levelM)
        min = levels.min()
        max = levels.max()

        // The history can have gaps (not every lake gets a reading every day),
        // so only report a delta when the two most recent points really are one
        // calendar day apart — otherwise a multi-day change would be labelled
        // "since yesterday".
        if sorted.count >= 2 {
            let last = sorted[sorted.count - 1]
            let prev = sorted[sorted.count - 2]
            let cal = Calendar(identifier: .gregorian)
            let dayGap = cal.dateComponents([.day], from: cal.startOfDay(for: prev.date), to: cal.startOfDay(for: last.date)).day
            deltaSinceYesterday = (dayGap == 1) ? last.levelM - prev.levelM : nil
        } else {
            deltaSinceYesterday = nil
        }
    }
}
