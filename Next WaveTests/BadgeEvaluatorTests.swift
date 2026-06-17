import Testing
import Foundation
@testable import Next_Wave

struct BadgeEvaluatorTests {

    private func stats(total: Int = 0, lakes: Int = 0, early: Int = 0,
                       seasons: [String] = [], anniversary: Bool = false,
                       sameDay: Int = 0, solo: Int = 0, peer: Int = 0) -> WaveStats {
        WaveStats(
            totalWaves: total, distinctStations: 0, distinctLakes: lakes, maxWavesOneStation: 0,
            firstOfDayCount: 0, lastOfDayCount: 0, earlyBirdCount: early, lunchCount: 0,
            nightOwlCount: 0, weekendCount: 0, maxWavesOneDay: sameDay, hasAnniversary: anniversary,
            soloCount: solo, maxPeerCount: peer, trendsetterCount: 0, seasonsRidden: seasons,
            currentStreakWeeks: 0, longestStreakWeeks: 0)
    }

    @Test func firstWaveBadgeUnlocksAtOne() {
        let none = BadgeEvaluator.evaluate(stats(total: 0)).first { $0.badge.id == "first_wave" }!
        let one  = BadgeEvaluator.evaluate(stats(total: 1)).first { $0.badge.id == "first_wave" }!
        #expect(none.isEarned == false)
        #expect(one.isEarned == true)
    }

    @Test func milestoneProgressTextShowsCurrentOverTarget() {
        let e = BadgeEvaluator.evaluate(stats(total: 7)).first { $0.badge.id == "milestone_10" }!
        #expect(e.isEarned == false)
        #expect(e.current == 7)
        #expect(e.progressText == "7/10")
    }

    @Test func fourSeasonsNeedsAllFour() {
        let three = BadgeEvaluator.evaluate(stats(seasons: ["spring","summer","autumn"]))
            .first { $0.badge.id == "four_seasons" }!
        let four  = BadgeEvaluator.evaluate(stats(seasons: ["spring","summer","autumn","winter"]))
            .first { $0.badge.id == "four_seasons" }!
        #expect(three.isEarned == false)
        #expect(four.isEarned == true)
    }

    @Test func crowdSurferNeedsFivePeers() {
        let four = BadgeEvaluator.evaluate(stats(peer: 4)).first { $0.badge.id == "crowd_surfer" }!
        let five = BadgeEvaluator.evaluate(stats(peer: 5)).first { $0.badge.id == "crowd_surfer" }!
        #expect(four.isEarned == false)
        #expect(five.isEarned == true)
    }

    @Test func anniversaryIsBoolean() {
        let no  = BadgeEvaluator.evaluate(stats(anniversary: false)).first { $0.badge.id == "one_year" }!
        let yes = BadgeEvaluator.evaluate(stats(anniversary: true)).first { $0.badge.id == "one_year" }!
        #expect(no.isEarned == false)
        #expect(yes.isEarned == true)
    }

    @Test func newlyEarnedExcludesAlreadySeen() {
        let s = stats(total: 1, early: 1)
        let earnedIds = Set(BadgeEvaluator.evaluate(s).filter { $0.isEarned }.map { $0.badge.id })
        // Already saw everything except "early_bird": only that one is "new".
        let seen = earnedIds.subtracting(["early_bird"])
        let fresh = BadgeEvaluator.newlyEarned(s, seenIds: seen)
        #expect(fresh.map { $0.id } == ["early_bird"])
    }
}
