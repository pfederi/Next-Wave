import Foundation

struct WaterLevelStats: Equatable {
    let current: Double?
    let min: Double?
    let max: Double?
    let deltaSinceYesterday: Double?

    init(history: [WaterLevelHistoryAPI.WaterLevelPoint]) {
        let sorted = history.sorted { $0.date < $1.date }
        current = sorted.last?.levelM
        min = history.map(\.levelM).min()
        max = history.map(\.levelM).max()
        if sorted.count >= 2 {
            deltaSinceYesterday = sorted[sorted.count - 1].levelM - sorted[sorted.count - 2].levelM
        } else {
            deltaSinceYesterday = nil
        }
    }
}
