import Testing
import Foundation
@testable import Next_Wave

struct WaterLevelStatsTests {
    private func pt(_ daysAgo: Int, _ level: Double) -> WaterLevelHistoryAPI.WaterLevelPoint {
        let date = Calendar(identifier: .gregorian).date(byAdding: .day, value: -daysAgo, to: Date())!
        return WaterLevelHistoryAPI.WaterLevelPoint(date: date, levelM: level)
    }

    @Test func emptyHistoryYieldsNils() {
        let stats = WaterLevelStats(history: [])
        #expect(stats.current == nil)
        #expect(stats.min == nil)
        #expect(stats.max == nil)
        #expect(stats.deltaSinceYesterday == nil)
    }

    @Test func singlePointHasNoDelta() {
        let stats = WaterLevelStats(history: [pt(0, 405.5)])
        #expect(stats.current == 405.5)
        #expect(stats.min == 405.5)
        #expect(stats.max == 405.5)
        #expect(stats.deltaSinceYesterday == nil)
    }

    @Test func computesCurrentMinMaxAndDelta() {
        let history = [pt(2, 405.0), pt(1, 405.5), pt(0, 405.2)]
        let stats = WaterLevelStats(history: history)
        #expect(stats.current == 405.2)
        #expect(stats.min == 405.0)
        #expect(stats.max == 405.5)
        #expect(abs(stats.deltaSinceYesterday! - (-0.3)) < 0.0001)
    }

    @Test func unsortedInputIsSortedInternally() {
        let history = [pt(0, 405.2), pt(2, 405.0), pt(1, 405.5)]
        let stats = WaterLevelStats(history: history)
        #expect(stats.current == 405.2)
    }
}
