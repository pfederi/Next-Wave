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
        #expect(stats.median == nil)
        #expect(stats.deltaSinceYesterday == nil)
        #expect(stats.deltaToMedian == nil)
    }

    @Test func singlePointHasNoDelta() {
        let stats = WaterLevelStats(history: [pt(0, 405.5)])
        #expect(stats.current == 405.5)
        #expect(stats.min == 405.5)
        #expect(stats.max == 405.5)
        #expect(stats.median == 405.5)
        #expect(stats.deltaSinceYesterday == nil)
        #expect(stats.deltaToMedian == 0)
    }

    @Test func computesCurrentMinMaxAndDelta() {
        let history = [pt(2, 405.0), pt(1, 405.5), pt(0, 405.2)]
        let stats = WaterLevelStats(history: history)
        #expect(stats.current == 405.2)
        #expect(stats.min == 405.0)
        #expect(stats.max == 405.5)
        #expect(abs(stats.deltaSinceYesterday! - (-0.3)) < 0.0001)
    }

    @Test func gapBeforeLatestPointYieldsNoDelta() {
        // Most recent two points are 5 days apart — the change is real, but it
        // is not a "since yesterday" change, so no delta should be reported.
        let history = [pt(5, 405.0), pt(0, 405.4)]
        let stats = WaterLevelStats(history: history)
        #expect(stats.current == 405.4)
        #expect(stats.min == 405.0)
        #expect(stats.max == 405.4)
        #expect(stats.deltaSinceYesterday == nil)
    }

    @Test func medianOddCount() {
        let history = [pt(2, 405.0), pt(1, 405.5), pt(0, 405.2)]
        let stats = WaterLevelStats(history: history)
        #expect(stats.median == 405.2)
        #expect(abs(stats.deltaToMedian! - 0) < 0.0001) // current (405.2) == median
    }

    @Test func medianEvenCountAverages() {
        let history = [pt(3, 405.0), pt(2, 405.2), pt(1, 405.4), pt(0, 405.8)]
        let stats = WaterLevelStats(history: history)
        // sorted levels: 405.0, 405.2, 405.4, 405.8 -> median of middle two
        #expect(abs(stats.median! - 405.3) < 0.0001)
        #expect(stats.current == 405.8)
        #expect(abs(stats.deltaToMedian! - 0.5) < 0.0001)
    }

    @Test func unsortedInputIsSortedInternally() {
        let history = [pt(0, 405.2), pt(2, 405.0), pt(1, 405.5)]
        let stats = WaterLevelStats(history: history)
        #expect(stats.current == 405.2)
    }
}
